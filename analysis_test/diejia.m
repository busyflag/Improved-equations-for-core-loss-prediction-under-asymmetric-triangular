% % 读取数据文件（示例路径需替换为实际路径）
% filename = 'E:\数模\研究c题\Material1.xlsx';
% data = xlsread(filename);
% 
% % 提取数据列
% temperature = data(2:end, 1);        % 第1列：温度（°C）
% frequency = data(2:end, 2);          % 第2列：频率（Hz）
% core_loss = data(2:end, 3);          % 第3列：磁芯损耗（W/m³）
% waveform_type = data(2:end, 4);      % 第4列：波形类型（1=正弦波，2=三角波，3=梯形波）
% B_samples = data(2:end, 5:end);      % 第5-1028列：磁通密度采样点（T）
% 
% % 参数设置
% Fs = 10 * max(frequency);        % 采样频率（根据信号最高频率设定）
% N = size(B_samples, 2);          % 采样点数（1024）
% harmonic_threshold = 0.05;       % 谐波幅值阈值（保留>5%最大幅值的谐波）
% 
% % 修正SE方程参数（来自问题二拟合结果）
% k0 = 3.3789;
% gamma = 0.0497;
% b0 = 1.3437;
% b1 = 0.0063;
% b2 = -0.0274;
% c0 = 2.1920;
% c1 = 0.0022;
% 
% %% 分波形类型处理
% core_loss_pred = zeros(size(core_loss));
% 
% for idx = 1:size(B_samples, 1)
%     % 当前样本参数
%     T = temperature(idx);
%     f = frequency(idx);
%     B_data = B_samples(idx, :);
%     
%     if waveform_type(idx) == 1
%         % === 处理正弦波：直接使用SE方程 ===
%         B_max = max(B_data);      % 正弦波峰值
%         % 应用修正SE方程
%         k_T = k0 * exp(-gamma*(T - 25));
%         f_exp = b0 + b1*T + b2*sqrt(T);
%         B_exp = c0 * exp(c1*T);
%         P_total = k_T * (f^f_exp) * (B_max^B_exp);
%     else
%         % === 处理非正弦波：傅里叶分解 + SE叠加 ===
%         % 去直流分量
%         B_data = B_data - mean(B_data);
%         
%         % FFT分析
%         Y = fft(B_data);
%         P2 = abs(Y/N);
%         P1 = P2(1:N/2+1);
%         P1(2:end-1) = 2*P1(2:end-1);
%         f_axis = Fs*(0:(N/2))/N;
%         
%         % 提取主要谐波分量
%         [peaks, locs] = findpeaks(P1, 'MinPeakHeight', max(P1)*harmonic_threshold);
%         f_components = f_axis(locs);
%         B_components = peaks;
%         
%         % 计算各谐波损耗并累加
%         P_total = 0;
%         for i = 1:length(f_components)
%             f_i = f_components(i);
%             B_i = B_components(i);
%             
%             % 应用修正SE方程
%             k_T = k0 * exp(-gamma*(T - 25));
%             f_exp = b0 + b1*T + b2*sqrt(T);
%             B_exp = c0 * exp(c1*T);
%             P_i = k_T * (f_i^f_exp) * (B_i^B_exp);
%             
%             P_total = P_total + P_i;
%         end
%     end
%     
%     core_loss_pred(idx) = P_total;
% end
% 
% %% 误差分析与可视化
% % 计算误差指标
% RMSE = sqrt(mean((core_loss_pred - core_loss).^2));
% MAPE = mean(abs((core_loss_pred - core_loss) ./ core_loss)) * 100;
% 
% fprintf('=== 综合预测误差 ===\n');
% fprintf('RMSE: %.2f W/m³\n', RMSE);
% fprintf('MAPE: %.2f%%\n', MAPE);
% 
% % 按波形类型显示误差
% waveform_names = {'正弦波', '三角波', '梯形波'};
% for w_type = 1:3
%     mask = (waveform_type == w_type);
%     if sum(mask) == 0, continue; end
%     loss_true = core_loss(mask);
%     loss_pred = core_loss_pred(mask);
%     
%     rmse = sqrt(mean((loss_pred - loss_true).^2));
%     mape = mean(abs((loss_pred - loss_true) ./ loss_true)) * 100;
%     
%     fprintf('\n=== %s ===\n', waveform_names{w_type});
%     fprintf('样本数: %d\n', sum(mask));
%     fprintf('RMSE: %.2f W/m³\n', rmse);
%     fprintf('MAPE: %.2f%%\n', mape);
% end
% 
% % 绘制预测结果对比
% figure;
% subplot(2,1,1);
% scatter(core_loss, core_loss_pred, 40, 'filled');
% hold on;
% plot([0, max(core_loss)], [0, max(core_loss)], 'k--');
% xlabel('实际损耗 (W/m³)'); ylabel('预测损耗 (W/m³)');
% title('全样本预测对比');
% grid on;
% 
% subplot(2,1,2);
% residuals = core_loss_pred - core_loss;
% histogram(residuals, 20);
% xlabel('残差 (W/m³)'); ylabel('频数');
% title('残差分布');
% 
% %% 结果保存（示例）
% % 生成附件四格式数据
% sample_ids = (1:size(data,1))';
% waveform_results = waveform_type;  % 假设问题一已完成分类
% predicted_loss = round(core_loss_pred, 1);  % 保留1位小数

