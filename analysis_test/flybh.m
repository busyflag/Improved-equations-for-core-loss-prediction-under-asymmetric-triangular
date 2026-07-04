clc;
clear;
close all;

%% 数据读取与预处理
filename = 'Material1.xlsx';
data = xlsread(filename);

% 提取第i行数据（示例：第1432行）
row_index = 1622;               
temperature = data(row_index, 1);   % 温度 (°C)
frequency = data(row_index, 2);     % 基波频率 (Hz)
core_loss_actual = data(row_index, 3);  % 实际磁芯损耗 (W/m³)
B_samples = data(row_index, 5:end); % 磁通密度采样点 (T)

% 移除可能的NaN值
B_samples = B_samples(~isnan(B_samples));
N = length(B_samples);             % 采样点数
T = 1 / frequency;                 % 波形周期 (s)
dt = T / N;                        % 时间步长 (s)
t = 0:dt:T-dt;                     % 时间轴

%% 傅里叶分解与频谱分析
% 执行FFT
B_fft = fft(B_samples);            % 傅里叶变换
B_mag = abs(B_fft) / N;            % 幅值归一化
f_axis = (0:N-1) * (1/T);          % 频率轴 (Hz)

% 提取谐波幅值（忽略直流分量）
harmonics_idx = 2:N*2/3;             % 仅分析基波和前N/2-1次谐波
harmonics_freq = f_axis(harmonics_idx);
harmonics_B = 2 * B_mag(harmonics_idx);  % 修正单边频谱幅值

%% 修正斯坦麦茨方程参数（示例值）
T0 = 25;   % 参考温度 (°C)
k0 = 3.3789;
gamma = 0.0497;
b0 = 1.3437;
b1 = 0.0063;
b2 = -0.0274;
c0 = 2.1920;
c1 = 0.0022;

%% 计算各谐波损耗并叠加
core_loss_harmonics = zeros(size(harmonics_freq));

for i = 1:length(harmonics_freq)
    f = harmonics_freq(i);          % 谐波频率 (Hz)
    B_max = harmonics_B(i);         % 谐波幅值 (T)
    
    % 温度修正项
    temp_term = exp(-gamma * (temperature - T0));
    
    % 频率指数项
    f_exp = b0 + b1*temperature + b2*sqrt(temperature);
    
    % 磁密指数项
    B_exp = c0 * exp(c1 * temperature);
    
    % 单谐波损耗计算
    core_loss_harmonics(i) = k0 * temp_term * f^f_exp * B_max^B_exp;
end

% 总损耗预测值（叠加所有谐波）
core_loss_pred = sum(core_loss_harmonics);

%% 输出结果与误差分析
fprintf('===== 第%d行数据计算结果 =====\n', row_index);
fprintf('实际磁芯损耗: %.4f W/m³\n', core_loss_actual);
fprintf('预测磁芯损耗: %.4f W/m³\n', core_loss_pred);
fprintf('相对误差: %.2f%%\n', 100*abs(core_loss_pred - core_loss_actual)/core_loss_actual);

%% 频谱可视化
figure;
stem(harmonics_freq/1e3, harmonics_B, 'b', 'LineWidth', 1.5); % 频率单位转换为kHz
xlabel('频率 (kHz)');
ylabel('磁通密度幅值 (T)');
title('磁通密度频谱分解');
grid on;

%% 损耗贡献分析
figure;
bar(harmonics_freq/1e3, core_loss_harmonics);
xlabel('频率 (kHz)');
ylabel('单谐波损耗 (W/m³)');
title('各谐波对总损耗的贡献');
grid on;

%% 波形重建验证（可选）
% 逆FFT验证频谱分解正确性
B_reconstructed = ifft(B_fft);
figure;
plot(t, B_samples, 'b', 'LineWidth', 1.5); hold on;
plot(t, real(B_reconstructed), 'r--', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('磁通密度 (T)');
legend('原始数据', '重建数据');
title('波形重建验证');