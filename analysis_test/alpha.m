clc; clear; close all;

% ========== 数据读取与预处理 ==========
filename = 'Material.xlsx';
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

% ========== 全局拟合（alpha作为温度的三次函数） ==========
% 初始参数：[k_i, beta, alpha0, alpha1, alpha2, alpha3]
initial_params = [1e-5, 2.5, 1.5, 0, 0, 0]; % 调整参数顺序，现在beta是第二个参数

options = optimset('Display','final', 'MaxIter', 2000);
global_params = fminsearch(@(p) global_objective(p, processed_data), initial_params, options);

% 提取参数
k_i_global = global_params(1);
beta_global = global_params(2);
alpha_coeffs = global_params(3:6); % [α0, α1, α2, α3]

fprintf('\n=== 全局拟合参数 ===\n');
fprintf('k_i = %.4e\n', k_i_global);
fprintf('beta = %.4f\n', beta_global);
fprintf('alpha(T) = %.4f + %.4f*T + %.4f*T² + %.4f*T³\n\n', alpha_coeffs);

% 绘制alpha-T关系
figure('Name', 'Alpha温度关系');
alpha_fun = @(T) alpha_coeffs(1) + alpha_coeffs(2)*T + alpha_coeffs(3)*T.^2 + alpha_coeffs(4)*T.^3;
T_plot = linspace(min(temps), max(temps), 100);
plot(T_plot, alpha_fun(T_plot), 'LineWidth', 2);
hold on;
scatter([processed_data.temp], arrayfun(@(T) alpha_fun(T), [processed_data.temp]), 'filled');
xlabel('温度 (℃)'); ylabel('alpha值');
title('Alpha作为温度的三次函数');
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
        current_params = [k_i_global, beta_global, alpha_fun(sub_samples(i).temp)];
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
    beta = params(2);  % β现在是常数
    alpha = params(3); % α是基于温度计算的值
    T = 1/freq;
    integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
    P_pred = (k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
end

function err = global_objective(params, samples)
    k_i = params(1);
    beta = params(2);
    alpha_coeffs = params(3:6);
    
    err = 0;
    for i = 1:length(samples)
        T = samples(i).temp;
        alpha = alpha_coeffs(1) + alpha_coeffs(2)*T + alpha_coeffs(3)*T^2 + alpha_coeffs(4)*T^3;
        
        pred = igse_model([k_i, beta, alpha], samples(i).dBdt, ...
                         samples(i).delta_B, samples(i).freq);
        err = err + (pred - samples(i).actual_loss)^2;
    end
    err = sqrt(err / length(samples));
end
