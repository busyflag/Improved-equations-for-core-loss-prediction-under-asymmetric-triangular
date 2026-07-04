clc;
clear;
close all;

% ========== 数据读取与预处理 ==========
filename = 'Material4.xlsx';
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultLegendFontName', 'Times New Roman');
data = xlsread(filename); % 假定波形类型列已经是数值型：1-SIN, 2-TRI, 3-TRAPEZOID

% 只保留三角波数据 (wave_type = 2)
data = data(data(:,4) == 2, :);
temperatures = data(:,1); 
N_samples_per_cycle = 1024; 
% 预处理每个样本的dB/dt、ΔB等信息
processed_data = struct('dBdt', [], 'delta_B', [], ...
                        'actual_loss', [], 'freq', [], 'f_eq', [], 'D_ratio', [] ,'temp', []);

for i = 1:size(data,1)
    B_wave = data(i,5:end); % 读取波形数据
    freq = data(i,2);
    dt = 1/(freq * N_samples_per_cycle); % 时间步长计算
    delta_B = max(B_wave) - min(B_wave);
  
    % 中心差分法计算dB/dt
    dBdt = zeros(1, N_samples_per_cycle);
    dBdt(1) = (B_wave(2) - B_wave(1)) / dt;
    dBdt(end) = (B_wave(end) - B_wave(end-1)) / dt;
    for j = 2:N_samples_per_cycle-1
        dBdt(j) = (B_wave(j+1) - B_wave(j-1)) / (2*dt);
    end
  
    % 计算等效频率f_eq = (2/ΔB²π²) * ∫(dB/dt)² dt
    f_eq = (2/(delta_B^2 * pi^2)) * trapz(linspace(0,1/freq,length(dBdt)), dBdt.^2);
    
    % 计算占空比 (D = 上升时间/总周期)
    [~, i_max] = max(B_wave); % 找到三角波顶点
    D_ratio = (i_max - 1) / (length(B_wave) - 1); % 归一化占空比
    
    % 保存到结构体
    processed_data(i).dBdt = dBdt;
    processed_data(i).delta_B = delta_B;
    processed_data(i).actual_loss = data(i,3);
    processed_data(i).freq = freq;
    processed_data(i).f_eq = f_eq;
    processed_data(i).D_ratio = D_ratio;
    processed_data(i).temp = data(i,1);
end

% ========== 全局拟合 ==========
% 初始参数 
% initial_params_igse = [1e-5, 1.5, 2.5]; 
% initial_params_mse = [1e-5, 1.5, 2.5, 1.0];
% % initial_params_dcm = [1e-5, 1.5, 2.5, 1.0, 1.0]; % k, α, β, CD (占空比修正系数)
% initial_params_dcm = [1e-5, 1.5, 2.5, 0, 0, 0, 0, 1.0]; % k, α, [β_coeffs], CD, CP
% % initial_params_dcm = [1e-5, 1.5, 2.5, 0, 0, 0, 1.0, 1.0]; % k, α, [β_coeffs], CD, CP
% lb_igse = [1e-10, 1.0, 1.0];     % k_i > 0, alpha >=1, beta >=1
% ub_igse = [1e-3,  3.0, 3.0];     % 假设参数大致范围
% 
% lb_mse = [1e-10, 1.0, 1.0, 0.1]; % MSE多一个修正系数Cm > 0
% ub_mse = [1e-3,  3.0, 3.0, 40.0];
% 
% lb_dcm = [1e-10, 1.0, 1.0, 0.1]; % DCM-IGSE多一个占空比修正系数CD > 0
% ub_dcm = [1e-3,  3.0, 3.0, 5.0];
% 初始参数 (第一个参数传入的是 log10(k) 的值)
initial_params_igse = [-5, 1.5, 2.5]; 
initial_params_mse = [-5, 1.5, 2.5, 1.0];
initial_params_dcm = [-5, 1.5, 2.5, 0, 0, 0, 0, 1.0]; % k, α, [β_coeffs], CD, CP

% 如果你要用 fmincon 或 pso，边界也要改对数
lb_igse = [-10, 1.0, 1.0];     % log(k) > -10
ub_igse = [-3,  3.0, 3.0];     

lb_mse = [-10, 1.0, 1.0, 0.1]; 
ub_mse = [-3,  3.0, 3.0, 40.0];

lb_dcm = [-10, 1.0, 1.0, -10, -10, -10, -10, 0.1]; % 适当放开温度系数的边界
ub_dcm = [-3,  3.0, 3.0,  10,  10,  10,  10, 5.0];

