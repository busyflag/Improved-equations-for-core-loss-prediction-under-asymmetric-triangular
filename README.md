# Improved Equations for Core Loss Prediction Under Asymmetric Triangular Excitation Waveforms

## Based on Improved Generalized Steinmetz Equation (DT-IGSE)

---

## 📄 Publication Information

| Item | Details |
|------|---------|
| **Title** | Improved equations for core loss prediction under asymmetric triangular excitation waveforms based on improved generalized Steinmetz equation |
| **Authors** | Yue Wang, Xiaodong Liu*, Jingwei Li |
| **Affiliation** | College of Electrical, Energy and Power Engineering, Yangzhou University, 225000 Yangzhou, China |
| **Journal** | Journal of Magnetism and Magnetic Materials |
| **DOI** | [10.1016/j.jmmm.2026.174052](https://doi.org/10.1016/j.jmmm.2026.174052) |
| **Received** | 23 October 2025 |
| **Revised** | 20 March 2026 |
| **Accepted** | 22 March 2026 |

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Theoretical Background](#2-theoretical-background)
3. [DT-IGSE Model Derivation](#3-dt-igse-model-derivation)
4. [Experimental Setup](#4-experimental-setup)
5. [Materials and Data](#5-materials-and-data)
6. [Code Structure](#6-code-structure)
7. [Running the Code](#7-running-the-code)
8. [Results and Discussion](#8-results-and-discussion)
9. [Fitting Parameters](#9-fitting-parameters)
10. [References](#11-references)

---

## 1. Overview

### 1.1 Research Motivation

Magnetic components in power electronic devices are frequently subjected to **non-sinusoidal excitation**. The conventional Steinmetz Equation (SE) exhibits significant limitations in predicting core losses under non-sinusoidal excitation conditions. Additionally, other empirical models suffer from low prediction accuracy due to:

- **Asymmetry of excitation waveforms**
- **Influence of extreme temperatures**
- **Material property variations**

This issue is particularly pronounced under **asymmetric triangular excitation waveforms**, which are common in high-frequency power switch designs.

### 1.2 Contribution Summary

This study proposes the **DT-IGSE (Duty cycle and Temperature Improved Generalized Steinmetz Equation)** model, which:

1. **Compares** mainstream empirical models (SE, MSE, IGSE) under asymmetric triangular excitation
2. **Reveals** that IGSE performs best but is constrained by three key factors: duty cycle, temperature, and material properties
3. **Introduces** a novel joint correction method combining duty cycle and temperature factors
4. **Validates** across four typical core materials with significantly reduced prediction errors

---

## 2. Theoretical Background

### 2.1 Steinmetz Equation (SE)

The classic Steinmetz Equation is one of the most well-known empirical equations for core loss prediction:

$$P_{SE} = k \cdot f^{\alpha} \cdot B_m^{\beta}$$

Where:
- $k$, $\alpha$, $\beta$ are coefficients fitted based on experimental data
- $f$ is the frequency
- $B_m$ is the peak magnetic flux density

**Limitation**: This equation only yields relatively low prediction errors under **sinusoidal excitation waveforms**.

### 2.2 Modified Steinmetz Equation (MSE)

The MSE equation was proposed to calculate core losses under **arbitrary waveforms** without requiring additional parameters beyond the original SE equation.

#### Equivalent Frequency Calculation

MSE assumes that core losses are related to the rate of change of magnetic flux density. The equivalent frequency is calculated as:

$$f_{eq} = \frac{2}{\Delta B^2 \pi^2} \int_0^T \left( \frac{dB}{dt} \right)^2 dt$$

Substituting into the SE equation:

$$P_{MSE} = \left( k \cdot f_{eq}^{\alpha-1} \cdot B_m^{\beta} \right) \cdot f$$

#### Limitations of MSE

1. **Overestimation of equivalent frequency**: When the magnetic flux density waveform results from superposition of two distinct sinusoidal waves with parameter $c \to 1$, the equivalent frequency is significantly overestimated while power loss is underestimated.

2. **Ambiguous frequency selection**: The MSE equation does not specify which frequency should be chosen as the fundamental wave.

3. **Ignores magnetization rates**: Since core loss per cycle is intrinsically related to the area of the hysteresis loop, MSE fails to account for the influence of magnetization rates within a cycle. By performing only static power fitting, it cannot resolve the entire dynamic magnetization process.

### 2.3 Improved Generalized Steinmetz Equation (IGSE)

To overcome the insufficient prediction accuracy of SE and MSE, the IGSE equation was proposed. This equation:

- Accounts for the influence of magnetization history
- Employs the peak difference as the product term in the integral
- Prevents magnetic loss during domain switching from being canceled out

The IGSE equation is expressed as:

$$P_{IGSE} = \frac{k_i}{T} \int_0^T \left| \frac{dB}{dt} \right|^{\alpha} \Delta B^{\beta-\alpha} dt$$

Where $k_i$ is calculated as:

$$k_i = \frac{k}{(2\pi)^{\alpha-1}} \int_0^{2\pi} |\cos\theta|^{\alpha} 2^{\beta-\alpha} d\theta$$

#### Limitations of IGSE

Despite its improvements, IGSE still exhibits:
1. **Duty cycle dependency**: Prediction accuracy shows deviations at different duty cycles
2. **Temperature effects**: Absence of a temperature term leads to significant errors under temperature-dependent conditions

---

## 3. DT-IGSE Model Derivation

### 3.1 Waveform Composite Hypothesis

When using the original IGSE model to predict core losses with duty cycle as the independent variable, it was found that the model consistently performed best at a **0.5 duty cycle** but exhibited significant deviations at **extreme duty cycles**.

#### Decomposition Process

An asymmetric triangular excitation waveform can be decomposed into the superposition of two symmetric triangular wave energies.

As shown in **Figure 1**, the rising edge (denoted as A) and falling edge (denoted as B) of an asymmetric triangular wave can be reflected about the axis of symmetry to obtain two excitation waveforms with different frequencies.

**Key insight**: The magnetic loss of an asymmetric triangular excitation waveform at frequency $f$ can be decomposed into the superposition of two symmetric triangular excitation waveforms at different frequencies.

#### Frequency Calculation

For a waveform with period $T$ and frequency $f$, where the rising edge occupies proportion $D$ of the entire cycle:

$$\text{Rising edge frequency: } f_A = \frac{1}{2D \cdot T} = \frac{f}{2D}$$

$$\text{Falling edge frequency: } f_B = \frac{1}{2(1-D) \cdot T} = \frac{f}{2(1-D)}$$

### 3.2 Mathematical Derivation

#### Step 1: Original IGSE Equation

$$P_{IGSE} = \frac{k_i}{T} \int_0^T \left| \frac{dB}{dt} \right|^{\alpha} \Delta B^{\beta-\alpha} dt$$

#### Step 2: Core Loss Decomposition

For core losses under fundamental frequency asymmetric excitation waveform:

$$P = P_A + P_B$$

Where $P_A$ and $P_B$ are the losses corresponding to the rising and falling segments respectively:

$$P_A = f_A \int_0^{1/(2f_A)} P_{IGSEa}(t) dt$$

$$P_B = f_B \int_{1/(2f_B)}^{1/f_B} P_{IGSEb}(t) dt$$

#### Step 3: Triangular Waveform Integral

For triangular excitation waveforms, the calculated result of $P_{IGSEa}(t)$ in the first half-cycle is identical to that in the second half-cycle. The core integral term yields:

$$\int_0^{T/2} \left| \frac{dB}{dt} \right|^{\alpha} dt = T \left( \frac{\Delta B}{T} \right)^{\alpha} = \int_{T/2}^{T} \left| \frac{dB}{dt} \right|^{\alpha} dt$$

#### Step 4: Incorporating Error Effects

Considering that error effects and material coefficient influences may arise when energies of different frequency waves superimpose, an exponential factor should be present in the product term preceding integration:

$$P_A = \left( \frac{1}{2D} \right)^{\gamma} \frac{1}{T} \int_0^{DT} P_{IGSEa}(t) dt$$

$$P_B = \left( \frac{1}{2(1-D)} \right)^{\gamma} \frac{1}{T} \int_0^{(1-D)T} P_{IGSEb}(t) dt$$

#### Step 5: Duty Cycle Correction

When operating at extreme duty cycles, one of the preceding product terms is approximated as zero to simplify calculations. The final magnetic loss calculation formula becomes:

$$P = \frac{k}{D^{\gamma} \cdot T} \int_0^T \left| \frac{dB}{dt} \right|^{\alpha} \Delta B^{\beta-\alpha} dt$$

Based on the symmetry relationship of core losses:
- When $D < 0.5$: $D' = D$
- When $D > 0.5$: $D' = (1-D)$

### 3.3 Temperature Factor Analysis

Temperature variations directly affect the intrinsic properties of magnetic materials:
- Magnetic permeability
- Magnetic flux density saturation characteristics

These factors influence the **B-H curve** and introduce errors in magnetic loss prediction. Furthermore, temperature and duty cycle may exhibit certain **coupling relationships**.

As shown in **Figure 2**, core losses exhibit:
- An **approximate exponential relationship** with duty cycle variation
- A **hyperbolic variation pattern** with temperature at the same duty cycle

### 3.4 Final DT-IGSE Equation

The temperature factor $TEMP$ is incorporated into the duty cycle correction equation:

$$TEMP = a \cdot T^{-1} + b \cdot T + c$$

Where $a$, $b$, $c$ are parameters to be fitted, and $T$ is the ambient temperature in °C.

**Final joint correction equation (DT-IGSE)**:

$$\boxed{P_{DT-IGSE} = \frac{k}{D^{\gamma} \cdot T} \int_0^T \left| \frac{dB}{dt} \right|^{\alpha} \Delta B^{\beta-\alpha} dt + \left( a \cdot T^{-1} + b \cdot T + c \right)}$$

---

## 4. Experimental Setup

### 4.1 Measurement Method

Core losses are measured using the **AC power method** with the **double-winding method**, as illustrated in **Figure 3**.

### 4.2 Test Core Configuration

The core under test is typically a **toroidal ring** with:
- $l_e$: Average magnetic path length
- $A_e$: Cross-sectional area of the core

### 4.3 Winding Setup

- **Excitation winding** and **induction winding** are uniformly wound on the core
- $N_1$ and $N_2$ represent the number of turns (typically $N_1 = N_2 = N$)

### 4.4 Measurement Principle

According to Ampère's circuit law and electromagnetic induction principle:

The net energy stored in the inductor during one cycle:

$$W = \int_0^T u(t) \cdot i(t) dt$$

Substituting and combining with electromagnetic principles:

$$W = \int_0^T \left( \frac{NA_e}{l_e} \frac{dB(t)}{dt} \right) \left( \frac{H(t)l_e}{N} \right) dt$$

The output power per unit volume (magnetic core loss density):

$$\boxed{P = \frac{1}{T} \int_{B(0)}^{B(T)} H \, dB}$$

**Key insight**: The core loss per unit volume within one excitation cycle equals the **area of the B-H hysteresis loop**.

---

## 5. Materials and Data

### 5.1 Material Specifications

Four typical ferrite core materials were selected for validation experiments:

| Material ID | Manufacturer | Material Grade | Application | Initial Permeability (μᵣ) | Tested Core |
|:-----------:|:------------:|:--------------:|:-----------:|:------------------------:|:-----------:|
| **Material 1** | TDK | N87 | Power transformers | 2200 | R34.0X20.5X12.5 |
| **Material 2** | TDK | N27 | Power transformers | 2000 | R20.0X10.0X7.0 |
| **Material 3** | Fair-Rite | 77 | High/low flux inductive designs | 2000 | 5977001401 |
| **Material 4** | Ferroxcube | 3C94 | Power and general-purpose transformers | 2300 | TX-20-10-7 |

### 5.2 Material Properties Summary

| Property | Material 1 (N87) | Material 2 (N27) | Material 3 (77) | Material 4 (3C94) |
|----------|:---------------:|:---------------:|:---------------:|:---------------:|
| **Type** | MnZn Ferrite | MnZn Ferrite | MnZn Ferrite | MnZn Ferrite |
| **μᵣ (Initial Permeability)** | 2200 | 2000 | 2000 | 2300 |
| **Core Geometry** | Toroid (R34×20.5×12.5) | Toroid (R20×10×7) | Toroid (5977001401) | Toroid (TX-20-10-7) |
| **Primary Application** | Power Transformers | Power Transformers | High/Low Flux Inductive Designs | Power & General-purpose Transformers |

### 5.3 Material Selection Rationale

- **Material 1 (TDK N87)**: High-performance power ferrite with low losses at high frequencies
- **Material 2 (TDK N27)**: Designed for high-frequency power transformer applications
- **Material 3 (Fair-Rite 77)**: Optimized for inductive designs requiring high/low flux operation
- **Material 4 (Ferroxcube 3C94)**: Widely used general-purpose power ferrite material

### 5.4 Experimental Data Specifications

| Parameter | Specification |
|-----------|---------------|
| **Samples per material** | ~1400 sets of triangular excitation waveform data |
| **Sampling points per cycle** | 1024 points at equal intervals |
| **Waveform types** | Sinusoidal, Triangular, Trapezoidal |
| **Temperature range** | 25°C - 100°C (typical) |
| **Frequency range** | Variable (see data files) |

### 5.5 Data File Format

Excel files (`Material1.xlsx`, `Material2.xlsx`, `Material3.xlsx`, `Material4.xlsx`) contain:

| Column | Content | Description |
|--------|---------|-------------|
| 1 | Temperature (°C) | Ambient temperature |
| 2 | Frequency (Hz) | Excitation frequency |
| 3 | Core Loss (W/m³) | Measured/actual loss value |
| 4 | Waveform Type | 1=Sinusoidal, 2=Triangular, 3=Trapezoidal |
| 5~1028 | B(t) values | 1024 sampling points of magnetic flux density (T) |

### 5.6 Material-to-File Mapping

| File | Corresponding Material |
|------|------------------------|
| `Material1.xlsx` | TDK N87 (μᵣ=2200, R34.0X20.5X12.5) |
| `Material2.xlsx` | TDK N27 (μᵣ=2000, R20.0X10.0X7.0) |
| `Material3.xlsx` | Fair-Rite 77 (μᵣ=2000, 5977001401) |
| `Material4.xlsx` | Ferroxcube 3C94 (μᵣ=2300, TX-20-10-7) |

---

## 6. Code Structure

### 6.1 Directory Structure

```
project_root/
├── README.md                          # This file
├── model_match.m                      # Main program (model comparison and fitting)
├── analysis_test/
│   ├── IGSELUNWEN.m                   # IGSE model original paper analysis
│   ├── moxin3.m                       # Model comparison analysis
│   ├── diejia.m                       # Superposition effect analysis
│   ├── sanjiaobo.m                    # Triangular waveform characteristics
│   ├── SE_youhua.m                    # SE equation optimization
│   ├── flybh.m                        # Flyback waveform analysis
│   ├── fenlei33qq.m                   # Classification statistics
│   ├── duoyuanbijiao.m                # Multi-variate comparison
│   ├── alpha.m                        # Alpha parameter analysis
│   ├── beta3ci.m                      # Beta parameter analysis
│   └── cizihuixian.m                 # Hysteresis loop visualization
└── Material*.xlsx                     # Experimental data files
```

### 6.2 Main Program: model_match.m

#### Functionality

The main program performs:

1. **Data Loading**: Reads Material data from Excel files
2. **Preprocessing**: 
   - Extracts triangular waveform data (wave_type = 2)
   - Calculates dB/dt using central difference method
   - Computes ΔB, equivalent frequency f_eq, duty cycle D_ratio
3. **Parameter Optimization**: Fits parameters for IGSE, MSE, and DT-IGSE models using fminsearch
4. **Model Comparison**: Calculates prediction errors for all models
5. **Visualization**: Generates comprehensive plots including:
   - Prediction vs. Actual scatter plots
   - Error distribution histograms
   - Duty cycle error analysis
   - Temperature error analysis
   - 3D loss surfaces
   - Error contour plots

#### Key Code Sections

```matlab
% Data preprocessing with dB/dt calculation
dBdt(j) = (B_wave(j+1) - B_wave(j-1)) / (2*dt);

% Equivalent frequency calculation
f_eq = (2/(delta_B^2 * pi^2)) * trapz(linspace(0,1/freq,length(dBdt)), dBdt.^2);

% Duty cycle calculation
D_ratio = (i_max - 1) / (length(B_wave) - 1);
```

#### Objective Function for Optimization

The optimization minimizes the root mean square error:

$$\varepsilon_{min} = \sqrt{\frac{\sum_{i=0}^{1024}(pred(i) - actual(i))^2}{1024}}$$

---

## 7. Running the Code

### 7.1 Environment Requirements

- **MATLAB R2016b or higher**
- Statistics and Machine Learning Toolbox (for optimization)
- Excel file support (xlsread/xlwrite)

### 7.2 Data File Preparation

1. Ensure `Material4.xlsx` (or other Material*.xlsx) is in the same directory as `model_match.m`
2. Data should follow the format specified in Section 5.3

### 7.3 Execution Steps

1. Open `model_match.m` in MATLAB
2. Modify the `filename` variable if using a different material:
   ```matlab
   filename = 'Material4.xlsx';  % Change as needed
   ```
3. Run the script (F5 or click Run)
4. View output in Command Window and figures

### 7.4 Expected Output

The program generates multiple figures:

| Figure | Description |
|--------|-------------|
| 1 | Model Prediction Comparison (IGSE, MSE, DT-IGSE) |
| 2 | Error Distribution Comparison |
| 3 | Effect of Duty Cycle on Error |
| 4 | Effect of Temperature on Error |
| 5 | 3D Loss Surface (Duty Cycle × Temperature × Loss) |
| 6 | 3D Model Prediction Comparison |

---

## 8. Results and Discussion

### 8.1 Model Comparison Under Duty Cycle Variation

As shown in **Figure 4**, the DT-IGSE model demonstrates:

- **Significantly reduced prediction errors** compared to MSE and IGSE
- **Higher robustness** across different duty cycles
- **Best performance** particularly at extreme duty cycles (D < 0.2 or D > 0.8)

Although the prediction error is slightly higher than other models for certain duty cycles in specific materials, the **overall error is significantly reduced**.

### 8.2 Temperature Dependence Analysis

As shown in **Figure 5**, at different temperatures:

- Materials 2, 3, and 4 exhibit **smaller average errors**
- Material 1 shows anomalies that may stem from experimental data inaccuracies
- The DT-IGSE model maintains consistent performance across the temperature range

### 8.3 Three-Dimensional Error Analysis

As shown in **Figure 6**, the 3D comparison reveals:

- DT-IGSE significantly reduces the **overall prediction error** for magnetic core losses
- The combined correction addresses errors from both duty cycle and temperature variations
- A novel correction approach is demonstrated: when developing correction models based on duty cycle or frequency, **temperature's impact must be simultaneously considered**

### 8.4 Key Findings

1. **Waveform Composite Hypothesis**: Asymmetric triangular waves can be effectively decomposed into symmetric triangular wave energies with different frequencies

2. **Duty Cycle Correction**: The exponential correction factor $D^{-\gamma}$ effectively addresses extreme duty cycle prediction errors

3. **Temperature Compensation**: The additive temperature term $TEMP = a \cdot T^{-1} + b \cdot T + c$ offsets temperature-induced material property variations

4. **Coupling Relationship**: Temperature and certain material coefficients exhibit coupling relationships that can be exploited for further model refinement

---

## 9. Fitting Parameters

### 9.1 DT-IGSE Parameters for Different Materials

| Parameter | Material 1 | Material 2 | Material 3 | Material 4 |
|-----------|------------|------------|------------|------------|
| **α** | 1.8057 | 1.7169 | 1.7497 | 1.8507 |
| **β** | 2.3274 | 2.3172 | 2.4380 | 2.4826 |
| **γ** | 0.0908 | 0.1377 | 0.1180 | 0.1630 |
| **k** | 5.302×10⁻⁴ | 2.038×10⁻³ | 1.710×10⁻³ | 5.198×10⁻⁴ |
| **a** | -0.3071 | -0.6578 | -1.0764 | 0.8719 |
| **b** | -0.1721 | 0.2565 | -2.1233 | -0.4270 |

### 9.2 Parameter Interpretation

| Parameter | Physical Meaning |
|-----------|------------------|
| **α** | Frequency exponent (related to hysteresis loss) |
| **β** | Flux density exponent (related to eddy current loss) |
| **γ** | Duty cycle correction coefficient |
| **k** | Core loss coefficient |
| **a, b** | Temperature correction coefficients |

---


## 10. References(main)

[1] G. Bertotti, "General properties of power losses in soft ferromagnetic materials," IEEE Trans. Magn., vol. 24, no. 1, pp. 621–630, 1988.

[2] C.P. Steinmetz, "On the law of hysteresis," Proc. IEEE, vol. 72, no. 2, pp. 197–221, 1984.

[3] R. Severns, "HF-core losses for nonsinusoidal waveforms," in Proc. HFPC '91, pp. 140–148, 1991.

[4] K. Venkatachalam et al., "Accurate prediction of ferrite core loss with nonsinusoidal waveforms using only Steinmetz parameters," in IEEE Workshop on Computers in Power Electronics, pp. 36–41, 2002.

[5] J. Reinert et al., "Calculation of losses in ferro- and ferrimagnetic materials based on the modified Steinmetz equation," IEEE Trans. Ind. Appl., vol. 37, no. 4, pp. 1055–1061, 2001.

[6] T. Jieli et al., "Improved calculation of core loss with nonsinusoidal waveforms," in Conf. Rec. IEEE IAS Annu. Meet., pp. 2203–2210, 2001.

[7] A. Arruti et al., "The composite improved generalized Steinmetz equation (ciGSE): An accurate model combining the composite waveform hypothesis with classical approaches," IEEE Trans. Power Electron., vol. 39, no. 1, pp. 1162–1173, 2024.

[8] S. Barg et al., "A review on the empirical core loss models for symmetric flux waveforms," IEEE Trans. Power Electron., vol. 40, no. 1, pp. 1609–1621, 2025.

[9] S. Barg et al., "An improved empirical formulation for magnetic core losses estimation under nonsinusoidal induction," IEEE Trans. Power Electron., vol. 32, no. 3, pp. 2146–2154, 2017.

[10] C.R. Sullivan et al., "Core loss predictions for general PWM waveforms from a simplified set of measured data," in APEC, pp. 1048–1055, 2010.

[11] Y. Li et al., "A core loss estimation method based on improved waveform coefficient Steinmetz equation for asymmetric triangular flux density waveform," AIP Adv., vol. 14, p. 015121, 2024.

[12] S. Barg et al., "Core loss modeling and calculation for trapezoidal magnetic flux density waveform," IEEE Trans. Ind. Electron., vol. 68, no. 9, pp. 7975–7984, 2021.

[13] H.Y. Lu et al., "Measurement and modeling of thermal effects on magnetic hysteresis of soft ferrites," IEEE Trans. Magn., vol. 43, no. 11, pp. 3952–3960, 2007.

etc.

---

## 📝 Citation

If this work is useful for your research, please cite:

```bibtex
@article{Wang2026Improved,
  title={Improved equations for core loss prediction under asymmetric triangular excitation waveforms based on improved generalized Steinmetz equation},
  author={Wang, Yue and Liu, Xiaodong and Li, Jingwei},
  journal={Journal of Magnetism and Magnetic Materials},
  year={2026},
  pages={174052},
  doi={10.1016/j.jmmm.2026.174052}
}
```

---

## 📧 Contact

- **fIRST Author**: Yue Wang
- **Email**: 2574414382@qq.com/233302124@stu.yzu.edu.cn
- **Institution**: College of Electrical, Energy and Power Engineering, Yangzhou University
- **Address**: Yangzhou 225000, China

---

*Last updated: July 2026*
