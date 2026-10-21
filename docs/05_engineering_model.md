# Stage 4: Engineering Mathematical Model

**Status:** Draft v0.3. It has 61 numbered equations in 12 groups, counting equations 11a, 34a, 41a and 41b.

This model gives the diagnostic rules their engineering justification. Every threshold test in the knowledge base compares a measured or derived quantity from this document against a reference value. The math is written in LaTeX syntax, so it renders in the VS Code Markdown preview and can be copied straight into the report.

Each equation has a **status**:

- **Implemented** means it already exists as a Prolog predicate.
- **Planned** means it is needed for a fault or test that is not built yet.
- **[verify]** means the form or constant must be checked against a source before it goes into the report.

All symbols are defined where they first appear and again in the nomenclature in section 4.14.

---

## 4.1 Sets and indices

- $\mathcal{R} = \{r_1, \dots, r_6\}$ is the set of racks A01 to A06, with $n_R = \lvert \mathcal{R} \rvert = 6$.
- $\mathcal{S}_r$ is the set of servers in rack $r$, with $\lvert \mathcal{S}_r \rvert = 20$.
- $\mathcal{B}$ is the set of rack PDU branch circuits.
- $k$ is a sample index, and $t_k$ is its timestamp.
- $\mathcal{F} = \{F_1, \dots, F_8, S_1, S_2, F_N\}$ is the fault universe from Stage 2.
- $\mathcal{H} = \mathcal{F} \setminus \{F_N\}$ is the set of fault hypotheses.

---

## 4.2 IT power model

**Server power.** Server electrical power is close to linear in CPU utilisation (Fan et al., 2007).

$$P_s = P_{idle} + (P_{max} - P_{idle})\, u_s \tag{1}$$

Here $P_s$ is the power of server $s$ in kW, $u_s \in [0,1]$ is its CPU utilisation, and $P_{idle}$ and $P_{max}$ are its idle and full-load power. The design values are $P_{idle} = 0.40$ kW and $P_{max} = 0.90$ kW *[assumption]*.

**Rack and row power.**

$$P_r = \sum_{s \in \mathcal{S}_r} P_s \tag{2}$$

$$P_{IT} = \sum_{r \in \mathcal{R}} P_r \tag{3}$$

With 20 servers per rack and six racks, utilisations of 10%, 50% and 90% give row loads of 54, 78 and 102 kW.

**Power model residual.** This compares the metered rack power $P_r^{meas}$ with the model. A large residual points to a metering fault or an unmodelled load.

$$\varepsilon_{P,r} = \frac{P_r^{meas} - P_r}{P_r} \tag{4}$$

*Status: planned. Supports S1-type checks on power metering and the energy balance in section 4.7.*

---

## 4.3 Server and rack thermal model

**Air mass flow from volume flow.**

$$\dot m = \rho_a \dot V \tag{5}$$

$\dot m$ is mass flow in kg/s, $\rho_a$ is air density in kg/m³, and $\dot V$ is volume flow in m³/s.

**Sensible heat pickup across a server.** This is the sensible-heat equation applied to one server with airflow $\dot m_s$.

$$\Delta T_s = \frac{P_s}{\dot m_s\, c_{p,a}} \tag{6}$$

$c_{p,a}$ is the specific heat of air in kJ/(kg·K). At $P_s = 0.65$ kW and $\dot m_s = 0.05$ kg/s, the rise is about 12.9 K.

**Rack outlet temperature.**

$$T_{out,r} = T_{in,r} + \frac{P_r}{\dot m_r\, c_{p,a}} \tag{7}$$

$\dot m_r = \sum_{s \in \mathcal{S}_r} \dot m_s$ is the total airflow through rack $r$.

**CPU temperature.** This is a lumped thermal-resistance model. The resistance falls as the server fan speeds up.

$$T_{cpu,s} = T_{in,r} + R_{th}(\omega_s)\, P_{cpu,s} \tag{8}$$

$R_{th}$ is the junction-to-inlet thermal resistance in K/kW, $\omega_s$ is the server fan speed in rpm, and $P_{cpu,s}$ is CPU power. When a server fan fails (F5), $\omega_s$ falls toward zero, so $R_{th}$ and $T_{cpu,s}$ rise even though the inlet temperature is normal. *[verify] the functional form of $R_{th}(\omega)$ against vendor thermal data.*

**Throttling ratio.**

$$\phi_{f,s} = \frac{f_{cpu,s}}{f_{nom,s}} \tag{9}$$

