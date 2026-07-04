clc;
clear;

%% 数据读取与预处理
data = readtable('附件一（训练集）.xlsx', 'PreserveVariableNames', true);


% 提取数据列
temperature = data(2:end, 1);        % 第1列：温度（°C）
frequency = data(2:end, 2);          % 第2列：频率（Hz）
core_loss = data(2:end, 3);          % 第3列：磁芯损耗（W/m³）
waveform_type = categorical(data{2:end, 4});     % 第4列：励磁波形类型（1-正弦波，2-三角波，3-梯形波）
B_samples = data(2:end, 5:end);      % 第5-1028列：磁通密度采样点（T）

for i=1:3400
if(strcmp(waveform_type(i),'正弦波') )
    lable(i)=1;
 else if(strcmp(waveform_type(i),'三角波'))
        lable(i)=2;
  else if(strcmp(waveform_type(i),'梯形波'))
         lable(i)=3;
end
end
end
end

% 设置容差阈值
temp_tol = 1;    % 温度容差±1°C
freq_tol = 1;    % 频率容差±1Hz

%% 生成工况标签（考虑容差）
% 将温度和频率规整到容差间隔
temp_bins = round(temperature / temp_tol) * temp_tol;
freq_bins = round(frequency / freq_tol) * freq_tol;

% 创建唯一工况组合标签
[unique_conditions, ~, group_id] = unique([temp_bins, freq_bins], 'rows');

%% 筛选具有多波形的工况组
valid_groups = [];
for i = 1:size(unique_conditions, 1)
    idx = (group_id == i); % 当前组的索引
    waveforms_in_group = waveform_type(idx);
    
    % 检查组内是否包含至少两种不同波形
    if length(unique(waveforms_in_group)) >= 2
        valid_groups = [valid_groups; i];
    end
end

%% 提取目标数据并展示
fprintf('找到%d组满足条件的工况:\n', length(valid_groups));
for k = 1:length(valid_groups)
    group = valid_groups(k);
    idx = (group_id == group);
    
    % 提取组内数据
    group_temp = unique_conditions(group, 1);
    group_freq = unique_conditions(group, 2);
    group_waveforms = waveform_type(idx);
    group_loss = core_loss(idx);
    
    % 输出结果
    fprintf('\n工况%d: 温度=%.1f°C, 频率=%.1fHz\n', k, group_temp, group_freq);
    fprintf('波形类型 | 磁芯损耗 (W/m³)\n');
    fprintf('----------------------------\n');
    for m = 1:length(group_waveforms)
        fprintf('   %d     | %.2f\n', group_waveforms(m), group_loss(m));
    end
end

%% 可视化对比（以第一组为例）
if ~isempty(valid_groups)
    group = valid_groups(1);
    idx = (group_id == group);
    
    % 提取数据
    group_loss = core_loss(idx);
    group_waveforms = waveform_type(idx);
    
    figure;
    bar(group_waveforms, group_loss);
    xlabel('波形类型');
    ylabel('磁芯损耗 (W/m³)');
    title(sprintf('温度=%.1f°C, 频率=%.1fHz下的损耗对比',...
         unique_conditions(group,1), unique_conditions(group,2)));
    set(gca, 'XTick', [1 2 3], 'XTickLabel', {'正弦波', '三角波', '梯形波'});
    grid on;
end