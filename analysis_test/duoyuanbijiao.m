clc
clear
%% 数据读取与k值提取
filename = '正弦波（训练集）.xlsx';
data = xlsread(filename);

% 提取数据列
temperature = data(:, 1);        % 第1列：温度（°C）
frequency = data(:, 2);          % 第2列：频率（Hz）
core_loss = data(:, 3);          % 第3列：磁芯损耗（W/m³）
B_samples = data(:, 5:end);      % 第5-1028列：磁通密度采样点（T）

% 计算磁通密度峰值 B_max
B_max = max(B_samples, [], 2);   % 沿行取最大值

% 按温度分组
unique_T = unique(temperature);
k_values = zeros(length(unique_T), 1);
k_values2 = zeros(length(unique_T), 1);
k_values3 = zeros(length(unique_T), 1);
% 对每个温度组独立拟合原始斯坦麦茨方程
for i = 1:length(unique_T)
    T = unique_T(i);
    idx = (temperature == T);
    X = [frequency(idx), B_max(idx)];
    y = core_loss(idx);
    
    % 定义原始斯坦麦茨方程：P_v = k * f^alpha * B_max^beta
    model_original = @(params, X) params(1) .* X(:,1).^params(2) .* X(:,2).^params(3);
    initial_guess = [0.05, 1.5, 2.0]; % 初始参数猜测
    params_fit = lsqcurvefit(model_original, initial_guess, X, y);
    k_values(i) = params_fit(1);
    k_values2(i) = params_fit(2);
    k_values3(i) = params_fit(3);

end

% 保存温度与对应的k值
T_k_data = [unique_T, k_values];
T_k_data1 = [unique_T, k_values2];
T_k_data2 = [unique_T, k_values3];
%% 回归模型拟合与AIC计算
T0 = T_k_data(:, 1);
k0 = T_k_data(:, 2);
T1 = T_k_data1(:, 1);
k1 = T_k_data1(:, 2);
T2 = T_k_data2(:, 1);
k2 = T_k_data2(:, 2);
function [residuals_linear,residuals_quad,residuals_exp]=moxin(k,T)
% 线性模型：k = b0 + b1*T
X_linear = [ones(size(T)), T];
[beta_linear, ~, ~, ~, stats_linear] = regress(k, X_linear);
R2_linear = stats_linear(1);
residuals_linear = k - X_linear * beta_linear;
AIC_linear = 2*2 + length(k)*log(mean(residuals_linear.^2));

% 二次多项式模型：k = b0 + b1*T + b2*T^2
X_quad = [ones(size(T)), T, T.^2];
[beta_quad, ~, ~, ~, stats_quad] = regress(k, X_quad);
R2_quad = stats_quad(1);
residuals_quad = k - X_quad * beta_quad;
AIC_quad = 2*3 + length(k)*log(mean(residuals_quad.^2));

% 指数模型：k = b0 * exp(b1*T)
model_exp = @(b, T) b(1) * exp(b(2)*T);
beta0_exp = [0.05, 0.001]; % 初始猜测
beta_exp = nlinfit(T, k, model_exp, beta0_exp);
residuals_exp = k - model_exp(beta_exp, T);
AIC_exp = 2*2 + length(k)*log(mean(residuals_exp.^2));

% 输出AIC值
fprintf('模型比较：\n');
fprintf('线性模型 AIC = %.2f\n', AIC_linear);
fprintf('二次模型 AIC = %.2f\n', AIC_quad);
fprintf('指数模型 AIC = %.2f\n', AIC_exp);
end
A=moxin(k0,T0);
B=moxin(k1,T1);
C=moxin(k2,T2);
%% 模型选择：以残差最小（RMSE）为准则
% 计算各模型的RMSE
function k_func=MSE(residuals_linear,residuals_quad,residuals_exp)
RMSE_linear = sqrt(mean(residuals_linear.^2));
RMSE_quad = sqrt(mean(residuals_quad.^2));
RMSE_exp = sqrt(mean(residuals_exp.^2));