$f_{cpu,s}$ is the measured CPU clock and $f_{nom,s}$ is its nominal clock. $\phi_{f,s} < 1$ together with $T_{cpu,s}$ near its limit $T_{j,max}$ is evidence of thermal throttling. This is a **consequence** of F1, F2, F4 or F5, not a fault class by itself.

*Status: equations 5 to 9 are planned.*

---

## 4.4 Rack inlet indicators

**Maximum inlet temperature of a rack.**

$$T_{in,max,r} = \max\left(T_{in,top,r},\ T_{in,mid,r}\right) \tag{10}$$

**Vertical stratification.**

$$\Delta T_{strat,r} = T_{in,top,r} - T_{in,mid,r} \tag{11}$$

**Outlet stratification.** The rear probes give the mean outlet temperature $T_{out,r}$ and the upper-half outlet temperature $T_{out,top,r}$. With two halves of similar airflow, the lower half is $T_{out,bot,r} = 2T_{out,r} - T_{out,top,r}$, so:

$$\Delta T_{strat,out,r} = T_{out,top,r} - T_{out,bot,r} = 2\left(T_{out,top,r} - T_{out,r}\right) \tag{11a}$$

Real recirculation heats the upper servers' inlet air, so their exhaust gets hotter too and equation 11a rises. A biased top inlet sensor changes equation 11 but not 11a. Comparing the two separates F4 from S1. The factor of 2 doubles the measurement noise, which is the main reason accuracy drops in the high-noise test category.

**Hot-rack indicator.** $\mathbb{1}[\cdot]$ equals 1 when its condition holds and 0 otherwise.

$$h_r = \mathbb{1}\left[T_{in,max,r} > T_{rec,max}\right] \tag{12}$$

**Fraction of hot racks.** A value at or above $\phi^*$ means the cause is at row level, such as F1 or F2. A value below it means a rack-level cause, such as F4.

$$\phi_{hot} = \frac{1}{n_R} \sum_{r \in \mathcal{R}} h_r \tag{13}$$

$T_{rec,max} = 27$ °C comes from ASHRAE TC 9.9 (2021), and $\phi^* = 0.5$ is an assumption.

*Status: equations 10, 11, 11a and 13 are implemented as `inlet_max/3`, `inlet_stratification/3`, `outlet_stratification/3` and `hot_rack_fraction/2`. Equation 12 is implemented inside `hot_rack_fraction/2`.*

**Supply and return heat indices** (Sharma et al., 2002). SHI measures how much hot exhaust mixes into the cold supply before it reaches the racks. Zero is ideal.

$$SHI = \frac{\sum_{r} \left(T_{in,r} - T_{sa}\right)}{\sum_{r} \left(T_{out,r} - T_{sa}\right)} \tag{14}$$

$$RHI = 1 - SHI \tag{15}$$

$T_{sa}$ is the CRAH supply-air temperature, used here as the reference temperature.

**Rack cooling indices** (Herrlin, 2005). RCI_HI is 100% when no inlet exceeds the recommended maximum.

$$RCI_{HI} = \left[1 - \frac{\sum_{r} \left(T_{in,r} - T_{rec,max}\right)\mathbb{1}\left[T_{in,r} > T_{rec,max}\right]}{n_R\left(T_{all,max} - T_{rec,max}\right)}\right] \times 100\% \tag{16}$$

$$RCI_{LO} = \left[1 - \frac{\sum_{r} \left(T_{rec,min} - T_{in,r}\right)\mathbb{1}\left[T_{in,r} < T_{rec,min}\right]}{n_R\left(T_{rec,min} - T_{all,min}\right)}\right] \times 100\% \tag{17}$$

The constants are $T_{all,max} = 32$ °C, $T_{rec,min} = 18$ °C and $T_{all,min} = 15$ °C for class A1. Applied to the top inlets of synthetic case f01, RCI_HI is about 8.7%, which signals severe overheating across the row.

**Recirculation mixing model.** This is the physical basis for F4. The air reaching an inlet is modelled as a mix of supply air and exhaust air, with recirculation fraction $\beta_r \in [0,1]$.

$$T_{in,r} = (1 - \beta_r)\, T_{sa} + \beta_r\, T_{out,r} \tag{18}$$

Solving for the recirculation fraction gives an estimate from three measurements:

$$\beta_r = \frac{T_{in,r} - T_{sa}}{T_{out,r} - T_{sa}} \tag{19}$$

In a sealed rack $\beta_r$ is close to zero. For the top inlet of rack A04 in case f03, with an assumed rack temperature rise of 13.4 K, $\beta \approx 0.44$.

*Status: equations 14 to 19 are planned. Equation 19 will strengthen rule R22 for F4.*

