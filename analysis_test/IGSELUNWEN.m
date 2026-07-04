clc;
clear;
close all;
% 步骤1：正确读取Excel数据（假设文件名为'core_loss_data.xlsx'）
data = readtable('三角波.xlsx', 'VariableNamingRule', 'preserve');

% 确保按列号提取数据（避免列名依赖）
T = data{2:end, 1};        % 第1列：温度（℃）
f = data{2:end, 2};        % 第2列：频率（Hz）
P_meas = data{2:end, 3};   % 第3列：实测损耗（W/m³）
waveform = data{2:end, 4}; % 第4列：波形类型（此处全为三角波）
B_data = data{2:end, 5:end}; % 第5-1028列：磁通密度（T）

% 数据类型检查
% assert(isnumeric(T) && isnumeric(f) && isnumeric(P_meas) && isnumeric(B_data), ...
    % '数据列类型错误！必须为数值类型');

% 步骤2：计算每个周期的占空比（D = 上升时间/总周期）
[N_samples, N_cycles] = size(B_data);
D_ratios = zeros(N_cycles, 1);

for i = 1:N_samples
    [B_max, i_max] = max(B_data(i, :)); % 找到三角波顶点
    D_ratios(i) = (i_max - 1) / (N_cycles - 1); % 归一化占空比
end

% 可视化占空比分布
figure;
histogram(D_ratios, 'BinWidth', 0.05);
xlabel('占空比 (D)'); ylabel('数据量'); 
title('三角波占空比分布');

% 步骤3：非线性拟合反推k, α, β（使用改进Steinmetz方程）
% 定义ISE模型函数
% ise_model = @(params, D, f, Bm) ...
%     (pi/4) * params(1) * 2^(-params(2)) .* (D.^(1-params(2)) + (1-D).^(1-params(2))) ...
%     .* f.^params(2) .* Bm.^params(3);
ise_model = @(params, X) ...
    (pi/4) * params(1) * 2^(-params(2)) .* ...
    (X(:,1).^(1-params(2)) + (1-X(:,1)).^(1-params(2))) .* ...
    X(:,2).^params(2) .* X(:,3).^params(3);
% 初始参数猜测（典型铁氧体初始值）
params_guess = [0.02, 1.8, 2.5]; % [k, α, β]

% 计算峰值磁通密度
Bm = max(B_data, [], 2);
X_data = [D_ratios(:), f(:), Bm(:)];
% 检查维度
disp(['D_ratios size: ', num2str(size(D_ratios))]);
disp(['f size: ', num2str(size(f))]);
disp(['Bm size: ', num2str(size(Bm))]);

% 非线性最小二乘拟合
 options = optimoptions('lsqcurvefit', 'Display', 'iter', 'MaxIterations', 300,'FunctionTolerance', 1e-8,'OptimalityTolerance', 1e-8);

% params_fit = lsqcurvefit(ise_model, params_guess, ...
%     [D_ratios, f, Bm], P_meas, [], [], options);
params_fit = lsqcurvefit(ise_model, params_guess, X_data, P_meas, [], [], options);

% 提取拟合参数
k_fit = params_fit(1);
alpha_fit = params_fit(2);
beta_fit = params_fit(3);

disp(['拟合参数: k=', num2str(k_fit), ', α=', num2str(alpha_fit), ', β=', num2str(beta_fit)]);

% 步骤4：使用拟合参数预测损耗
P_pred = ise_model(params_fit, X_data);

% 计算误差
abs_error = abs(P_pred - P_meas);
rel_error = abs_error ./ P_meas * 100;

% 整体误差统计
fprintf('平均相对误差: %.2f%%, 最大误差: %.2f%%\n', ...
    mean(rel_error), max(rel_error));
% 计算R²
P_pred = ise_model(params_fit, X_data);
SS_res = sum((P_meas - P_pred).^2);
SS_tot = sum((P_meas - mean(P_meas)).^2);
R2 = 1 - SS_res/SS_tot;