% 选择RMSE最小的模型
[RMSE_values, idx] = min([RMSE_linear, RMSE_quad, RMSE_exp]);
models = {'线性', '二次', '指数'};
selected_model = models{idx};
fprintf('最优模型：%s (RMSE = %.2f)\n', selected_model, RMSE_values);

% 根据最优模型定义k(T)
if strcmp(selected_model, '线性')
    k_func = @(T) beta_linear(1) + beta_linear(2)*T;
elseif strcmp(selected_model, '二次')
    k_func = @(T) beta_quad(1) + beta_quad(2)*T + beta_quad(3)*T.^2;
else
    k_func = @(T) beta_exp(1) * exp(beta_exp(2)*T);
end
end
MSE(A(1),A(2),A(3));
MSE(B(1),B(2),B(3));
MSE(C(1),C(2),C(3));
%% 选择最优模型（以AIC最小为准则）
% [AIC_values, idx] = min([AIC_linear, AIC_quad, AIC_exp]);
% models = {'线性', '二次', '指数'};
% selected_model = models{idx};
% fprintf('最优模型：%s (AIC = %.2f)\n', selected_model, AIC_values);
% 
% % 根据最优模型定义k(T)
% if strcmp(selected_model, '线性')
%     k_func = @(T) beta_linear(1) + beta_linear(2)*T;
% elseif strcmp(selected_model, '二次')
%     k_func = @(T) beta_quad(1) + beta_quad(2)*T + beta_quad(3)*T.^2;
% else
%     k_func = @(T) beta_exp(1) * exp(beta_exp(2)*T);
% end

%% 修正方程全局拟合
% 修正模型：P_v = k(T) * f^alpha * B_max^beta
model_modified = @(params, X) k_func(X(:,1)) .* X(:,2).^params(1) .* X(:,3).^params(2);
% 输入 X 的列：[温度, 频率, B_max]
% 参数 params = [alpha, beta]

% 组合输入变量矩阵 X
X_all = [temperature, frequency, B_max];
y_all = core_loss;

% 初始参数猜测
initial_guess = [1.5, 2.0]; 

% 非线性最小二乘拟合
[params_fit, resnorm] = lsqcurvefit(model_modified, initial_guess, X_all, y_all);

% 计算预测误差
core_loss_pred = model_modified(params_fit, X_all);
RMSE = sqrt(mean((core_loss_pred - y_all).^2));
MAPE = mean(abs((core_loss_pred - y_all) ./ y_all)) * 100;

% 输出结果
fprintf('\n修正模型参数：\n');
fprintf('alpha = %.4f\nbeta = %.4f\n', params_fit);
fprintf('RMSE = %.2f W/m³\nMAPE = %.2f%%\n', RMSE, MAPE);
fprintf('a=%f\nb=%f\n',beta_exp(1),beta_exp(2));
%% 可视化温度对k的影响
figure;
scatter(T, k, 80, 'filled');
hold on;
T_range = linspace(min(T), max(T), 100);
plot(T_range, k_func(T_range), 'r-', 'LineWidth', 1.5);
xlabel('温度 (°C)');
ylabel('k(T)');
title(sprintf('温度对k的影响（模型：%s）', selected_model));
grid on;

%% 预测值与实际值对比
figure;
plot(y_all, core_loss_pred, 'o', 'MarkerSize', 6);
hold on;
plot([min(y_all), max(y_all)], [min(y_all), max(y_all)], 'r--', 'LineWidth', 1.5);
xlabel('实际磁芯损耗 (W/m³)');
ylabel('预测磁芯损耗 (W/m³)');
title('修正模型预测性能');
legend('数据点', '理想拟合线', 'Location', 'best');
grid on;

%% 残差分析
figure;
plot(core_loss_pred, core_loss_pred - y_all, 'o');
hold on;
yline(0, 'r--', 'LineWidth', 1.5);
xlabel('预测值 (W/m³)');
ylabel('残差 (W/m³)');
title('残差分布');
grid on;