---

## 4.5 CRAH air side and fan

**Air-side heat removal.**

$$Q_a = \dot m_a\, c_{p,a} \left(T_{ra} - T_{sa}\right) \tag{20}$$

$\dot m_a$ is the CRAH air mass flow and $T_{ra}$ is the return-air temperature.

**Fan affinity laws** (ASHRAE Handbook, fans chapter *[verify edition]*). These hold for a fixed system curve. $N$ is fan speed and the subscript $rated$ marks values at rated speed.

$$\dot V_a = \dot V_{rated} \left(\frac{N}{N_{rated}}\right) \tag{21}$$

$$\Delta p_{fan} = \Delta p_{rated} \left(\frac{N}{N_{rated}}\right)^{2} \tag{22}$$

$$P_{f,exp} = P_{f,rated} \left(\frac{N}{N_{rated}}\right)^{3} \tag{23}$$

**Fan power ratio.** This is the ratio of measured to expected fan power. It is close to 1 for a healthy fan. A value well below 1 means the motor is running but the fan is not moving air, as with a broken belt or coupling (F1).

$$\rho_f = \frac{P_f}{P_{f,exp}} \tag{24}$$

**Fan power from airflow and pressure.** $\eta_f$ is the combined fan and motor efficiency. This links fan power to the system pressure drop, which is how filter loading (F3) shows up.

$$P_f = \frac{\dot V_a\, \Delta p_{tot}}{\eta_f} \tag{25}$$

**Filter pressure drop.** The quadratic form is typical for turbulent flow *[verify against filter manufacturer data]*.

$$\Delta p_{filt} = K_{filt}\, \dot V_a^{2} \tag{26}$$

**Filter loading ratio.** This normalises the resistance coefficient by its clean value, so the test does not depend on the current fan speed.

$$\lambda_{filt} = \frac{K_{filt}}{K_{filt,clean}} = \frac{\Delta p_{filt} / \dot V_a^{2}}{K_{filt,clean}} \tag{27}$$

$\lambda_{filt}$ well above 1 indicates F3.

**Supply-air deviation from setpoint.**

$$\delta_{sa} = T_{sa} - T_{sp} \tag{28}$$

$\delta_{sa} > \Delta T_{band}$ supports F2. A negative value with row-wide overheating supports F1, because the coil over-cools the small airflow that remains.

*Status: equations 23, 24 and 27 are implemented as `expected_fan_power/3`, `fan_power_ratio/3` and `filter_loading/3`. Equation 27 uses equation 21 for the airflow. Equation 28 is implemented inside rules r05, r06 and r47. The rest are planned.*

---

## 4.6 Chilled-water side and coil

**Water temperature rise.**

$$\Delta T_w = T_{wr} - T_{ws} \tag{29}$$

**Water-side heat absorption.** $\dot m_w$ is the water mass flow and $c_{p,w}$ is the specific heat of water.

$$Q_w = \dot m_w\, c_{p,w}\, \Delta T_w \tag{30}$$

**Coil capacity by the effectiveness-NTU method.** $C = \dot m c_p$ is a heat capacity rate in kW/K.

$$Q_{coil} = \varepsilon\, C_{min} \left(T_{ra} - T_{ws}\right) \tag{31}$$

$$NTU = \frac{UA}{C_{min}}, \qquad C^{*} = \frac{C_{min}}{C_{max}} \tag{32}$$

$UA$ is the coil's overall heat-transfer conductance in kW/K. For a counterflow approximation *[verify against the coil geometry; crossflow forms differ]*:

$$\varepsilon = \frac{1 - \exp\left[-NTU\left(1 - C^{*}\right)\right]}{1 - C^{*} \exp\left[-NTU\left(1 - C^{*}\right)\right]} \tag{33}$$

A fall in the effective $UA$ at normal flows would indicate coil fouling. That is outside the current fault set and is listed as future work.

**Equal-percentage valve characteristic.** $\theta_v \in [0,1]$ is the valve opening as a fraction and $\mathcal{R}_v$ is the valve rangeability, typically about 50 *[verify]*.

$$\dot m_w = \dot m_{w,max}\, \mathcal{R}_v^{\,\theta_v - 1} \tag{34}$$

**Water flow ratio.** $\dot m_w^{meas}$ is the measured flow and $\dot m_w^{exp}$ is the flow predicted by equation 34 at the measured valve position. The ratio is close to 1 when the valve and the chilled-water supply are healthy.

$$\rho_w = \frac{\dot m_w^{meas}}{\dot m_w^{exp}} \tag{34a}$$

