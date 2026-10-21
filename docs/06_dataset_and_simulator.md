# Stage 11: Dataset and Simulator

**Status:** Draft v0.2.

## 11.1 Data origin

**Every case in this project is synthetic.** No value is a measurement from a real data centre, and the report must never present one as such. The framework requires four kinds of information to be kept apart. This project keeps them apart as follows:

| Kind | Where it lives |
|---|---|
| Measured data | None in this project |
| Synthetic test cases | `data/cases.pl` (4 hand-written), `data/generated_cases.pl` (255 simulated, calibration split) and `data/holdout_cases.pl` (255 simulated, held-out split). Every `case/3` fact carries the origin `synthetic` |
| Engineering assumptions | Sources of type `assumption` in `kb/sources.pl`, and the simulator assumptions in section 11.4 |
| Literature-supported rules | Sources of type `standard` or `literature` in `kb/sources.pl` |

## 11.2 How to regenerate

From the project folder:

```
python simulator/dc_sim.py
python simulator/dc_sim.py --seed 777 --prefix h --split holdout --out data/holdout_cases.pl --csv data/holdout_cases.csv --truth data/holdout_truth.json
```

The first command builds the calibration split with seed 20261020 and case IDs g001 to g255. The second builds the held-out split with seed 777 and case IDs h001 to h255. The same seed always gives the same files. Only the Python standard library is needed. Python only generates data. All diagnosis happens in Prolog.

| Output file | Contents |
|---|---|
| `data/generated_cases.pl`, `data/holdout_cases.pl` | Prolog facts: `case/3`, `case_category/2`, `case_split/2`, `expected/2`, `obs/4` |
| `data/generated_cases.csv`, `data/holdout_cases.csv` | The same observations in long format, with units, for analysis outside Prolog |
| `data/generated_truth.json`, `data/holdout_truth.json` | The hidden ground truth for each case, such as fault severities, the biased sensor and the stale entity |

## 11.3 How the simulator works

Each case goes through four steps:

1. **Workload.** The row load is drawn as low (10 to 20% CPU), nominal (40 to 60%) or high (80 to 90%). Each rack varies around the row value, and each server around its rack.
2. **Fault injection into the physics.** A fault changes a physical parameter, never a reading directly. A fan failure cuts the airflow the fan delivers, and the temperatures follow from that. The table below lists each fault's parameter.
3. **Steady-state solution.** The simulator solves the coupled server, rack, cooling-unit and coil equations from Stage 4 by damped fixed-point iteration. The cooling-unit fan follows airflow demand, and the valve controller finds the smallest opening that holds the 20 °C setpoint.
4. **Sensor layer.** It applies sensor bias, Gaussian measurement noise, frozen values for stale telemetry, and randomly missing readings.

| Fault | Physical parameter changed | Clear range | Borderline range |
|---|---|---|---|
| F1 fan failure | Airflow fraction delivered, and fan power over the affinity-law prediction | 0 to 0.1, and 0.05 to 0.15 | 0.3 to 0.5, and 0.4 to 0.6 |
| F2 chilled-water loss | Fraction of design water flow available | 0.02 to 0.2 | 0.25 to 0.4 |
| F3 filter clogging | Filter loading ratio, Stage 4 equation 27 | 3 to 6 | 1.8 to 2.5 |
| F4 recirculation | Extra recirculation fraction at the top of one rack | 0.25 to 0.5 | 0.12 to 0.2 |
| F5 server fan failure | Server airflow falls to 0.012 kg/s and the reported fan speed to near zero | – | – |
| F6 branch overload | Phase 1 share of feed A power, set to give a target current | 27 to 30 A | 24.5 to 26.5 A |
| F7 battery degradation | Cell resistance ratio, with low float voltage and sometimes high temperature | 1.5 to 2.5 | 1.2 to 1.4 |
| F8 UPS on bypass | Mode flag set to bypass, and efficiency rises to 0.99 | – | – |
| S1 sensor bias | Offset of 3 to 8 K on one inlet or supply-air sensor | – | – |
| S2 telemetry dropout | One telemetry group frozen at pre-fault values, with a sample age of 300 to 1800 s | – | – |

## 11.4 Simulator assumptions

These assumptions need to be justified in the report.

| Assumption | Value | Reason |
|---|---|---|
| Server power model | 0.40 kW idle, 0.90 kW at full load, 55% of it in the CPU | Stage 4 equation 1. A typical two-socket server *[verify]* |
| Server airflow | 0.055 kg/s at nominal fan speed, scaling with fan speed | Gives a 13 to 16 K rise across a server |
| Server fan control | Speed rises with utilisation and with inlet temperature above 24 °C | Typical baseboard controller behaviour |
| CPU throttling | The clock drops so the CPU stays at or below 95 °C | Vendor limits vary *[verify]* |
| Cooling-unit fan control | Supplies 10% more air than the servers demand | Common practice to avoid recirculation |
| Coil heat transfer | 15 kW/K on the air side. 10 kW/K on the water side at 3.2 kg/s, scaling with flow to the power 0.8 | Tuned so the water warms by 5 to 7 K in normal operation |
| Airflow shortfall | 40% of the missing air comes from the hot aisle, 60% from room air at 25 °C | Without this, a fan failure has no steady state. It stands in for leakage paths and other cooling units in the room |
| Natural top-of-rack recirculation | 10% in a sealed rack | Gives the 1 to 2 K top-to-middle difference seen in normal cases |
| Noise | For example 0.15 K on air temperatures and 1% on power and current | Typical sensor accuracy *[verify against datasheets]* |
| Steady state | No transients are modelled | A limitation. A real chilled-water loss heats the room over minutes |

