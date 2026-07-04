%% 新型磁芯多目标优化系统
% 目标1：最小化损耗 P = k0*exp(-gamma*(T-T0)) * f^(b0+b1T+b2*sqrt(T)) * B^(c0*exp(c1*T))  
% 目标2：最大化能量传输指标 f*B
clc; clear; close all;
rng(42);

%% 参数配置
params.k0 = 3.3789;    % 损耗模型系数
params.gamma = 0.0497; % 温度衰减系数（原γ改为gamma）
params.b0 = 1.3437;    % 频率指数基值
params.b1 = 0.0063;    % 温度线性项系数
params.b2 = -0.0274;   % 温度根号项系数
params.c0 = 2.1920;    % 磁密指数基准
params.c1 = 0.0022;    % 磁密温度耦合系数
params.T0 = 25;        % 参考温度(℃)

material.Bsat_ref = 0.45;       % 25℃基准饱和磁密(T)
material.T_coef = -0.005;       % Bsat温度系数(T/℃)

%% 优化参数范围
optimParams.T_range = [25 90];  % 温度范围(℃)
optimParams.f_range = [1e3 1e5];% 频率范围(Hz)
optimParams.B_range = [0.1 0.4];% 磁密范围(T)

%% 多目标优化配置
options = optimoptions('gamultiobj',...
    'PopulationSize', 200,...
    'ParetoFraction',0.7,...
    'FunctionTolerance',1e-4,...
    'MaxGenerations', 100,...
    'PlotFcn',@gaplotpareto);

%% 执行优化
nvars = 3; % T, f, B
[x_opt, fval_opt] = gamultiobj(@(x)magnetic_objectives(x,params,material),...
    nvars,... 
    [],[],[],[],... 
    [optimParams.T_range(1), optimParams.f_range(1), optimParams.B_range(1)],... % LB
    [optimParams.T_range(2), optimParams.f_range(2), optimParams.B_range(2)],...   % UB
    @(x)magnetic_constraints(x,material), options);

%% 结果显示
figure('Name','帕累托前沿')
scatter(fval_opt(:,1), -fval_opt(:,2), 40,'filled','MarkerFaceAlpha',0.6)
xlabel('磁芯损耗 P_{core} (W/m^3)')
ylabel('能量密度 fB (Hz*T)')
title('新型模型优化帕累托前沿')
grid on; axis tight;

% 最优折中解选取
ref_point = [min(fval_opt(:,1)), max(-fval_opt(:,2))];
norm_fval = [fval_opt(:,1)-ref_point(1), -fval_opt(:,2)-ref_point(2)];
[~, idx] = min(sqrt(sum(norm_fval.^2,2)));
hold on; 
plot(fval_opt(idx,1), -fval_opt(idx,2), 'ro','MarkerSize',10);

%% 最优参数输出
optimal_params = struct(...
    'T', x_opt(idx,1),...
    'f', x_opt(idx,2)./1e3,...
    'B', x_opt(idx,3));
disp('===== 最优折中解参数 =====');
disp(['温度: ', num2str(optimal_params.T), ' ℃']);
disp(['频率: ', num2str(optimal_params.f), ' kHz']);
disp(['磁密: ', num2str(optimal_params.B), ' T']);

%% ------------------ 目标函数 ------------------ 
function obj = magnetic_objectives(x,params,material)
T = x(1);    % 温度(℃)
f = x(2);    % 频率(Hz)
B = x(3);    % 磁密(T)

% 动态饱和磁密计算
T0_ref = params.T0;
Bsat = material.Bsat_ref + material.T_coef*(T - T0_ref);

% 磁芯损耗计算
exponent_f = params.b0 + params.b1*T + params.b2*sqrt(T);
exponent_B = params.c0 * exp(params.c1*T);
P_core = params.k0 * exp(-params.gamma*(T-T0_ref)) * (f.^exponent_f) .* (B.^exponent_B);

% 能量传输指标
energy_metric = f .* B;

obj = [P_core, -energy_metric]; 
end

%% ------------------ 约束函数 ------------------
function [c, ceq] = magnetic_constraints(x,material)
T = x(1);
B = x(3);

% 动态饱和磁密计算
T0_ref = 25;  % 参考温度与参数定义一致
Bsat = material.Bsat_ref + material.T_coef*(T - T0_ref);

% 安全系数约束
safety_margin = 0.95;
c = B - Bsat*safety_margin;   % 磁密约束为不等式约束
ceq = [];
end