F2 is the case where $\theta_v$ is high but $\rho_w$ is far below 1, so the coil cannot absorb the heat load. The water temperature rise $\Delta T_w$ is *not* a reliable F2 signature. Low flow makes it larger, not smaller.

*Status: equations 29, 34 and 34a are implemented as `chw_delta_t/3`, `expected_chw_flow/3` and `chw_flow_ratio/3`. The rest are planned. Equations 30 and 34a use the chilled-water flow meter, x25 in Stage 3.*

---

## 4.7 Energy balances and analytical redundancy

These equations are how the system tells sensor faults apart from equipment faults. Each balance can be computed from independent sensors. If one balance breaks while the physically linked variables look normal, a sensor is the likely culprit.

**First law over the row in steady state.** The fan motor heat ends up in the airstream. $Q_{env}$ is the small heat gain through the room envelope.

$$Q_a = P_{IT} + P_f + Q_{env} \tag{35}$$

**Adiabatic coil.** The heat the air loses equals the heat the water gains.

$$Q_w = Q_a \tag{36}$$

**Balance residuals.**

$$r_1 = \frac{Q_a - \left(P_{IT} + P_f\right)}{P_{IT}} \tag{37}$$

$$r_2 = \frac{Q_w - Q_a}{Q_a} \tag{38}$$

**Uncertainty-based residual threshold.** For a product $Q = \dot m c_p \Delta T$, the relative standard uncertainty follows from first-order propagation. $u_T$ is the standard uncertainty of one temperature sensor, so the temperature difference has uncertainty $\sqrt{2}\,u_T$.

$$\frac{u_Q}{Q} = \sqrt{\left(\frac{u_{\dot m}}{\dot m}\right)^{2} + \left(\frac{\sqrt{2}\, u_T}{\Delta T}\right)^{2}} \tag{39}$$

A residual counts as violated when it exceeds a coverage factor $k_c$ times its combined uncertainty:

$$\lvert r_i \rvert > \vartheta_i = k_c\, u_{r_i} \tag{40}$$

As a worked example, take $u_{\dot m}/\dot m = 10\%$ for estimated airflow, $u_T = 0.5$ K and $\Delta T = 13.4$ K. Then $u_{Q_a}/Q_a \approx 11.3\%$. The water side, with a 5% flow meter, $u_T = 0.2$ K and $\Delta T_w = 6$ K, gives about 6.9%. With $k_c = 2$, the threshold for $r_2$ is about 26%. These thresholds come from the sensor specifications rather than being chosen by hand, which makes them defensible.

With the simulator's sensor specifications, $u_{\dot m}/\dot m \approx 6\%$ and $u_T = 0.15$ K on the air side, and 2% and 0.1 K on the water side. Then $u_{r_2} \approx 0.07$, which gives 0.14 with $k_c = 2$. The knowledge base uses **0.2**, close to $k_c = 3$. The extra margin matters because chilled-water loss cases reach $\lvert r_2 \rvert \approx 0.14$ on their own. The cost is that the smallest injected supply-sensor bias, about 3 K, can go undetected.

**Neighbour consistency for temperature sensors (S1).** $\mathcal{N}(r)$ is the set of other racks whose sensors at the same height see the same supply air.

$$r_{S,r} = T_{in,r} - \operatorname{median}_{j \in \mathcal{N}(r)} T_{in,j} \tag{41}$$

A large $\lvert r_{S,r} \rvert$ from one sensor alone suggests sensor bias. If the middle and top sensors of the same rack both deviate in the same direction, the air itself is warmer, so it is not a sensor fault.

**Supply-air sensor check.** The supply air feeds every middle inlet, so the median middle inlet is an independent estimate of the supply-air temperature:

$$r_{sa} = T_{sa} - \operatorname{median}_{r \in \mathcal{R}} T_{in,mid,r} \tag{41a}$$

**Hypothesis test for a supply-air sensor fault.** A large $r_{sa}$ also appears when the cooling unit cannot deliver enough air, because room and hot-aisle air then warm the inlets. To tell the two apart, equation 38 is recomputed with the supply-air reading replaced by the median middle inlet:

$$r_2' = \frac{Q_w - \rho_a \dot V_a c_{p,a}\left(T_{ra} - \operatorname{median}_r T_{in,mid,r}\right)}{\rho_a \dot V_a c_{p,a}\left(T_{ra} - \operatorname{median}_r T_{in,mid,r}\right)} \tag{41b}$$