## 11.5 Dataset composition

| Category | Cases | Framework test | Contents |
|---|---|---|---|
| normal | 30 | A | 10 each at low, nominal and high load |
| single_fault | 120 | B, C, D | 15 cases each of F1 to F8 |
| instrumentation | 30 | E | 15 sensor-bias and 15 telemetry-dropout cases |
| multiple | 30 | F | 6 cases each of: F3 with F4, F4 with a sensor bias that hides it, F7 with F8, F1 with F6, and F4 with F5 in the same rack |
| noisy | 15 | G | A random single fault with 5 times normal sensor noise |
| incomplete | 15 | G | A random single fault or normal case with 15% of readings removed |
| borderline | 15 | G | Fault severities near the detection thresholds, plus high-load normal cases |
| smoke | 4 | H | The hand-written cases in `data/cases.pl`, used for the explanation demonstration |

Each case has about 460 readings: 9 cooling-unit variables, 6 per rack, one current per rack PDU phase with 6 phases per rack, 3 per server, 6 for the UPS and battery, and one sample age per telemetry group.

**Power distribution.** Each rack has two independent feeds, A and B, that share the rack load equally. This 2N arrangement is standard in data centres. An earlier single-feed design ran at 81% of breaker rating in normal operation at high load, which would make any overload rule fire falsely.

**Entity naming.** Racks are `rack_a01` to `rack_a06`. Servers are `rack_a01_s01` to `rack_a06_s20`. Rack PDU phases are `rack_a01_a_l1` to `rack_a06_b_l3`, for feed A or B and phase 1 to 3. The other entities are `crah_1`, `ups_1` and `battery_1`.

**Labels.** `expected/2` lists the injected faults as Prolog terms. Examples are `crah_fan_failure(crah_1)`, `server_fan_failure(rack_a03_s07)`, `sensor_bias(t_inlet_top, rack_a04)` and `telemetry_dropout(ups_1)`. A consequence such as CPU throttling during a fan failure is not labelled separately.

## 11.6 Data dictionary

Variables, units and sensors are defined in [Stage 3](03_observation_variables.md). The simulator emits these variables: x1 to x7, x8 as `dp_filter`, x9 to x13, x14 as the mean utilisation per rack, x15 to x24 with x22 as the highest monitored cell resistance, x25 and x26.

## 11.7 Calibration and held-out evaluation

**Method.** The rule thresholds were set from engineering reasoning. They were then checked against the calibration split, by profiling each signature in normal and fault cases. The held-out split was generated afterwards with a different seed. It was never used to choose or adjust anything, so its results measure how well the rules generalise.

**Results with deductive reasoning only.** All 44 rules are in place, covering every fault class.

| Category | Calibration | Held-out |
|---|---|---|
| Normal | 30 of 30 | 30 of 30 |
| Single fault, F1 to F8 | 120 of 120 | 120 of 120 |
| Instrumentation, S1 and S2 | 29 of 30 | 30 of 30 |
| Multiple faults | 30 of 30 | 30 of 30 |
| Incomplete evidence | 12 of 15 | 13 of 15 |
| Borderline | 4 of 15 | 6 of 15 |
| High noise | 2 of 15 | 3 of 15 |
| **All** | **227 of 255, 89.0%** | **232 of 255, 91.0%** |

The held-out score is slightly higher than the calibration score. That makes overfitting to the calibration data unlikely. Mean reasoning time is about 0.2 ms per case, and the maximum is under 0.6 ms.

## 11.8 Where the rules fail, and why

- **High noise.** At five times normal noise, temperature sensors scatter by about 0.75 K. Equation 11a doubles the difference of two readings, so outlet stratification scatters by about 2 K. The stratification rules then report recirculation and top-sensor faults that are not there. The fault that was really injected is almost always found as well, so these are extra findings rather than misses. Preferring the smallest set of faults that explains the evidence, the job of the abductive module, is the planned remedy. Repeated readings with the noise filter in Stage 4 equation 54 would also help.
- **Borderline faults.** These are injected at severities near or below the thresholds, so many are diagnosed as normal. This is the intended behaviour of a threshold rule, and the category exists to measure it. It feeds the threshold sensitivity study in Stage 14.
- **Borderline fan failures** produce an airflow shortfall without a low enough fan power ratio. They are reported as an unexplained abnormality, which escalates to a technician. An earlier version of the supply-sensor rule blamed the sensor in these cases. The rule now accepts a sensor fault only if assuming it closes the coil energy balance, as described in Stage 4 equation 41b. That change turned three confident wrong answers into honest escalations.
- **Incomplete evidence.** When the one reading a rule depends on is missing, that rule cannot fire. Backup rules use independent evidence: a fan failure also makes the supply air unusually cold, and a chilled-water loss also shows as hot supply air with the valve open. They recover some of these cases. The rest are reported as normal or unexplained.
- **A 3 K supply-air sensor bias** is the smallest the simulator injects. It sits just inside the energy balance threshold, as explained under Stage 4 equation 40.

## 11.9 Lessons from the simulator

The simulator found three errors in the knowledge base that hand-made cases did not reveal. These belong in the report's validation section.

1. **Chilled-water loss signature.** The first rule expected the water temperature rise to fall to zero. Physically, low flow makes it rise. The rule now compares measured flow with the flow that the valve position predicts.
2. **Overload false alarms.** A single-feed rack design ran near its breaker limit in normal operation. The design was changed to dual feeds, as in real data centres.
3. **Recirculation against sensor bias.** A rule that checked inlet stratification against outlet stratification failed, because server fans speed up when their inlet air is hot. The final rules compare outlet stratification on its own with a fixed threshold.
