clc;
clear;
close all;

%% ========== 数据读取 ==========
filename = 'Material.xlsx';

% 读取指定行列范围（行1088-2370，列A-E假设为有效数据列）
start_row = 1088;  % Excel实际起始行号
end_row = 2370;
columns_range = 'A:AZ';  % 根据实际情况修改列范围

% 读取数据表（包括标题行）
full_data = readtable(filename, 'Range', 'A1'); % 读取表头
data_range = [columns_range(1) num2str(start_row) ':' columns_range(3:end) num2str(end_row)];
raw_data = xlsread(filename, data_range); % 仅读取数值数据部分

%% ========== 核心配置 ==========
valid_rows = size(raw_data,1); % 实际有效数据行数
temps = unique(raw_data(:,1)); 
wave_types = unique(raw_data(:,4));
N_samples_per_cycle = 1024;
threshold_coef = 0.1; % 占空比检测阈值

%% ========== 数据预处理 ==========
processed_data = struct('dBdt', [], 'delta_B', [], 'freq', [],...
                        'temp', [], 'wave_type', [], 'D', [],...
                        'actual_loss', []);

for i = 1:valid_rows
    B_wave = raw_data(i,5:end);
    freq = raw_data(i,2);
    dt = 1/(freq*N_samples_per_cycle);
    
    % dB/dt计算（优化二阶中心差分）
    dBdt = gradient(B_wave, dt); % 代替手动差分
    
    % 占空比自动检测
    max_B = max(B_wave);
    min_B = min(B_wave);
    threshold = min_B + (max_B - min_B)*threshold_coef;
    rising_edges = find(diff(B_wave >= threshold) > 0);
    falling_edges = find(diff(B_wave >= threshold) < 0);
    
    if isempty(rising_edges) || isempty(falling_edges)
        D = 0.2;  % 默认值
    else
        pulse_width = falling_edges(1) - rising_edges(1);
        D = pulse_width / N_samples_per_cycle;
    end
    
    % 存储有效数据
    processed_data(i).dBdt = dBdt;
    processed_data(i).delta_B = max_B - min_B;
    processed_data(i).actual_loss = raw_data(i,3);
    processed_data(i).freq = freq;
    processed_data(i).temp = raw_data(i,1);
    processed_data(i).wave_type = raw_data(i,4);
    processed_data(i).D = D;
end

%% ========== 模型参数拟合 ==========
params = struct('k', [], 'alpha', [], 'beta', [], 'gamma', []);
grouped_data = groupByTempWaveform(processed_data); % 自定义分组函数

for t = 1:length(temps)
    current_temp = temps(t);
    fprintf('Processing temperature: %.0f℃\n', current_temp);
    
    for w = 1:length(wave_types)
        current_wave = wave_types(w);
        samples = grouped_data{t,w};
        
        if isempty(samples)
            params(t,w).k = NaN;
            params(t,w).alpha = NaN;
            params(t,w).beta = NaN;
            params(t,w).gamma = NaN;
            continue;
        end
        
        % 遗传算法优化（防止局部最优）
        options = optimoptions('particleswarm','SwarmSize',50,'MaxIterations',100);
        lb = [1e-8, 1.2, 2.0, 0.05];  % 参数下限
        ub = [1e-3, 2.5, 3.5, 0.5];   % 参数上限
        opt_params = particleswarm(@(p) mapeObjective(p, samples),4,lb,ub,options);
        
        % 存储优化结果
        params(t,w).k = opt_params(1);
        params(t,w).alpha = opt_params(2);
        params(t,w).beta = opt_params(3);
        params(t,w).gamma = opt_params(4);
    end
end

%% ========== 模型验证与MAPE计算 ==========
[mape_table, error_dist] = calculateMAPE(processed_data, params);

% 输出MAPE结果
fprintf('\n===== 分类MAPE结果 =====\n');
disp(mape_table);

% 绘制误差分布直方图
figure('Name','总体误差分布');
histogram([error_dist.errors],'Normalization','probability');
xlabel('相对误差 (%)'); ylabel('频率');
title(sprintf('总体MAPE: %.2f%%', mean([error_dist.errors])));

%% ========== 核心函数 ==========
function group = groupByTempWaveform(data)
    temps = unique([data.temp]);
    wave_types = unique([data.wave_type]);
    group = cell(length(temps), length(wave_types));
    
    for i = 1:length(data)
        t = find(temps == data(i).temp);
        w = find(wave_types == data(i).wave_type);
        group{t,w} = [group{t,w},data(i)];
    end
end

function error = mapeObjective(params, samples)
    total_err = 0;
    valid_counts = 0;
    
    for s = 1:length(samples)
        pred = improved_igse(params, samples(s).dBdt, samples(s).delta_B,...
                            samples(s).freq, samples(s).D);
        if samples(s).actual_loss == 0 || isnan(pred)
            continue;
        end
        
        total_err = total_err + abs(pred - samples(s).actual_loss)/samples(s).actual_loss;
        valid_counts = valid_counts + 1;
    end
    
    if valid_counts == 0
        error = inf;
    else
        error = total_err / valid_counts * 100; % MAPE百分比
    end
end

function [mape_table, error_data] = calculateMAPE(data, params)
    error_data = struct('temp', [], 'wave', [], 'mape', [], 'errors', []);
    mape_table = table('Size', [length(unique([data.temp]))*length(unique([data.wave_type])),4],...
                      'VariableNames', {'温度', '波形', '样本数', 'MAPE'},...
                      'VariableTypes', {'double','double','double','double'});
    row_idx = 1;
    
    temps = unique([data.temp]);
    waves = unique([data.wave_type]);
    
    for t = 1:length(temps)
        for w = 1:length(waves)
            mask = ([data.temp] == temps(t)) & ([data.wave_type] == waves(w));
            samples = data(mask);
            
            if isempty(samples)
                continue;
            end
            
            errors = zeros(length(samples),1);
            for s = 1:length(samples)
                p = params(t,w);
                pred = improved_igse([p.k, p.alpha, p.beta, p.gamma],...
                                    samples(s).dBdt, samples(s).delta_B,...
                                    samples(s).freq, samples(s).D);
                if samples(s).actual_loss == 0
                    errors(s) = NaN;
                else
                    errors(s) = abs(pred - samples(s).actual_loss)/samples(s).actual_loss*100;
                end
            end
            
            valid_errors = errors(~isnan(errors));
            current_mape = mean(valid_errors);
            
            mape_table(row_idx,:) = {temps(t), waves(w), length(valid_errors), current_mape};
            error_data(row_idx).temp = temps(t);
            error_data(row_idx).wave = waves(w);
            error_data(row_idx).mape = current_mape;
            error_data(row_idx).errors = valid_errors;
            row_idx = row_idx + 1;
        end
    end
end

function P_pred = improved_igse(params, dBdt, delta_B, freq, D)
    k = params(1); alpha = params(2); beta = params(3); gamma = params(4);
    T = 1/freq;
    integrand = abs(dBdt).^alpha .* delta_B.^(beta - alpha);
    D_factor = (D*(1-D))^gamma;  % 占空比调整因子
    
    if D_factor < 1e-6  % 防止除零错误
        D_factor = 1e-6;
    end
    
    P_pred = (k / D_factor) * (1/T) * trapz(linspace(0,T,length(dBdt)), integrand);
end