If the sensor really is biased, the substitution removes the error, so $\lvert r_2' \rvert$ falls within the threshold while $\lvert r_2 \rvert$ did not. If airflow is really lost, the estimated airflow is still wrong and the balance stays broken. This is consistency-based reasoning in miniature: the sensor-fault hypothesis is accepted only if assuming it restores consistency with the knowledge base.

*Status: equations 38, 41, 41a and 41b are implemented as `coil_balance_residual/3`, `mid_inlet_deviation/3`, `top_inlet_deviation/3`, `supply_air_deviation/3` and `coil_balance_residual_corrected/3`. Equations 20 and 30 are implemented as `air_side_heat/3` and `water_side_heat/3`. Equations 35 to 37, 39 and 40 are planned for the consistency-based module.*

---

## 4.8 Electrical distribution

**Three-phase power.** $V_{LL}$ is the line-to-line voltage, $I$ is the line current and $\cos\varphi$ is the power factor.

$$P = \sqrt{3}\, V_{LL}\, I \cos\varphi \tag{42}$$

**Branch loading ratio.** $I_b$ is the current on branch $b$ and $I_{brk,b}$ is its breaker rating. A continuous load above 0.8 is an overload (F6) *[verify against NEC 210.20 or the local code]*.

$$L_b = \frac{I_b}{I_{brk,b}} \tag{43}$$

**Phase current imbalance.** $\bar I$ is the mean of the three phase currents $I_a$, $I_b$ and $I_c$. Imbalance is a common root cause of a single overloaded phase.

$$IU = \frac{\max_{p \in \{a,b,c\}} \lvert I_p - \bar I \rvert}{\bar I} \tag{44}$$

**UPS efficiency and losses.**

$$\eta_{UPS} = \frac{P_{UPS,out}}{P_{UPS,in}} \tag{45}$$

$$P_{UPS,loss} = P_{UPS,in} - P_{UPS,out} \tag{46}$$

In double conversion, $\eta_{UPS}$ is about 0.94 to 0.97 *[verify]*. When the UPS is on static bypass (F8), the load is fed straight from the utility, so $\eta_{UPS}$ jumps to about 1. That jump, together with the mode flag, is the F8 signature.

**Partial power usage effectiveness of the row.** This adapts The Green Grid's PUE to the row boundary.

$$pPUE = \frac{P_{IT} + P_f + P_{UPS,loss}}{P_{IT}} \tag{47}$$

*Status: equations 43 and 45 are implemented as `branch_loading/3` and `ups_efficiency/3`. Equation 42 is applied per phase inside the simulator. The rest are planned.*

---

## 4.9 Battery

**Cell float voltage.** $V_{str}$ is the string voltage and $n_{cell}$ is the number of cells in series.

$$V_{cell} = \frac{V_{str}}{n_{cell}} \tag{48}$$

**Internal resistance ratio.** $R_{cell,0}$ is the commissioning baseline. A rising ratio is the main F7 indicator *[verify the action threshold against IEEE Std 1188 or manufacturer guidance]*.

$$\rho_R = \frac{R_{cell}}{R_{cell,0}} \tag{49}$$

**Peukert runtime.** $t_{run}$ is runtime in hours, $C_H$ is the rated capacity in Ah at the rated discharge time $H$, $I_{dis}$ is the discharge current and $k_p$ is the Peukert exponent, typically 1.1 to 1.3 for lead-acid *[verify]*.

$$t_{run} = H \left(\frac{C_H}{I_{dis}\, H}\right)^{k_p} \tag{50}$$

**Temperature derating of service life.** This is the rule of thumb that VRLA life halves for every 10 K above 25 °C *[verify; sources quote 8 to 10 K]*. $\mathcal{L}_{25}$ is the design life at 25 °C and $T_b$ is the battery temperature.

$$\mathcal{L}(T_b) = \mathcal{L}_{25} \cdot 2^{-(T_b - 25)/10} \tag{51}$$

*Status: equation 49 is implemented as `cell_resistance_ratio/3`. The rest are planned.*

---

## 4.10 Telemetry, preprocessing and statistical evidence

**Sample age.** $t_{now}$ is the evaluation time and $t_x$ is the timestamp of the latest sample of variable $x$. When $a_x > a_{max}$, with $a_{max} = 60$ s *[assumption]*, the value is treated as missing (S2).

$$a_x = t_{now} - t_x \tag{52}$$

**Relative deviation and z-score.** $x_{ref}$ is the design reference value. $\mu_x$ and $\sigma_x$ are the mean and standard deviation of $x$ under normal operation, estimated from the normal synthetic cases.

$$\delta_x = \frac{x - x_{ref}}{x_{ref}}, \qquad z_x = \frac{x - \mu_x}{\sigma_x} \tag{53}$$

