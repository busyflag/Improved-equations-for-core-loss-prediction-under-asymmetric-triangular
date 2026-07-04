# Improved Equations for Core Loss Prediction Under Asymmetric Triangular Excitation Waveforms

## 项目概述

本项目基于发表在 *Journal of Magnetism and Magnetic Materials* 的学术论文，实现了**DT-IGSE（Dual-Temperature Improved Generalized Steinmetz Equation）** 模型，用于精确预测非对称三角波激励下的磁芯损耗。

**论文信息：**
- 标题：Improved equations for core loss prediction under asymmetric triangular excitation waveforms based on improved generalized Steinmetz equation
- 作者：Yue Wang, Xiaodong Liu, Jingwei Li
- 单位：扬州大学电气与能源工程学院

---

## 研究背景

### 问题挑战

电力电子设备中的磁芯元件经常承受**非正弦激励**，传统的 Steinmetz 方程（SE）在预测此类激励下的磁芯损耗时存在显著局限性。尤其在**非对称三角波激励**条件下，预测精度下降明显。

### 现有模型局限

| 模型 | 局限性 |
|------|--------|
| SE方程 | 仅在正弦激励下精度较高 |
| MSE方程 | 等效频率被高估，损耗被低估；无法描述磁化轨迹形状特征 |
| IGSE方程 | 存在占空比、温度和材料属性的预测偏差 |

---

## 核心方法：DT-IGSE模型

### 1. 波形合成假设分析

非对称三角波可分解为两个对称三角波能量的叠加：

$$f_A = \frac{1}{2D \cdot T} = \frac{f}{2D}$$

$$f_B = \frac{1}{2(1-D) \cdot T} = \frac{f}{2(1-D)}$$

### 2. 占空比-温度联合修正

基于IGSE方程，引入温度因子TEMP进行联合修正：

$$P_{DT-IGSE} = \frac{k}{D^\gamma \cdot T} \int_0^T \left| \frac{dB}{dt} \right|^\alpha \Delta B^{\beta-\alpha} dt + TEMP$$

其中：
- $D$：占空比（上升时间/总周期）
- $\gamma$：占空比修正系数
- $TEMP = a \cdot T^{-1} + b \cdot T + c$：温度修正项

### 3. 参数拟合

采用多参数优化算法（fminsearch）最小化预测值与实际值的均方根误差：

$$\varepsilon_{min} = \sqrt{\frac{\sum_{i=0}^{1024}(pred(i) - actual(i))^2}{1024}}$$

---

## 文件说明

### 主程序

| 文件 | 功能描述 |
|------|----------|
| `model_match.m` | 主程序：参数拟合、模型对比、可视化分析 |

### 辅助分析脚本

| 文件 | 功能描述 |
|------|----------|
| `analysis_test/IGSELUNWEN.m` | IGSE模型原始文献分析 |
| `analysis_test/moxin3.m` | 模型对比分析 |
| `analysis_test/diejia.m` | 叠加效应分析 |
| `analysis_test/sanjiaobo.m` | 三角波特性分析 |
| `analysis_test/SE_youhua.m` | SE方程优化 |
| `analysis_test/flybh.m` | 飞轮波形分析 |
| `analysis_test/fenlei33qq.m` | 分类统计分析 |
| `analysis_test/duoyuanbijiao.m` | 多元对比分析 |
| `analysis_test/alpha.m` | α参数分析 |
| `analysis_test/beta3ci.m` | β参数分析 |
| `analysis_test/cizhihuixian.m` | 磁滞回线分析 |

### 数据文件

| 文件 | 说明 |
|------|------|
| `Material*.xlsx` | 四种磁性材料的实验数据 |

---

## 运行指南

### 环境要求

- **MATLAB R2016b 或更高版本**
- 数据文件：`Material4.xlsx`（或其他材料数据）

### 数据格式

Excel文件应包含以下列结构：

| 列号 | 内容 | 说明 |
|------|------|------|
| 1 | 温度 (°C) | 环境温度 |
| 2 | 频率 (Hz) | 激励频率 |
| 3 | 实际损耗 (W/m³) | 实验测量值 |
| 4 | 波形类型 | 1-SIN, 2-TRI, 3-梯形波 |
| 5~1028 | B(t) | 1024个采样点的磁通密度波形 |

### 运行步骤

1. 确保 `model_match.m` 同目录下存在 `Material4.xlsx` 数据文件
2. 在MATLAB中打开 `model_match.m`
3. 直接运行（F5或点击运行按钮）

### 输出结果

程序将生成以下图表：

1. **模型预测对比图**：IGSE、MSE、DT-IGSE三种模型的预测值vs实际值散点图
2. **误差分布对比图**：三种模型的相对误差分布直方图
3. **占空比-误差分析图**：
   - 不同占空比组的MAPE对比
   - 各组样本数量分布
   - 误差箱线图
4. **温度-误差分析图**：
   - 不同温度组的MAPE对比
   - 各温度组样本分布
   - 温度误差箱线图
5. **三维关系曲面**：
   - 损耗-占空比-温度三维关系
   - 等高线投影图
6. **模型预测误差对比**：各模型的误差分布等高线图

---

## 模型对比结果

### DT-IGSE 模型优势

- ✅ **占空比修正**：解决了极端占空比下的预测偏差
- ✅ **温度补偿**：抵消了温度对材料特性的影响
- ✅ **材料通用性**：在四种不同材料上均表现稳健

### 拟合参数示例（Material 4）

| 参数 | 数值 |
|------|------|
| α | 1.8507 |
| β | 2.4826 |
| γ | 0.163 |
| k | 5.198e-4 |
| a | 0.8719 |
| b | -0.4270 |

---

## 核心代码逻辑

```
数据读取 → 预处理(dB/dt, ΔB, f_eq, D_ratio) → 参数优化
                                                    ↓
模型对比 ← 误差计算 ← 预测值计算 ← 各模型公式
                            ↓
                     可视化输出
```

---

## 引用格式

如果本研究对你的工作有帮助，请引用：

```bibtex
@article{Wang2026Improved,
  title={Improved equations for core loss prediction under asymmetric triangular excitation waveforms based on improved generalized Steinmetz equation},
  author={Wang, Yue and Liu, Xiaodong and Li, Jingwei},
  journal={Journal of Magnetism and Magnetic Materials},
  year={2026},
  doi={https://doi.org/10.1016/j.jmmm.2026.174052}
}
```

---

---

## 联系方式

- 通讯作者：Yue Wang
- 邮箱：2427817067@qq.com
- 单位：扬州大学电气与能源工程学院