% %% 数据读取与预处理
% filename = 'E:\数模\研究c题\三角波.xlsx';   % 确保路径正确
% data = xlsread(filename);
% B_samples = data(2:end, 5:end);        % 提取所有磁通密度采样点（第5列开始）
% frequency = data(2:end, 2);            % 提取频率列（单位：Hz）
% 
% %% 提取第一个样本的磁通密度数据
% sample_idx = 1;                        % 选择第一个样本
% B_signal = B_samples(sample_idx, :);   % 获取该样本的磁通密度序列
% Fs = frequency(sample_idx) * length(B_signal); % 计算采样频率 = 基频 × 每周期采样点数
% N = length(B_signal);                   % 采样点数
% t = (0:N-1)/Fs;                        % 时间轴（单位：秒）
% 
% %% 快速傅里叶变换（FFT）
% Y = fft(B_signal);                     % 应用FFT
% A = 2 * abs(Y(1:N/2)) / N;             % 单边幅度谱（取前N/2点）
% phase = angle(Y(1:N/2));               % 相位（弧度）
% frequencies = Fs*(0:N/2-1)/N;          % 频率轴（单位：Hz）
% 
% %% 筛选主要频率分量（幅度阈值设为最大幅度的1%）
% threshold = max(A) * 0.01;             % 调整阈值可控制保留的分量数量
% significant_indices = find(A > threshold);
% A_sig = A(significant_indices);
% f_sig = frequencies(significant_indices);
% phase_sig = phase(significant_indices);
% 
% %% 重建信号
% B_reconstructed = zeros(1, N);
% for k = 1:length(A_sig)
%     B_reconstructed = B_reconstructed + A_sig(k) * sin(2*pi*f_sig(k)*t + phase_sig(k));
% end
% 
% %% 可视化对比原始信号与重建信号
% figure;
% subplot(2,1,1);
% plot(t, B_signal, 'b', 'LineWidth', 1.5);
% title('原始三角波信号');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% subplot(2,1,2);
% plot(t, B_reconstructed, 'r--', 'LineWidth', 1.5);
% title('重建信号（正弦波叠加）');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% %% 显示叠加公式参数
% disp('=== 主要正弦波分量参数 ===');
% fprintf('频率 (Hz)\t 幅度 (T)\t 相位 (rad)\n');
% for k = 1:length(A_sig)
%     fprintf('%.1f\t\t%.4f\t\t%.2f\n', f_sig(k), A_sig(k), phase_sig(k));
% end