**Noise filtering.** An exponentially weighted moving average smooths noisy readings before the rules see them. $\alpha \in (0,1]$ is the smoothing weight.

$$\hat x_k = \alpha\, x_k + (1 - \alpha)\, \hat x_{k-1} \tag{54}$$

*Status: equation 52 is used directly, because the telemetry pipeline reports the sample age. Equation 53 is implemented in `engine/evidence.pl` in a robust form: σ is estimated from the case itself as 1.4826 times the median absolute deviation of the six middle inlets, so one biased sensor cannot distort it. Equation 54 is planned, because each case is a single snapshot.*

---

## 4.11 Evidence aggregation and ranking

**Graded evidence.** A soft threshold turns a z-score into evidence strength in $[0,1]$. This avoids an all-or-nothing flip for borderline cases. $z_0$ is where evidence starts and $z_1$ is where it saturates.

$$e_{j} = \min\left(1,\ \max\left(0,\ \frac{\lvert z_j \rvert - z_0}{z_1 - z_0}\right)\right) \tag{55}$$

**Weighted evidence and confidence for hypothesis $k$.** $w_{jk}$ is the weight of symptom $j$ for hypothesis $k$, taken from the fault signature table. $E_{\neg k}$ is the evidence against $k$, meaning expected symptoms that were observed absent. $\epsilon$ is a small constant that prevents division by zero.

$$E_k = \sum_{j} w_{jk}\, e_{j}, \qquad \mathrm{Conf}(k) = \frac{E_k}{E_k + E_{\neg k} + \epsilon} \tag{56}$$

$\mathrm{Conf}(k)$ is a **ranking score, not a probability**. The report must say so, because the framework warns against claiming probabilistic certainty the model does not support.

*Status: equations 55 and 56 are implemented in `engine/evidence.pl` and `engine/abductive.pl`. Equation 55 is used with the deviation measured past the threshold in units of the feature's noise, $e = \operatorname{clip}(0.5 + d / 4\sigma)$, so $e = 0.5$ at the threshold. The weights $w_{jk}$ are in `kb/causal.pl`. See [09_reasoning_modules.md](09_reasoning_modules.md).*

---

## 4.12 Logical formulation of diagnosis and evaluation

These are the KRR equations from the framework, specialised to this system. They are listed for completeness and traceability but are **not counted** in the 56 above.

**Deductive diagnosis.** $KB$ is the knowledge base and $E$ is the evidence, meaning the observations plus derived conditions.

$$KB \cup E \models F_k$$

**Abductive diagnosis.** A set $D \subseteq \mathcal{H}$ is an explanation if it entails the evidence and is consistent with it. Minimal explanations are preferred.

$$D \cup KB \models E, \qquad D \cup KB \cup E \not\models \bot, \qquad D^{*} = \arg\min_{D} \lvert D \rvert$$

**Consistency-based diagnosis** (Reiter, 1987). $SD$ is the system description, $COMPS$ is the set of components including sensors, $OBS$ is the observations and $AB(c)$ means component $c$ is abnormal. $\Delta \subseteq COMPS$ is a diagnosis when

$$SD \cup OBS \cup \{AB(c) \mid c \in \Delta\} \cup \{\neg AB(c) \mid c \in COMPS \setminus \Delta\} \not\models \bot$$

The minimal diagnoses are the minimal hitting sets of the conflict sets (de Kleer & Williams, 1987).

**Closed-world normality** (rule R30). With $\mathcal{H}$ as above:

$$F_N \iff \left(\forall F_k \in \mathcal{H}:\ KB \cup E \not\models F_k\right) \wedge \left(\forall r:\ T_{in,max,r} \le T_{rec,max}\right)$$

**Evaluation metrics.** TP, TN, FP and FN are true positives, true negatives, false positives and false negatives, counted per fault class and then macro-averaged.

$$\mathrm{Accuracy} = \frac{TP + TN}{TP + TN + FP + FN}, \quad \mathrm{Precision} = \frac{TP}{TP + FP}, \quad \mathrm{Recall} = \frac{TP}{TP + FN}$$

$$F_1 = \frac{2\,\mathrm{Precision} \cdot \mathrm{Recall}}{\mathrm{Precision} + \mathrm{Recall}}, \qquad \mathrm{Coverage} = \frac{N_{correct}}{N_{test}}$$

$$\mathrm{ExplainabilityRate} = \frac{N_{valid\ explanations}}{N_{diagnoses}}, \qquad \mathrm{PlanValidity} = \frac{N_{valid\ plans}}{N_{plans}}$$

