clc; clear; close all;

% ========== 数据读取与预处理 ==========
filename = 'Material1.xlsx';
data = xlsread(filename);
data = data(data(:,4) == 2, :); % 仅使用三角波数据
temps = unique(data(:,1)); 
N_samples_per_cycle = 1024; 

% 预处理结构体
processed_data = struct('dBdt', [], 'delta_B', [], ...
                       'actual_loss', [], 'freq', [], 'temp', []);

for i = 1:size(data,1)
    B_wave = data(i,5:end);
    freq = data(i,2);
    dt = 1/(freq * N_samples_per_cycle); 
    
    % 中心差分计算dB/dt
    dBdt = zeros(1, N_samples_per_cycle);
    dBdt(1) = (B_wave(2) - B_wave(1)) / dt;
    dBdt(end) = (B_wave(end) - B_wave(end-1)) / dt;
    for j = 2:N_samples_per_cycle-1
        dBdt(j) = (B_wave(j+1) - B_wave(j-1)) / (2*dt);
    end
    
    processed_data(i).dBdt = dBdt;
    processed_data(i).delta_B = max(B_wave) - min(B_wave);
    processed_data(i).actual_loss = data(i,3);
    processed_data(i).freq = freq;
    processed_data(i).temp = data(i,1);
end

% ========== 全局拟合（beta作为温度的三次函数） ==========
% 初始参数：[k_i, alpha, beta0, beta1, beta2, beta3]
% initial_params = [1e-4, 1.92, 2.0054230137048, 0.0151546235910474, -0.000327459265401962, 2.23161955301280e-06]; 
initial_params = [1e-5, 1.5, 2.5,0,0,0];
% initial_params = [2.2750e-04, 1.8716, 2.2859,0,0,0];
% 使用fmincon约束优化（确保alpha > 1, beta(T) > 0）
% options = optimoptions('fmincon', 'Display', 'iter', 'MaxIter', 100);
% lb = [1e-10, 1, 0, -Inf, -Inf, -Inf]; % 参数下限
% ub = [Inf, 3, Inf, Inf, Inf, Inf];    % 参数上限
   options = optimset('Display','final', 'MaxIter', 2000);
    % params{t} = fminsearch(@(p) objective(p, samples), initial_params, options);
% 定义非线性约束：对所有T，beta(T) > 0
% nonlcon = @(p) beta_constraint(p, temps);

% 全局拟合
% global_params = fmincon(@(p) global_objective(p, processed_data), ...
%                        initial_params, [], [], [], [], lb, ub, nonlcon, options);
global_params = fminsearch(@(p) global_objective(p, processed_data), initial_params, options);

% 提取参数
k_i_global = global_params(1);
alpha_global = global_params(2);
beta_coeffs = global_params(3:6); % [β0, β1, β2, β3]

fprintf('\n=== 全局拟合参数 ===\n');
fprintf('k_i = %.4e\n', k_i_global);
fprintf('alpha = %.4f\n', alpha_global);
fprintf('beta(T) = %.4f + %.4f*T + %.4f*T² + %.4f*T³\n\n', beta_coeffs);

% 绘制beta-T关系
figure('Name', 'Beta温度关系');
beta_fun = @(T) beta_coeffs(1) + beta_coeffs(2)*T + beta_coeffs(3)*T.^2 + beta_coeffs(4)*T.^3;
T_plot = linspace(min(temps), max(temps), 100);
plot(T_plot, beta_fun(T_plot), 'LineWidth', 2);
hold on;
scatter([processed_data.temp], arrayfun(@(T) beta_fun(T), [processed_data.temp]), 'filled');
xlabel('温度 (℃)'); ylabel('beta值');
title('Beta作为温度的三次函数');
grid on;

% ========== 误差分析 ==========
all_pred = [];
all_actual = [];
temp_MAPE = zeros(length(temps),1);

figure('Name', '全局模型预测对比');
for t = 1:length(temps)
    temp_mask = [processed_data.temp] == temps(t);
    sub_samples = processed_data(temp_mask);
    if isempty(sub_samples), continue; end
    
    actual = [sub_samples.actual_loss]';
    pred = zeros(length(sub_samples),1);
    
    for i = 1:length(sub_samples)
        % 使用全局参数预测
        current_params = [k_i_global, alpha_global, beta_fun(sub_samples(i).temp)];
        pred(i) = igse_model(current_params, sub_samples(i).dBdt, ...
                           sub_samples(i).delta_B, sub_samples(i).freq);
    end
    
    % 存储结果
    all_pred = [all_pred; pred];
    all_actual = [all_actual; actual];
    
    % 计算MAPE
    valid_idx = actual ~= 0;
    if any(valid_idx)
        temp_MAPE(t) = 100 * mean(abs((actual(valid_idx)-pred(valid_idx))./actual(valid_idx)));
    end
    
    % 绘制子图
    subplot(2,2,t);
    scatter(actual, pred, 'filled');
    hold on;
    plot([0 max(actual)], [0 max(actual)], 'r--');
    title(sprintf('温度%d℃ MAPE=%.2f%%', temps(t), temp_MAPE(t)));
    xlabel('实际损耗'); ylabel('预测损耗');
    axis equal; grid on;
end

% 全局MAPE
global_mape = 100 * mean(abs((all_pred(all_actual~=0)-all_actual(all_actual~=0))./all_actual(all_actual~=0)));
fprintf('全局MAPE: %.2f%%\n', global_mape);

% ========== 模型函数 ==========
function P_pred = igse_model(params, dBdt, delta_B, freq)
    k_i = params(1);
    alpha = params(2);
    beta = params(3); % 此处beta已经是基于温度计算好的值
    T = 1/freq;
    integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
    P_pred = (k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
end

function err = global_objective(params, samples)
    k_i = params(1);
    alpha = params(2);
    beta_coeffs = params(3:6);
    
    err = 0;
    for i = 1:length(samples)
        T = samples(i).temp;
        beta = beta_coeffs(1) + beta_coeffs(2)*T + beta_coeffs(3)*T^2 + beta_coeffs(4)*T^3;
        
        pred = igse_model([k_i, alpha, beta], samples(i).dBdt, ...
                         samples(i).delta_B, samples(i).freq);
        err = err + (pred - samples(i).actual_loss)^2;
    end
    err = sqrt(err / length(samples));
end

function [c, ceq] = beta_constraint(params, temps)
    % 确保在所有温度下 beta(T) > 0
    beta_coeffs = params(3:6);
    beta_values = beta_coeffs(1) + beta_coeffs(2)*temps + ...
                 beta_coeffs(3)*temps.^2 + beta_coeffs(4)*temps.^3;
    c = -beta_values; % 要求 beta_values > 0 等价于 -beta_values < 0
    ceq = [];
end
