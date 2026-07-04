clc;
clear;

%% 数据读取与预处理
filename = '正弦波（训练集）.xlsx';
data = xlsread(filename);

% 提取数据列
temperature = data(:, 1);        % 第1列：温度（°C）
frequency = data(:, 2);          % 第2列：频率（Hz）
core_loss = data(:, 3);          % 第3列：磁芯损耗（W/m³）
B_samples = data(:, 5:end);      % 第5-1028列：磁通密度采样点（T）

% 计算磁通密度峰值 B_max
B_max = max(B_samples, [], 2);   % 沿行取最大值

% 输入变量矩阵 X = [温度, 频率, B_max]
X_all = [temperature, frequency, B_max];
y_all = core_loss;

%% 模型定义：温度对频率指数（二次项）和B_max指数（指数项）的修正
% 定义模型函数：P = k0 * exp(-γ*(T-T0)) * f^(b0 + b1*T + b2*T^0.5) * B_max^(c0*exp(c1*T))
T0 = 25; % 参考温度（根据实验数据设定）
model_modified = @(params, X) ...
    params(1) * exp(-params(2) * (X(:,1) - T0)) .* ...       % k(T) = k0 * exp(-γ*(T-T0))
    X(:,2).^(params(3) + params(4)*X(:,1) + params(5)*X(:,1).^0.5) .* ...  % f^(b0 + b1*T + b2*T^2)
    X(:,3).^(params(6) * exp(params(7)*X(:,1)));             % B_max^(c0*exp(c1*T))

% 初始参数猜测（根据物理意义或先验知识设置）
initial_guess = [15, 0.01, 1.5, -0.002, 0.0001, 2.0, 0.001]; % [k0, γ, b0, b1, b2, c0, c1]

% 非线性最小二乘拟合
options = optimoptions('lsqcurvefit', 'Algorithm', 'levenberg-marquardt', 'MaxIterations', 1000);
[params_fit, resnorm] = lsqcurvefit(model_modified, initial_guess, X_all, y_all, [], [], options);

% 提取拟合参数
k0 = params_fit(1);
gamma = params_fit(2);
b0 = params_fit(3);
b1 = params_fit(4);
b2 = params_fit(5);
c0 = params_fit(6);
c1 = params_fit(7);

%% 预测误差分析
core_loss_pred = model_modified(params_fit, X_all);

% 计算误差指标
RMSE = sqrt(mean((core_loss_pred - y_all).^2));
MAPE = mean(abs((core_loss_pred - y_all) ./ y_all)) * 100;

% 输出结果
fprintf('\n=== 修正斯坦麦茨方程参数 ===\n');
fprintf('k0 = %.4f\nγ = %.4f\nb0 = %.4f\nb1 = %.4f\nb2 = %.4f\nc0 = %.4f\nc1 = %.4f\n', params_fit);
fprintf('RMSE = %.2f W/m³\nMAPE = %.2f%%\n', RMSE, MAPE);

%% 可视化分析
% 1. 温度对各参数的影响
T_range = linspace(min(temperature), max(temperature), 100);

% k(T) = k0 * exp(-γ*(T-T0))
k_T = k0 * exp(-gamma * (T_range - T0));

% 频率指数项：b0 + b1*T + b2*T^2
f_exp_T = b0 + b1*T_range + b2*T_range.^2;

% B_max指数项：c0*exp(c1*T)
B_exp_T = c0 * exp(c1*T_range);

figure;
subplot(3,1,1);
plot(T_range, k_T, 'r-', 'LineWidth', 1.5);
xlabel('温度 (°C)'); ylabel('k(T)'); title('温度对k的影响');

subplot(3,1,2);
plot(T_range, f_exp_T, 'b-', 'LineWidth', 1.5);
xlabel('温度 (°C)'); ylabel('f指数项'); title('温度对频率指数的影响');

subplot(3,1,3);
plot(T_range, B_exp_T, 'g-', 'LineWidth', 1.5);
xlabel('温度 (°C)'); ylabel('B_{max}指数项'); title('温度对B_{max}指数的影响');

% 2. 预测值与实际值对比
figure;
scatter(y_all, core_loss_pred, 30, 'filled');
hold on;
plot([min(y_all), max(y_all)], [min(y_all), max(y_all)], 'k--', 'LineWidth', 1.5);
xlabel('实际磁芯损耗 (W/m³)'); ylabel('预测磁芯损耗 (W/m³)');
title('模型预测性能对比');
grid on;

% 3. 残差分布
residuals = core_loss_pred - y_all;
figure;
histogram(residuals, 20);
xlabel('残差 (W/m³)'); ylabel('频数');
title('残差分布直方图');