% %% 数据读取与预处理
% filename = 'E:\数模\研究c题\三角波.xlsx';   % 确保路径正确
% data = xlsread(filename);
% B_samples = data(:, 5:end);        % 提取所有磁通密度采样点（第5列开始）
% frequency = data(:, 2);            % 提取频率列（单位：Hz）
% 
% %% 提取第一个样本的磁通密度数据
% sample_idx = 1;                        % 选择第一个样本
% B_signal = B_samples(sample_idx, :);   % 获取该样本的磁通密度序列
% Fs = 1024; % 计算采样频率 = 基频 × 每周期采样点数
% N = length(B_signal);                   % 采样点数
% t = (0:N-1)/Fs;                        % 时间轴（单位：秒）
% 
% %% 快速傅里叶变换（FFT）
% Y = fft(B_signal);                     % 应用FFT
% A = 2 * abs(Y(1:N/2)) / N;             % 单边幅度谱（取前N/2点）
% phase = angle(Y(1:N/2));               % 相位（弧度）
% frequencies = Fs*(0:N/2-1)/N;          % 频率轴（单位：Hz）
% 
% %% 重建信号（使用所有频率分量）
% B_reconstructed = zeros(1, N);
% for k = 1:length(A)
%     B_reconstructed = B_reconstructed + A(k) * sin(2*pi*frequencies(k)*t + phase(k));
% end
% 
% %% 可视化所有正弦波分量及其叠加效果
% figure;
% 
% % 绘制原始信号
% subplot(3,1,1);
% plot(t, B_signal, 'b', 'LineWidth', 1.5);
% title('原始三角波信号');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% % 绘制所有正弦波分量（透明度设为0.3以区分重叠部分）
% subplot(3,1,2);
% hold on;
% for k = 1:length(A)
%     component = A(k) * sin(2*pi*frequencies(k)*t + phase(k));
%     plot(t, component, 'Color', [0.5 0.5 0.5 0.3]); % 灰色半透明线条
% end
% title('所有正弦波分量');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% hold off;
% 
% % 绘制叠加后的重建信号
% subplot(3,1,3);
% plot(t, B_reconstructed, 'r--', 'LineWidth', 1.5);
% title('重建信号（全部正弦波叠加）');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% %% 显示全部分量参数
% disp('=== 全部分解正弦波分量参数 ===');
% fprintf('频率 (Hz)\t 幅度 (T)\t 相位 (rad)\n');
% for k = 1:length(A)
%     fprintf('%.1f\t\t%.4f\t\t%.2f\n', frequencies(k), A(k), phase(k));
% end