**Exact-match ratio for multiple-fault cases.** $Y_i$ is the true fault set of case $i$ and $\hat Y_i$ is the diagnosed set.

$$\mathrm{EMR} = \frac{1}{N_{test}} \sum_{i} \mathbb{1}\left[\hat Y_i = Y_i\right]$$

**Reasoning time.** $\tau_i$ is the wall-clock reasoning time for case $i$.

$$\bar\tau = \frac{1}{N_{test}} \sum_i \tau_i, \qquad \tau_{max} = \max_i \tau_i$$

Counting these logical and evaluation formulas as well gives 69 equations in total.

---

## 4.13 Fault-to-equation traceability

This table shows which equations discriminate each fault. It drives rule design in Stage 6 and the fault-propagation figure.

| Fault | Primary evidence | Discriminating against |
|---|---|---|
| F1 Fan failure | Equations 13, 23, 24 and 28 | F2, through fan power ratio and the sign of the supply-air deviation |
| F2 Chilled-water loss | Equations 28, 34 and 34a | F1, through healthy fan power |
| F3 Filter clogging | Equations 25, 26 and 27 | F1, because the fan still draws power but the pressure drop is high |
| F4 Recirculation | Equations 11, 13, 18 and 19 | S1, through a high recirculation fraction and a consistent energy balance |
| F5 Server fan failure | Equations 8 and 9 | F4, because the rack inlet is normal |
| F6 Branch overload | Equations 42, 43 and 44 | Metering faults, through equation 4 |
| F7 Battery degradation | Equations 48 to 51 | Temperature-only ageing, through the resistance ratio |
| F8 UPS on bypass | Equations 45 and 46 | Normal operation, through the efficiency jump |
| S1 Sensor bias | Equations 37 to 41 | F4, through neighbour consistency and energy balance |
| S2 Telemetry dropout | Equation 52 | All faults, because the evidence is missing rather than abnormal |

---

## 4.14 Nomenclature