% 优化选项
% options = optimset('Display','final', 'MaxIter', 5000);
options = optimset('Display','iter', 'MaxIter', 10000, 'MaxFunEvals', 20000, 'TolFun', 1e-5, 'TolX', 1e-5);
% options = optimoptions('fmincon', ...
%     'Algorithm', 'interior-point', ...
%     'Display', 'iter', ...
%     'MaxIterations', 1000, ...
%     'StepTolerance', 1e-8);
% options_pso = optimoptions('particleswarm', ...
%     'SwarmSize', 50, ...          % 粒子数量（默认 min(100,10*参数数)）
%     'MaxIterations', 200, ...     % 最大迭代次数
%     'Display', 'iter', ...        % 显示迭代过程
%     'FunctionTolerance', 1e-6);   % 函数值容忍度

% IGSE模型参数优化
[opt_params_igse, ~, ~] = fminsearch(@(p) objective_igse(p, processed_data), initial_params_igse, options);

% [opt_params_igse, ~, ~] = fmincon(@(p) objective_igse(p, processed_data), ...
%     initial_params_igse, [], [], [], [], lb_igse, ub_igse, [], options);

% [opt_params_igse, ~, ~] = particleswarm(@(p) objective_igse(p, processed_data), ...
%     length(initial_params_igse), lb_igse, ub_igse, options_pso);
% MSE模型参数优化
[opt_params_mse, ~, ~] = fminsearch(@(p) objective_mse(p, processed_data), initial_params_mse, options);

% [opt_params_mse, ~, ~] = fmincon(@(p) objective_mse(p, processed_data), ...
%     initial_params_mse, [], [], [], [], lb_mse, ub_mse, [], options);

% [opt_params_mse, ~, ~] = particleswarm(@(p) objective_mse(p, processed_data), ...
%     length(initial_params_mse), lb_mse, ub_mse, options_pso);
% DCM-IGSE模型参数优化
[opt_params_dcm, ~, ~] = fminsearch(@(p) objective_dcm(p, processed_data), ...
                                   initial_params_dcm, options);

% [opt_params_dcm, ~, ~] = fminsearch(@(p) objective_dcm(p, processed_data), initial_params_dcm, options);
% 
% [opt_params_dcm, ~, ~] = fmincon(@(p) objective_dcm(p, processed_data), ...
%     initial_params_dcm, [], [], [], [], lb_dcm, ub_dcm, [], options);

% [opt_params_dcm, ~, ~] = particleswarm(@(p) objective_dcm(p, processed_data), ...
%     length(initial_params_dcm), lb_dcm, ub_dcm, options_pso);
% 优化算法输出的是 log10(k)，我们把它变回真实的 k 
opt_params_igse(1) = 10^opt_params_igse(1);
opt_params_mse(1)  = 10^opt_params_mse(1);
opt_params_dcm(1)  = 10^opt_params_dcm(1);
% 显示最终拟合参数
fprintf('IGSE 全局拟合参数:\n');
fprintf('k_i = %.4e, alpha = %.4f, beta = %.4f\n\n', ...
        opt_params_igse(1), opt_params_igse(2), opt_params_igse(3));

fprintf('MSE 全局拟合参数:\n');
fprintf('k_i = %.4e, alpha = %.4f, beta = %.4f, Cm = %.4f\n\n', ...
        opt_params_mse(1), opt_params_mse(2), opt_params_mse(3), opt_params_mse(4));

fprintf('DCM-IGSE 全局拟合参数:\n');
fprintf('k_i = %.4e, alpha = %.4f, beta = %.4f*T^3+%.4f*T^2+%.4f*T^1+%.4f, CD = %.4f\n\n, CP= %.4f\n\n', ...
        opt_params_dcm(1), opt_params_dcm(2), opt_params_dcm(3), opt_params_dcm(4),opt_params_dcm(5),opt_params_dcm(6),opt_params_dcm(7),opt_params_dcm(8));

% ========== 计算各个模型的预测值和误差 ==========
all_actual = [processed_data.actual_loss]';
N = length(processed_data);

% 各模型预测
pred_igse = zeros(N,1);
pred_mse = zeros(N,1);
pred_dcm = zeros(N,1);

for i = 1:N
    pred_igse(i) = igse_model(opt_params_igse, processed_data(i).dBdt, ...
                            processed_data(i).delta_B, processed_data(i).freq);
    pred_mse(i) = mse_model(opt_params_mse, processed_data(i).f_eq, ...
                          processed_data(i).delta_B, processed_data(i).freq);
    pred_dcm(i) = dcm_igse_model(opt_params_dcm, processed_data(i).dBdt, ...
                               processed_data(i).delta_B, processed_data(i).freq, ...
                               processed_data(i).D_ratio,processed_data(i).temp);
end

% 计算误差
valid_idx = all_actual ~= 0; 
actual_valid = all_actual(valid_idx);