% %% 数据读取与预处理
% filename = 'E:\数模\研究c题\梯形波.xlsx';   % 修改为梯形波文件路径
% data = xlsread(filename);
% B_samples = data(2:end, 5:end);        % 提取所有磁通密度采样点（第5列开始）
% frequency = data(2:end, 2);            % 提取频率列（单位：Hz）
% 
% %% 提取第一个样本的磁通密度数据
% sample_idx = 1;                        % 选择第一个样本
% B_signal = B_samples(sample_idx, :);   % 获取该样本的磁通密度序列
% Fs = frequency(sample_idx) * length(B_signal); % 采样频率 = 基频 × 每周期采样点数
% N = length(B_signal);                   % 采样点数
% t = (0:N-1)/Fs;                        % 时间轴（单位：秒）
% 
% %% 快速傅里叶变换（FFT）
% Y = fft(B_signal);                     % 应用FFT
% A = 2 * abs(Y(1:N/2)) / N;             % 单边幅度谱（取前N/2点）
% phase = angle(Y(1:N/2));               % 相位（弧度）
% frequencies = Fs*(0:N/2-1)/N;          % 频率轴（单位：Hz）
% 
% %% 重建信号（使用所有频率分量）
% B_reconstructed = zeros(1, N);
% for k = 1:length(A)
%     B_reconstructed = B_reconstructed + A(k) * sin(2*pi*frequencies(k)*t + phase(k));
% end
% 
% %% 可视化所有正弦波分量及其叠加效果
% figure;
% 
% % 绘制原始信号
% subplot(3,1,1);
% plot(t, B_signal, 'b', 'LineWidth', 1.5);
% title('原始梯形波信号');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% % 绘制所有正弦波分量（透明度设为0.3以区分重叠部分）
% subplot(3,1,2);
% hold on;
% for k = 1:length(A)
%     component = A(k) * sin(2*pi*frequencies(k)*t + phase(k));
%     plot(t, component, 'Color', [0.5 0.5 0.5 0.3]); % 灰色半透明线条
% end
% title('所有正弦波分量');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% hold off;
% 
% % 绘制叠加后的重建信号
% subplot(3,1,3);
% plot(t, B_reconstructed, 'r--', 'LineWidth', 1.5);
% title('重建信号（全部正弦波叠加）');
% xlabel('时间 (s)');
% ylabel('磁通密度 (T)');
% grid on;
% 
% %% 显示全部分量参数
% disp('=== 全部分解正弦波分量参数 ===');
% fprintf('频率 (Hz)\t 幅度 (T)\t 相位 (rad)\n');
% for k = 1:length(A)
%     fprintf('%.1f\t\t%.4f\t\t%.2f\n', frequencies(k), A(k), phase(k));
% end

% filename = 'E:\数模\研究c题\梯形波.xlsx';   % 梯形波数据文件
% data = xlsread(filename);
% B_samples = data(2:end, 5:end);        % 第5列开始为磁通密度采样点
% frequency = data(2:end, 2);            % 频率列（单位：Hz）
% 
% %% 提取第一个梯形波样本
% sample_idx = 1;                        % 选择第一个样本
% B_signal = B_samples(sample_idx, :);   % 获取磁通密度序列
% Fs = 1024;                              % 直接指定采样频率（示例值，需根据实际数据调整）
% N = length(B_signal);                   % 采样点数
% t = (0:N-1)/Fs;                        % 时间轴（单位：秒）
% 
% %% 快速傅里叶变换（FFT）与预处理
% Y = fft(B_signal);                     % 应用FFT
% A = 2 * abs(Y(1:N/2)) / N;             % 单边幅度谱
% phase = angle(Y(1:N/2));               % 相位（弧度）
% frequencies = Fs*(0:N/2-1)/N;          % 频率轴（单位：Hz）
% 
% %% 筛选主要低频分量（调整阈值和频率范围）
% threshold = max(A) * 0.01;             % 提高阈值至1%
% significant_indices = find(A > threshold & frequencies < 2000); % 限制在2kHz以下
% A_sig = A(significant_indices);
% f_sig = frequencies(significant_indices);
% phase_sig = phase(significant_indices);
% 
% %% 重建信号（严格相位对齐）
% B_reconstructed = zeros(1, N);
% for k = 1:length(A_sig)
%     B_reconstructed = B_reconstructed + ...
%         A_sig(k) * cos(2*pi*f_sig(k)*t + phase_sig(k)); % 改用cos函数相位对齐
% end
% 
% %% 可视化对比（增强显示效果）
% figure;
% subplot(2,1,1);
% plot(t, B_signal, 'b', 'LineWidth', 1.5);
% title('原始梯形波信号', 'FontSize', 12);
% xlabel('时间 (s)', 'FontSize', 10);
% ylabel('磁通密度 (T)', 'FontSize', 10);
% xlim([0 0.1]); % 显示前100ms
% grid on;
% 
% subplot(2,1,2);
% plot(t, B_reconstructed, 'r--', 'LineWidth', 1.5);
% title('重建信号（低频正弦波叠加）', 'FontSize', 12);
% xlabel('时间 (s)', 'FontSize', 10);
% ylabel('磁通密度 (T)', 'FontSize', 10);
% xlim([0 0.1]);
% grid on;
% 
% %% 显示谐波参数（格式化输出）
% fprintf('\n=== 梯形波主要谐波分量 ===\n');
% fprintf('%-10s\t%-10s\t%-10s\n', '频率(Hz)', '幅值(T)', '相位(rad)');
% for k = 1:length(A_sig)
%     fprintf('%-10.1f\t%-10.4f\t%-10.2f\n',...
%         f_sig(k), A_sig(k), phase_sig(k));
% end


