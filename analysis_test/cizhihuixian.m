clc; clear; close all;

%% 仿真参数设置
f = 1000;           % 频率 (Hz)
T = 1/f;            % 周期 (s)
t_step = 1e-6;      % 时间步长 (s)
t = 0:t_step:4*T;   % 时间向量 (4个周期)
B_max = 0.5;        % 峰值磁感应强度 (T)

%% 选择励磁波形类型
wave_type = 'triangular';  % 可选: 'sine', 'rectangular', 'triangular'
D = 0.5;                    % 占空比 (仅对矩形波有效)

% 生成励磁磁场H(t)的波形
switch wave_type
    case 'sine'
        H = sin(2*pi*f*t);                % 正弦波
        label = 'Sinusoidal Wave';
    case 'rectangular'
        H = B_max * square(2*pi*f*t, D*100);  % 矩形波 (占空比D)
        label = ['Rectangular Wave (D = ', num2str(D), ')'];
    case 'triangular'
        H = B_max * sawtooth(2*pi*f*t, 0.5);  % 三角波 (对称)
        label = 'Triangular Wave';
end

%% Jiles-Atherton模型参数 (简化版本)
Ms = 1.6e6;         % 饱和磁化强度 (A/m)
a = 50;             % 形状参数 (A/m)
k = 100;            % 磁滞损耗系数 (A/m)
c = 0.5;            % 可逆磁化系数
alpha = 1e-4;       % 耦合系数

%% 初始化磁化强度M和磁场H的关系
M = zeros(size(H));
Man = zeros(size(H));

% 数值求解J-A模型
for i = 2:length(H)
    dH = H(i) - H(i-1);
    if abs(dH) < 1e-10
        dH = 1e-10;  % 避免除以零
    end
    
    % 计算无磁滞磁化强度Man（Langevin函数近似）
    Man(i) = Ms * (coth(H(i)/a) - a/H(i));
    
    % 磁化率微分方程（简化J-A模型）
    delta = sign(dH);
    dM_dH = (Man(i) - M(i-1)) / (k * delta - alpha * (Man(i) - M(i-1)));
    M(i) = M(i-1) + dM_dH * dH;
end

% 计算磁感应强度B
mu0 = 4*pi*1e-7;    % 真空磁导率
B = mu0 * (H + M);  % B = μ0*(H + M)

%% 绘制磁滞回线
figure;
plot(H, B, 'LineWidth', 1.5);
xlabel('磁场 H (A/m)');
ylabel('磁感应强度 B (T)');
title(['磁滞回线 - ', label]);
grid on;

% 标记饱和区域
hold on;
plot(H(1), B(1), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
text(H(1), B(1), '  Start', 'FontSize', 10);

% 绘制励磁波形（辅助理解）
figure;
subplot(2,1,1);
plot(t, H, 'b', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('磁场 H (A/m)');
title(['励磁波形: ', label]);
grid on;
xlim([0 4*T]);

subplot(2,1,2);
plot(t, B, 'r', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('磁感应强度 B (T)');
title('磁感应强度响应');
grid on;
xlim([0 4*T]);