% 各模型误差指标
[RMSE_igse, MAE_igse, MaxError_igse, MAPE_igse] = calc_errors(pred_igse, all_actual);
[RMSE_mse, MAE_mse, MaxError_mse, MAPE_mse] = calc_errors(pred_mse, all_actual);
[RMSE_dcm, MAE_dcm, MaxError_dcm, MAPE_dcm] = calc_errors(pred_dcm, all_actual);

% 输出误差指标
fprintf('=== IGSE模型误差指标 ===\n');
fprintf('RMSE: %.2f W/m³\n', RMSE_igse);
fprintf('MAE:  %.2f W/m³\n', MAE_igse);
fprintf('Max Error: %.2f W/m³\n', MaxError_igse);
fprintf('MAPE: %.2f%%\n\n', MAPE_igse);

fprintf('=== MSE模型误差指标 ===\n');
fprintf('RMSE: %.2f W/m³\n', RMSE_mse);
fprintf('MAE:  %.2f W/m³\n', MAE_mse);
fprintf('Max Error: %.2f W/m³\n', MaxError_mse);
fprintf('MAPE: %.2f%%\n\n', MAPE_mse);

fprintf('=== DT-IGSE模型误差指标 ===\n');
fprintf('RMSE: %.2f W/m³\n', RMSE_dcm);
fprintf('MAE:  %.2f W/m³\n', MAE_dcm);
fprintf('Max Error: %.2f W/m³\n', MaxError_dcm);
fprintf('MAPE: %.2f%%\n\n', MAPE_dcm);

% ========== 可视化 ==========
% 预测值与实际值对比图
figure('Name', '模型预测对比', 'Position', [100 100 1200 400]);
subplot(1,3,1);
scatter(all_actual, pred_igse, 'b', 'filled');
hold on;
plot([0 max(all_actual)], [0 max(all_actual)], 'r--');
title(sprintf('IGSE模型 (MAPE=%.2f%%)', MAPE_igse));
xlabel('实际损耗 (W/m³)');
ylabel('预测损耗 (W/m³)');
axis equal;
grid on;

subplot(1,3,2);
scatter(all_actual, pred_mse, 'g', 'filled');
hold on;
plot([0 max(all_actual)], [0 max(all_actual)], 'r--');
title(sprintf('MSE模型 (MAPE=%.2f%%)', MAPE_mse));
xlabel('实际损耗 (W/m³)');
ylabel('预测损耗 (W/m³)');
axis equal;
grid on;

subplot(1,3,3);
scatter(all_actual, pred_dcm, 'm', 'filled');
hold on;
plot([0 max(all_actual)], [0 max(all_actual)], 'r--');
title(sprintf('DT-IGSE模型 (MAPE=%.2f%%)', MAPE_dcm));
xlabel('实际损耗 (W/m³)');
ylabel('预测损耗 (W/m³)');
axis equal;
grid on;

% 误差分布对比图
figure('Name', '误差分布对比', 'Position', [100 100 800 400]);
error_percent_igse = 100 * (pred_igse(valid_idx) - actual_valid) ./ actual_valid;
error_percent_mse = 100 * (pred_mse(valid_idx) - actual_valid) ./ actual_valid;
error_percent_dcm = 100 * (pred_dcm(valid_idx) - actual_valid) ./ actual_valid;

histogram(error_percent_igse, 'BinWidth', 2, 'FaceColor', 'b', 'FaceAlpha', 0.5);
hold on;
histogram(error_percent_mse, 'BinWidth', 2, 'FaceColor', 'g', 'FaceAlpha', 0.5);
histogram(error_percent_dcm, 'BinWidth', 2, 'FaceColor', 'm', 'FaceAlpha', 0.5);
title('模型误差分布对比');
xlabel('相对误差 (%)');
ylabel('样本数');
legend('IGSE模型', 'MSE模型', 'DT-IGSE模型');
grid on;