%% 初始化与数据读取
filename = 'E:\数模\研究c题\梯形波.xlsx';%'E:\数模\研究c题\三角波.xlsx';
data = xlsread(filename);
B_samples = data(2:end, 5:end);    % 磁通密度采样点（每行1024点）
frequency = data(2:end, 2);        % 频率列（单位：Hz）

%% 提取样本并动态计算采样频率
sample_idx = 10;                    % 选择第一个样本
B_signal = B_samples(sample_idx, :);
N = length(B_signal);              % 采样点数
T = 1 / frequency(sample_idx);     % 信号周期（秒）
Fs = N / T;                        % 动态计算采样频率
t = (0:N-1)/Fs;                    % 时间轴（单位：秒）

%% 快速傅里叶变换（FFT）与频谱分析
Y = fft(B_signal);                 
A = 2 * abs(Y(1:N/2)) / N;         % 单边幅度谱（单位：特斯拉）
phase = angle(Y(1:N/2));           % 相位（弧度）
frequencies = Fs*(0:N/2-1)/N;      % 频率轴（单位：Hz）

%% 筛选主要谐波分量（动态阈值与频率范围）
threshold = max(A) * 0.01;         % 保留幅值大于1%最大幅值的分量
max_harmonic = 10;                 % 限制最高谐波次数（根据需求调整）
significant_indices = find(A > threshold & frequencies < max_harmonic*frequency(sample_idx));
A_sig = A(significant_indices);
f_sig = frequencies(significant_indices);
phase_sig = phase(significant_indices);

%% 重建信号并绘制所有正弦分量
figure;
subplot(3,1,1);
plot(t, B_signal, 'b', 'LineWidth', 1.5);
title('原始三角波信号', 'FontSize', 12);
xlabel('时间 (s)'); ylabel('磁通密度 (T)');
xlim([0 T]); grid on;

subplot(3,1,2);
hold on;
B_reconstructed = zeros(1, N);
for k = 1:length(A_sig)
    % 生成单个正弦分量
    component = A_sig(k) * cos(2*pi*f_sig(k)*t + phase_sig(k));
    plot(t, component, '--', 'LineWidth', 0.8);
    B_reconstructed = B_reconstructed + component;
end
title('分解出的正弦分量', 'FontSize', 12);
xlabel('时间 (s)'); ylabel('磁通密度 (T)');
xlim([0 T]); grid on;
hold off;

subplot(3,1,3);
plot(t, B_reconstructed, 'r', 'LineWidth', 1.5);
title('叠加重建信号', 'FontSize', 12);
xlabel('时间 (s)'); ylabel('磁通密度 (T)');
xlim([0 T]); grid on;

%% 输出谐波参数（按幅值降序排列）
[~, sorted_indices] = sort(A_sig, 'descend');
fprintf('\n=== 主要谐波分量（按幅值排序） ===\n');
fprintf('%-12s\t%-12s\t%-12s\t%-12s\n', '频率(Hz)', '幅值(T)', '相位(rad)', '谐波次数');
for k = 1:length(sorted_indices)
    idx = sorted_indices(k);
    harmonic_order = round(f_sig(idx) / frequency(sample_idx));
    fprintf('%-12.1f\t%-12.4f\t%-12.2f\t%-12d\n',...
        f_sig(idx), A_sig(idx), phase_sig(idx), harmonic_order);
end