% 可视化残差
figure;
histogram(P_meas - P_pred, 50);
title(sprintf('残差分布 (R²=%.4f)', R2));

% 按温度分组误差
temp_groups = unique(T);
for t = temp_groups'
    idx = T == t;
    fprintf('温度%d℃: 平均误差=%.2f%%\n', t, mean(rel_error(idx)));
end
% 提取频率列
frequencies = X_data(:,2); 

% 动态确定分组边界
f_max = max(frequencies);
f_limits = [0, f_max/3, 2*f_max/3, f_max]; % 三等分频率范围

% 创建分组标签
group_names = {'低频', '中频', '高频'};
group_colors = {'b', 'g', 'r'};

% 初始化图形
figure('Name', '按频率分组的误差分析');
set(gcf, 'Position', [100, 100, 900, 400]);

% --- 子图1：分组残差箱线图 ---
subplot(1,2,1);
hold on;
residuals = rel_error;

% 为每组数据绘制箱线图
for i = 1:3
    mask = (frequencies >= f_limits(i)) & (frequencies < f_limits(i+1));
    boxplot(residuals(mask), 'Positions', i, 'Colors', group_colors{i}, 'Widths', 0.6);
end

% 图形美化
set(gca, 'XTickLabel', group_names);
ylabel(' (实测-预测)');
title('不同频段误差分布');
grid on;

% 添加参考线
% yline(0, 'k--', 'LineWidth', 1);
% legend('负残差: 模型高估', '正残差: 模型低估', 'Location', 'best');

% --- 子图2：频段误差统计 ---
subplot(1,2,2);
hold on;

% 计算每组的统计量
error_stats = zeros(3,3); % [平均绝对误差, 最大误差, 标准差]
for i = 1:3
    mask = (frequencies >= f_limits(i)) & (frequencies < f_limits(i+1));
    group_residuals = residuals(mask);
    
    error_stats(i,1) = mean(abs(group_residuals));
    error_stats(i,2) = max(abs(group_residuals));
    error_stats(i,3) = std(group_residuals);
    
    % 绘制条形图
    bar(i, error_stats(i,1), 'FaceColor', group_colors{i}, 'FaceAlpha', 0.6);
end

% 添加误差条
errorbar(1:3, error_stats(:,1), error_stats(:,3), 'k.', 'LineWidth', 1.5);

% 标注最大误差
for i = 1:3
    text(i, error_stats(i,1)+0.1*max(error_stats(:,1)), ...
        sprintf('Max=%.2f', error_stats(i,2)), 'HorizontalAlignment', 'center');
end

% 图形美化
set(gca, 'XTick', 1:3, 'XTickLabel', group_names);
ylabel('平均绝对误差 (MAE)');
title('各频段误差统计');
grid on;

% --- 输出关键结论 ---
fprintf('频率分组边界 (Hz):\n 低频: [0, %.1f)\n 中频: [%.1f, %.1f)\n 高频: [%.1f, %.1f]\n\n', ...
    f_limits(2), f_limits(2), f_limits(3), f_limits(3), f_limits(4));
% 步骤5：绘制预测 vs 实测对比
figure;
subplot(2,1,1);
scatter(D_ratios, P_meas, 40, f, 'filled'); hold on;
scatter(D_ratios, P_pred, 80, 'r', 'LineWidth', 1.5);
colorbar; xlabel('占空比'); ylabel('损耗 (W/m³)');
legend('实测', '预测 (ISE)', 'Location', 'northwest');
title('损耗预测对比（颜色表示频率）');

subplot(2,1,2);
scatter(P_meas, P_pred, 40, T, 'filled');
hold on; plot([min(P_meas), max(P_meas)], [min(P_meas), max(P_meas)], 'r--');
colorbar; xlabel('实测损耗'); ylabel('预测损耗'); 
title('预测 vs 实测散点图（颜色表示温度）');

% 误差分布图
figure;
boxplot(rel_error, T);
xlabel('温度 (℃)'); ylabel('相对误差 (%)');
title('不同温度下的预测误差分布');