% ========== 模型函数 ==========
function P_pred = igse_model(params, dBdt, delta_B, freq)
    k_i = params(1);
    alpha = params(2);
    beta = params(3);
    T = 1/freq;
    integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
    P_pred = (k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
end

function P_mse = mse_model(params, f_eq, delta_B, freq)
    k_i = params(1);
    alpha = params(2);
    beta = params(3);
    Cm = params(4); % MSE修正系数
    P_mse = Cm * k_i * (f_eq^(alpha-1)) * freq * (delta_B^beta);
end

% function P_dcm = dcm_igse_model(params, dBdt, delta_B, freq, D_ratio)
%     k_i = params(1);
%     alpha = params(2);
%     beta = params(3);
%     CD = params(4); % 占空比修正系数
%     CP = params(5);
% 
%     T = 1/freq;
%     integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
% 
%     % DCM-IGSE公式: Pv = D(1-D)^CD * (k_i/T) * ∫|dB/dt|^α ΔB^(β-α) dt
%     % 其中CD = f(D_ratio)是占空比修正函数
%     % P_dcm = 1/((D_ratio*(1-D_ratio))^CD) * (k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
%     P_dcm = 1/((D_ratio)^CD) * (k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
%     % P_dcm = 1/((D_ratio)*CD) * (k_i / T) * trapz(linspace(0,D_ratio*T,length(dBdt)), integrand)+1/((1-D_ratio)*CP) * (k_i / T) * trapz(linspace(D_ratio*T,T,length(dBdt)), integrand);
%     % P_dcm = ((delta_B)^2)*CD+ (delta_B)*CP+(k_i / T) * trapz(linspace(0,T,length(dBdt)), integrand);
% end

function P_dcm = dcm_igse_model(params, dBdt, delta_B, freq, D_ratio, T)
    k_i = params(1);
    alpha = params(2);
    % beta改为温度的三次函数: beta(T) = a0 + a1*T + a2*T² + a3*T³
    beta_coeffs = params(3:6); % [a0, a1, a2, a3]
    CD = params(7); % 占空比修正系数
    CP = params(8);
     % 特征频率计算
    f1 = freq/(2*D_ratio);          % 上升段特征频率
    f2 = freq/(2*(1-D_ratio));      % 下降段特征频率
    % 计算温度相关的beta值
    % beta = beta_coeffs(1) + beta_coeffs(2)*T + beta_coeffs(3)*T^2 + beta_coeffs(4)*T^3;
    beta = beta_coeffs(1) ;
    alpha1=beta_coeffs(2) ;
    % TEMP = beta_coeffs(4) +beta_coeffs(2)*T^-1;
    TEMP = beta_coeffs(4)+ beta_coeffs(3)*T +beta_coeffs(2)*T^-1;
    % TEMP=0;
    % TEMP = beta_coeffs(4)-beta_coeffs(3)*T + beta_coeffs(2)*T^2;
    % TEMP =  beta_coeffs(2)*T^-1;
    T_period = 1/freq;
    integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
    P_dcm = (1/(D_ratio))^CD * (k_i / T_period) * trapz(linspace(0,T_period,length(dBdt)), integrand)+TEMP;
    % P_base  = (k_i ) * trapz(linspace(0,T_period,length(dBdt)), integrand);
    %  % 频率相关损耗调整
    % P_f1 = CD * (P_base *f1)^(1-alpha1); % 频率缩放项
    % P_f2 = CD * (P_base *f2)^(1-alpha1);
    %    % 占空比权重函数 (sigmoid形式，D=0.5时为0.5)
    % w1 = 1/(1+exp(-CD*(D_ratio-0.5)));
    % w2 = 1 - w1;
    % 
    % % 最终预测损耗
    % P_dcm = w1*P_f1 + w2*P_f2;
end

% 
% function P_dcm = dcm_igse_model(params, dBdt,delta_B, freq , D  ,Tem)
%     % 参数解包
%     k_i = params(1);   % 基础损耗系数
%     alpha = params(2);  
%     % dBdt指数
%     beta_coeffs = params(3:6);     % ΔB指数
%     beta=beta_coeffs(1);
%     CD = params(4);   % 占空比修正系数
%     T=1/freq;
%     % 关键物理量计算
%     duration_rise = T * D;            % 上升时间
%     duration_fall = T * (1-D);        % 下降时间
%     avg_dBdt = abs(delta_B / T);      % 平均扫频率
% 
%     % 有效扫频率计算 (核心修正)
%     dBdt_rise = median(dBdt(dBdt > 0));   % 上升段典型dBdt
%     dBdt_fall = -median(dBdt(dBdt < 0));  % 下降段典型dBdt (取正值)
%     effective_dBdt = (dBdt_rise * duration_rise + dBdt_fall * duration_fall) / T;
% 
%     % 占空比影响因子 (指数形式保证D=0.5时因子为1)
%     D_factor = exp(CD * (D - 0.5)^2);
%     TEMP = beta_coeffs(4)+beta_coeffs(3)*Tem + beta_coeffs(2)*Tem^-1;
%     % 修改的IGSE积分 (保持原始频率项不变)
%     integrand = abs(dBdt).^alpha .* delta_B.^(beta-alpha);
%     P_base = (k_i / T) * trapz(linspace(0, T, length(dBdt)), integrand);
% 
%     % 最终预测 (关键修正: 使用有效扫频率替代频率缩放)
%     P_dcm = TEMP + P_base * (effective_dBdt / avg_dBdt) * D_factor;
% end

% function [rise_peak, fall_peak] = calc_peaks(dBdt, t, T, D)
%     % 上升沿定位 (精确到波形区间)
%     rise_start = 0;
%     rise_end = D*T*1.05;  % 增加5%安全边界
% 
%     % 下降沿定位
%     fall_start = D*T*0.95; % 增加5%安全边界
%     fall_end = T;
% 
%     rise_seg = dBdt(t >= rise_start & t <= rise_end & dBdt > 0);
%     fall_seg = dBdt(t >= fall_start & t <= fall_end & dBdt < 0);
% 
%     % 取峰值绝对值
%     rise_peak = max(abs(rise_seg));
%     fall_peak = max(abs(fall_seg));
% 
%     % 异常处理 (确保特征值合理)
%     if isempty(rise_peak), rise_peak = 0.01*max(abs(dBdt)); end
%     if isempty(fall_peak), fall_peak = 0.01*max(abs(dBdt)); end
% end
% 
% function P_dcm = dcm_igse_model(params, dBdt,delta_B, freq , D  ,Tem)
%     k = params(1);
%     alpha_min = params(2);
%     beta = params(3);
%     k_D = params(4);
%     gamma = params(5);
%     delta = params(6);
%     T=1/freq;
%     t = linspace(0, T, 1024); 
%     [rise_max, fall_max] = calc_peaks(dBdt, t, T, D);
%     r = max(rise_max, eps)/max(fall_max, eps); % 避免除零
%      % 动态α函数 (sigmoid调整)
%     alpha_rise = alpha_min + k_D/(1+exp(-gamma*(log10(r)-delta)));
%     alpha_fall = alpha_min + k_D/(1+exp(-gamma*(-log10(r)-delta)));
% 
%     % 3. 分阶段积分
%     idx_rise = find(dBdt > 0 & t < D*T);
%     idx_fall = find(dBdt < 0 & t > D*T);
% 
%     % 上升沿积分 (使用α_rise)
%     integrand_rise = abs(dBdt(idx_rise)).^alpha_rise .* delta_B^(beta - alpha_rise);
%     P_rise = (k/(T)) * trapz(t(idx_rise), integrand_rise);
% 
%     % 下降沿积分 (使用α_fall)
%     integrand_fall = abs(dBdt(idx_fall)).^alpha_fall .* delta_B^(beta - alpha_fall);
%     P_fall = (k/(T)) * trapz(t(idx_fall), integrand_fall);
% 
%     % 4. 耦合效应补偿 (D<0.2时增强)
%     if D < 0.2
%         coupling_factor = 1 + 0.3*(log10(0.2/max(D,0.05)))^1.5;
%     elseif D > 0.8
%         coupling_factor = 1 + 0.3*(log10(0.2/max((1-D),0.05)))^1.5;
%     else
%         coupling_factor = 1;
%     end
% 
%     P_dcm = (P_rise + P_fall) * coupling_factor;
% end
function err = objective_igse(params, samples)
    err = 0;
    real_p = params;
    real_p(1) = 10^params(1); % 【在计算误差前，先在函数内部把 log 还原成 k】
    for i = 1:length(samples)
        s = samples(i);
        pred = igse_model(real_p, s.dBdt, s.delta_B, s.freq);
        % 【改用相对误差平方】
        err = err + ((pred - s.actual_loss) / s.actual_loss)^2;
    end
    err = sqrt(err / length(samples));
end

function err = objective_mse(params, samples)
    err = 0;
    real_p = params;
    real_p(1) = 10^params(1); % 还原 k
    for i = 1:length(samples)
        s = samples(i);
        pred = mse_model(real_p, s.f_eq, s.delta_B, s.freq);
        err = err + ((pred - s.actual_loss) / s.actual_loss)^2;
    end
    err = sqrt(err / length(samples));
end

function err = objective_dcm(params, samples)
    err = 0;
    real_p = params;
    real_p(1) = 10^params(1); % 还原 k
    for i = 1:length(samples)
        s = samples(i);
        pred = dcm_igse_model(real_p, s.dBdt, s.delta_B, s.freq, s.D_ratio, s.temp);
        err = err + ((pred - s.actual_loss) / s.actual_loss)^2;
    end
    err = sqrt(err / length(samples));
end

% function err = objective_igse(params, samples)
%     err = 0;
%     for i = 1:length(samples)
%         s = samples(i);
%         pred = igse_model(params, s.dBdt, s.delta_B, s.freq);
%         err = err + (pred - s.actual_loss)^2;
%     end
%     err = sqrt(err / length(samples));
% end
% 
% function err = objective_mse(params, samples)
%     err = 0;
%     for i = 1:length(samples)
%         s = samples(i);
%         pred = mse_model(params, s.f_eq, s.delta_B, s.freq);
%         err = err + (pred - s.actual_loss)^2;
%     end
%     err = sqrt(err / length(samples));
% end
% 
% % function err = objective_dcm(params, samples)
% %     err = 0;
% %     for i = 1:length(samples)
% %         s = samples(i);
% %         pred = dcm_igse_model(params, s.dBdt, s.delta_B, s.freq, s.D_ratio);
% %         err = err + (pred - s.actual_loss)^2;
% %     end
% %     err = sqrt(err / length(samples));
% % end
% 
% function err = objective_dcm(params, samples)
%     err = 0;
%     for i = 1:length(samples)
%         s = samples(i);
%         % T = temperatures(i); % 获取当前样本的温度
%         pred = dcm_igse_model(params, s.dBdt, s.delta_B, s.freq, s.D_ratio, s.temp);
%         err = err + (pred - s.actual_loss)^2;
%     end
%     err = sqrt(err / length(samples));
% end

function [rmse, mae, maxerr, mape] = calc_errors(pred, actual)
    valid_idx = actual ~= 0;
    actual_valid = actual(valid_idx);
    pred_valid = pred(valid_idx);
    
    rmse = sqrt(mean((pred - actual).^2));
    mae = mean(abs(pred - actual));
    maxerr = max(abs(pred - actual));
    mape = 100 * mean(abs((actual_valid - pred_valid) ./ actual_valid));
end
% ========== 占空比分组误差分析 ==========
all_D_ratios = [processed_data.D_ratio]';
valid_idx = all_actual ~= 0;
actual_valid = all_actual(valid_idx);

% 1. 定义占空比分组 (建议5-6组)
D_edges = linspace(0, 1, 6);  % 产生5个区间：[0-0.2), [0.2-0.4),..., [0.8-1]
D_centers = (D_edges(1:end-1) + D_edges(2:end))/2;  % 计算各组中心值

% 2. 按占空比离散化分组 (使用discretize函数)
D_groups = discretize(all_D_ratios, D_edges);
valid_D_groups = D_groups(valid_idx);  % 只保留有效数据对应的分组

% 3. 准备各模型的绝对百分比误差
errors_igse = 100 * abs(pred_igse(valid_idx) - actual_valid) ./ actual_valid;
errors_mse = 100 * abs(pred_mse(valid_idx) - actual_valid) ./ actual_valid;
errors_dcm = 100 * abs(pred_dcm(valid_idx) - actual_valid) ./ actual_valid;

% 4. 计算各组的平均误差 (手动实现更稳健)
n_groups = length(D_edges) - 1;
group_errors = zeros(n_groups, 3);  % 5组×3模型

for g = 1:n_groups
    group_mask = (valid_D_groups == g);
    if sum(group_mask) > 0  % 如果组内有数据
        group_errors(g, 1) = mean(errors_igse(group_mask));
        group_errors(g, 2) = mean(errors_mse(group_mask));
        group_errors(g, 3) = mean(errors_dcm(group_mask));
    else
        group_errors(g, :) = NaN;  % 标记空组
    end
end

% ========== 占空比误差对比可视化 ==========
figure('Name', 'Effect of duty cycle on error', 'Position', [100 100 1200 400]);

% 1. 各模型在不同占空比组的MAPE对比
subplot(1,3,1);
hold on;
plot(D_centers, group_errors(:,1), 'bo-', 'LineWidth', 2, 'MarkerSize', 8);
plot(D_centers, group_errors(:,2), 'gs-', 'LineWidth', 2, 'MarkerSize', 8);
plot(D_centers, group_errors(:,3), 'md-', 'LineWidth', 2, 'MarkerSize', 8);
title('Comparison of model errors at different duty cycles');
xlabel('duty cycle');
ylabel('Mean absolute percentage error(MAPE)');
legend('IGSE model', 'MSE model', 'DT-IGSE model', 'Location', 'best');
grid on;

% 2. 样本数量分布（显示数据分布情况）
subplot(1,3,2);
group_counts = histcounts(all_D_ratios, D_edges);
bar(D_centers, group_counts, 0.8, 'FaceColor', [0.7 0.7 0.9]);
title('Number of samples in each duty cycle group');
xlabel('duty cycle');
ylabel('sample size');
grid on;

% 3. 误差箱线图（显示误差分布）
subplot(1,3,3);
hold on;
colors = lines(3);

% 收集各组的误差数据
all_groups = [];
all_errors = [];
model_labels = {};

for g = 1:n_groups
    group_mask = (valid_D_groups == g);
    
    % IGSE
    all_groups = [all_groups; repmat(g, sum(group_mask), 1)];
    all_errors = [all_errors; errors_igse(group_mask)];
    model_labels = [model_labels; repmat({'IGSE'}, sum(group_mask), 1)];
    
    % MSE
    all_groups = [all_groups; repmat(g, sum(group_mask), 1)];
    all_errors = [all_errors; errors_mse(group_mask)];
    model_labels = [model_labels; repmat({'MSE'}, sum(group_mask), 1)];
    
    % DCM-IGSE
    all_groups = [all_groups; repmat(g, sum(group_mask), 1)];
    all_errors = [all_errors; errors_dcm(group_mask)];
    model_labels = [model_labels; repmat({'DT-IGSE'}, sum(group_mask), 1)];
end

% 创建分组的箱线图
boxplot(all_errors, {all_groups, model_labels}, 'colors', colors,...
        'factorgap', [10 2], 'labelverbosity', 'majorminor');
title('Distribution of errors for each duty cycle group');
xlabel('duty cycle group');
ylabel('relative error (%)');
grid on;

% 添加说明文本
text_h = findobj(gca, 'Type', 'text');
for i = 1:length(text_h)
    pos = get(text_h(i), 'Position');
    if pos(2) < -10
        set(text_h(i), 'Position', pos + [0 10 0]);  % 移动组标签位置
    end
end

temp_edges = [ 25, 50, 75, max(temperatures)]; % 温度分组边界（可调整）
temp_centers = (temp_edges(1:end-1) + temp_edges(2:end))/2;      % 计算各组中心值all_temps = [processed_data.temp]';
all_temps = [processed_data.temp]';
temp_groups = discretize(all_temps, temp_edges); % 温度离散化分组
valid_temp_groups = temp_groups(valid_idx);      % 只保留有效数据的分组

% 计算各温度组的平均误差
n_temp_groups = length(temp_edges) - 1;
temp_group_errors = zeros(n_temp_groups, 3); % 温度组×3模型

for g = 1:n_temp_groups
    group_mask = (valid_temp_groups == g);
    if sum(group_mask) > 0
        temp_group_errors(g, 1) = mean(errors_igse(group_mask));
        temp_group_errors(g, 2) = mean(errors_mse(group_mask));
        temp_group_errors(g, 3) = mean(errors_dcm(group_mask));
    else
        temp_group_errors(g, :) = NaN;
    end
end
% ===== 新增：温度误差可视化 =====
figure('Name', 'Effect of temperature on error', 'Position', [100 100 1200 800]);

% 1. 各模型在不同温度组的MAPE对比
subplot(1,3,1);
hold on;
plot(temp_centers, temp_group_errors(:,1), 'bo-', 'LineWidth', 2, 'MarkerSize', 8);
plot(temp_centers, temp_group_errors(:,2), 'gs-', 'LineWidth', 2, 'MarkerSize', 8);
plot(temp_centers, temp_group_errors(:,3), 'md-', 'LineWidth', 2, 'MarkerSize', 8);
title('Comparison of model errors at different temperatures');
xlabel('Temperature (°C)');
ylabel('Mean absolute percentage error(MAPE)');
legend('IGSE model', 'MSE model', 'DT-IGSE model', 'Location', 'best');
grid on;

% 2. 温度样本数量分布
subplot(1,3,2);
temp_counts = histcounts(all_temps, temp_edges);
bar(temp_centers, temp_counts, 0.8, 'FaceColor', [0.9 0.7 0.7]);
title('Number of samples in each temperature group');
xlabel('Temperature (°C)');
ylabel('sample size');
grid on;

% 3. 温度误差箱线图
subplot(1,3,3);
hold on;
colors = lines(3);

% 收集温度组的误差数据
all_temp_groups = [];
all_temp_errors = [];
temp_model_labels = {};

for g = 1:n_temp_groups
    group_mask = (valid_temp_groups == g);
    
    % IGSE
    all_temp_groups = [all_temp_groups; repmat(g, sum(group_mask), 1)];
    all_temp_errors = [all_temp_errors; errors_igse(group_mask)];
    temp_model_labels = [temp_model_labels; repmat({'IGSE'}, sum(group_mask), 1)];
    
    % MSE
    all_temp_groups = [all_temp_groups; repmat(g, sum(group_mask), 1)];
    all_temp_errors = [all_temp_errors; errors_mse(group_mask)];
    temp_model_labels = [temp_model_labels; repmat({'MSE'}, sum(group_mask), 1)];
    
    % DCM-IGSE
    all_temp_groups = [all_temp_groups; repmat(g, sum(group_mask), 1)];
    all_temp_errors = [all_temp_errors; errors_dcm(group_mask)];
    temp_model_labels = [temp_model_labels; repmat({'DT-IGSE'}, sum(group_mask), 1)];
end

% 创建分组的箱线图
boxplot(all_temp_errors, {all_temp_groups, temp_model_labels}, 'colors', colors,...
        'factorgap', [10 2], 'labelverbosity', 'majorminor');
title('各温度组误差分布');
xlabel('温度组');
ylabel('相对误差 (%)');
grid on;

% 调整标签位置
text_h = findobj(gca, 'Type', 'text');
for i = 1:length(text_h)
    pos = get(text_h(i), 'Position');
    if pos(2) < -10
        set(text_h(i), 'Position', pos + [0 10 0]);
    end
end
% ===== 新增：温度分组误差指标输出 =====
fprintf('=== 各温度组平均误差 ===\n');
fprintf('温度组(°C) | IGSE误差(％) | MSE误差(％) | DT-IGSE误差(％)\n');
for g = 1:n_temp_groups
    fprintf('[%2d-%2d]   | %8.2f     | %8.2f    | %8.2f\n', ...
            temp_edges(g), temp_edges(g+1), ...
            temp_group_errors(g,1), temp_group_errors(g,2), temp_group_errors(g,3));
end

% ========== 新增：温度和占空比的三维可视化 ==========

% 获取所有样本的占空比和温度数据
D_ratios = [processed_data.D_ratio];
temps = [processed_data.temp];
actual_losses = [processed_data.actual_loss];

% 创建网格数据用于曲面拟合
[X, Y] = meshgrid(linspace(min(D_ratios), max(D_ratios), 20),...
                 linspace(min(temps), max(temps), 20));
                 
% 使用griddata进行插值 (可以更改插值方法)
Z_loss = griddata(D_ratios, temps, actual_losses, X, Y, 'natural');
% 如果使用matlab R2020b以上版本，推荐使用：
% F = scatteredInterpolant(D_ratios', temps', actual_losses', 'natural', 'linear');
% Z_loss = F(X, Y);

% 绘制三维曲面图
figure('Name', 'Loss-duty cycle-temperature three-dimensional relationship', 'Position', [100 100 1000 800], 'Color', 'white');
subplot(2,1,1);
surf(X, Y, Z_loss, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
hold on;
% scatter3(D_ratios, temps, actual_losses, 60, actual_losses, 'filled', 'MarkerEdgeColor', 'k');
hold off;

% 美化图形
shading interp;
colormap(jet);
h_colorbar = colorbar;
ylabel(h_colorbar, 'Actual loss (W/m³)', 'FontSize', 12);
title('Core Loss vs. Duty Cycle and Temperature (Actual)');
xlabel('duty cycle', 'FontSize', 12);
ylabel('Temperature. (°C)', 'FontSize', 12);
zlabel('Actual loss (W/m³)', 'FontSize', 12);
view(-45, 30);
grid on;

% 添加等高线投影
subplot(2,1,2);
contourf(X, Y, Z_loss, 20, 'LineColor', 'none');
hold on;
% scatter(D_ratios, temps, 60, actual_losses, 'filled', 'MarkerEdgeColor', 'k');
hold off;

% 美化等高线图
colormap(jet);
h_colorbar = colorbar;
ylabel(h_colorbar, 'Actual loss (W/m³)', 'FontSize', 12);
title('Duty cycle-temperature contour of loss distribution');
xlabel('duty cycle', 'FontSize', 12);
ylabel('Temperature. (°C)', 'FontSize', 12);
grid on;

% ========== 新增：不同模型的预测值三维可视化 ==========
models = {
    {'IGSE Forecast', pred_igse},...
    {'DT-IGSE Forecast', pred_dcm},...
    {'MSE Forecast', pred_mse}
};

colors = {
    [0.1, 0.5, 0.9],...  % IGSE - 蓝色
    [0.9, 0.3, 0.5],...  % DCM-IGSE - 红色
    [0.4, 0.8, 0.2]      % MSE - 绿色
};

% 为每个模型创建三维子图
figure('Name', 'Comparison of model predictions', 'Position', [100 100 1400 700], 'Color', 'white');
actual_losses=transpose(actual_losses);
for mod_idx = 1:numel(models)
    model_name = models{mod_idx}{1};
    predicted = models{mod_idx}{2};
    
    % 创建插值曲面
    Z_pred = griddata(D_ratios, temps, predicted', X, Y, 'natural');
    
    subplot(2, 3, mod_idx);
    surf(X, Y, Z_pred, 'FaceAlpha', 0.8, 'FaceColor', colors{mod_idx}, 'EdgeColor', 'none');
    hold on;
    % scatter3(D_ratios, temps, predicted, 30, actual_losses, 'filled', 'MarkerEdgeColor', 'k');
    hold off;
    
    % 美化图形
    shading interp;
    title([model_name 'curved surface']);
    xlabel('duty cycle');
    ylabel('Temperature (°C)');
    zlabel('Predicting wear and tear (W/m³)');
    view(-45, 30);
    grid on;
    
    subplot(2, 3, mod_idx+3);
    contourf(X, Y, abs(Z_pred - Z_loss), 20, 'LineColor', 'none');
    title([model_name 'error distribution']);
    xlabel('duty cycle');
    ylabel('Temperature (°C)');
    
    clim([min(abs(predicted-actual_losses)) max(abs(predicted-actual_losses))]);
    hcb = colorbar;
    ylabel(hcb, 'absolute error (W/m³)');
    hold on;
    % scatter(D_ratios, temps, 30, abs(predicted-actual_losses), 'filled', 'MarkerEdgeColor', 'k');
    hold off;
end