| Symbol | Meaning | Unit |
|---|---|---|
| $a_x$, $a_{max}$ | Sample age of variable $x$, and its limit | s |
| $C_H$ | Battery rated capacity at discharge time $H$ | Ah |
| $C_{min}$, $C_{max}$, $C^{*}$ | Smaller and larger heat capacity rates, and their ratio | kW/K, kW/K, – |
| $c_{p,a}$, $c_{p,w}$ | Specific heat of air (1.006) and water (4.186) | kJ/(kg·K) |
| $e_j$ | Graded evidence strength of symptom $j$ | – |
| $E_k$, $E_{\neg k}$ | Weighted evidence for and against hypothesis $k$ | – |
| $f_{cpu,s}$, $f_{nom,s}$ | Measured and nominal CPU clock | GHz |
| $H$ | Rated discharge time of the battery | h |
| $h_r$ | Hot-rack indicator | – |
| $I$, $I_p$, $\bar I$ | Line current, phase current, mean phase current | A |
| $I_b$, $I_{brk,b}$ | Branch current and breaker rating | A |
| $I_{dis}$ | Battery discharge current | A |
| $IU$ | Phase current imbalance | – |
| $K_{filt}$, $K_{filt,clean}$ | Filter resistance coefficient, current and clean | Pa·s²/m⁶ |
| $k_c$ | Coverage factor | – |
| $k_p$ | Peukert exponent | – |
| $L_b$ | Branch loading ratio | – |
| $\mathcal{L}(T_b)$, $\mathcal{L}_{25}$ | Battery service life at $T_b$ and at 25 °C | years |
| $\dot m$, $\dot m_a$, $\dot m_r$, $\dot m_s$, $\dot m_w$ | Mass flow: general, CRAH air, rack, server, water | kg/s |
| $\dot m_{w,max}$ | Water mass flow with the valve fully open | kg/s |
| $N$, $N_{rated}$ | CRAH fan speed and rated speed | % |
| $n_R$, $n_{cell}$ | Number of racks, number of cells in series | – |
| $NTU$ | Number of transfer units | – |
| $P$ | Three-phase electrical power | kW |
| $P_s$, $P_r$, $P_{IT}$ | Server, rack and row IT power | kW |
| $P_r^{meas}$ | Metered rack power | kW |
| $P_{idle}$, $P_{max}$ | Server idle and full-load power | kW |
| $P_{cpu,s}$ | CPU power of server $s$ | kW |
| $P_f$, $P_{f,exp}$, $P_{f,rated}$ | Fan power: measured, expected, rated | kW |
| $P_{UPS,in}$, $P_{UPS,out}$, $P_{UPS,loss}$ | UPS input, output and loss power | kW |
| $pPUE$ | Partial power usage effectiveness of the row | – |
| $Q_a$, $Q_w$, $Q_{coil}$, $Q_{env}$ | Heat flows: air side, water side, coil capacity, envelope gain | kW |
| $R_{cell}$, $R_{cell,0}$ | Cell internal resistance, current and baseline | mΩ |
| $R_{th}$ | CPU junction-to-inlet thermal resistance | K/kW |
| $\mathcal{R}_v$ | Valve rangeability | – |
| $r_1$, $r_2$ | Energy balance residuals | – |
| $r_{S,r}$ | Neighbour-consistency residual of rack $r$ | K |
| $RCI_{HI}$, $RCI_{LO}$ | Rack cooling indices | % |
| $SHI$, $RHI$ | Supply and return heat indices | – |
| $T_{in,r}$, $T_{in,top,r}$, $T_{in,mid,r}$ | Rack inlet temperature: general, top, middle | °C |
| $T_{in,max,r}$ | Maximum inlet temperature of rack $r$ | °C |
| $T_{out,r}$ | Rack outlet temperature | °C |
| $T_{sa}$, $T_{ra}$, $T_{sp}$ | CRAH supply, return and setpoint temperatures | °C |
| $T_{ws}$, $T_{wr}$ | Chilled-water supply and return temperatures | °C |
| $T_{cpu,s}$, $T_{j,max}$ | CPU temperature and its junction limit | °C |
| $T_b$ | Battery temperature | °C |
| $T_{rec,max}$, $T_{rec,min}$ | ASHRAE recommended limits, 27 and 18 | °C |
| $T_{all,max}$, $T_{all,min}$ | ASHRAE A1 allowable limits, 32 and 15 | °C |
| $t_{run}$ | Battery runtime | h |
| $t_{now}$, $t_x$ | Evaluation time and sample timestamp | s |
| $u_s$ | Server CPU utilisation | – |
| $u_Q$, $u_T$, $u_{\dot m}$, $u_{r_i}$ | Standard uncertainties | as the quantity |
| $UA$ | Coil overall heat-transfer conductance | kW/K |
| $V_{LL}$ | Line-to-line voltage | V |
| $V_{str}$, $V_{cell}$ | Battery string and cell voltage | V |
| $\dot V$, $\dot V_a$, $\dot V_{rated}$ | Volume flow: general, CRAH, rated | m³/s |
| $w_{jk}$ | Weight of symptom $j$ for hypothesis $k$ | – |
| $x$, $x_{ref}$, $\hat x_k$ | Variable, reference value, filtered value | as the variable |
| $\alpha$ | Smoothing weight | – |
| $\beta_r$ | Recirculation fraction of rack $r$ | – |
| $\Delta p_{fan}$, $\Delta p_{rated}$, $\Delta p_{tot}$, $\Delta p_{filt}$ | Pressure rise or drop: fan, rated, total system, filter | Pa |
| $\Delta T_s$, $\Delta T_w$, $\Delta T_{strat,r}$ | Temperature differences: server, water, stratification | K |
| $\Delta T_{band}$ | Supply-air tolerance band, 2 K | K |
| $\delta_{sa}$, $\delta_x$ | Supply-air deviation, relative deviation | K, – |
| $\varepsilon$ | Coil effectiveness | – |
| $\varepsilon_{P,r}$ | Rack power model residual | – |
| $\epsilon$ | Small positive constant | – |
| $\eta_f$, $\eta_{UPS}$ | Fan and UPS efficiency | – |
| $\theta_v$ | Valve opening fraction | – |
| $\lambda_{filt}$ | Filter loading ratio | – |
| $\mu_x$, $\sigma_x$, $z_x$, $z_0$, $z_1$ | Normal mean, standard deviation, z-score and soft-threshold limits | – |
| $\rho_a$ | Air density, 1.2 | kg/m³ |
| $\rho_f$, $\rho_R$ | Fan power ratio, internal resistance ratio | – |
| $\vartheta_i$ | Violation threshold of residual $r_i$ | – |
| $\tau_i$, $\bar\tau$, $\tau_{max}$ | Reasoning time of case $i$, its mean and maximum | ms |
| $\varphi$ | Phase angle, so $\cos\varphi$ is the power factor | rad |
| $\phi_{hot}$, $\phi^*$ | Hot-rack fraction and its row-level threshold, 0.5 | – |
| $\phi_{f,s}$ | CPU frequency ratio | – |
| $\omega_s$ | Server fan speed | rpm |
