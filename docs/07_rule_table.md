# Diagnostic Rule and Provenance Tables

Generated from `kb/rules.pl`, `kb/thresholds.pl` and `kb/sources.pl` by `tests/export_rules.pl`. Do not edit by hand.

Variables are written as capital letters. In each row `A` is the case being diagnosed. `\+` is negation as failure.

## Diagnostic rules

| Rule | Concludes | If all of these hold | Source | Source type |
|---|---|---|---|---|
| r01 | condition `rack_inlet_hot(B)` | `component(B,rack)`, `inlet_max(A,B,C)`, `threshold(t_inlet_rec_max,D)`, `C>D` | ashrae_tc99_2021 | standard |
| r02 | condition `row_inlet_hot` | `hot_rack_fraction(A,B)`, `threshold(row_hot_fraction,C)`, `B>=C` | a2_row_fraction | assumption |
| r03 | condition `localised_inlet_hot(B)` | `cond(A,rack_inlet_hot(B))`, `hot_rack_fraction(A,C)`, `threshold(row_hot_fraction,D)`, `C<D` | a2_row_fraction | assumption |
| r04 | condition `inlet_stratified(B)` | `inlet_stratification(A,B,C)`, `threshold(strat_max,D)`, `C>D` | a5_stratification | assumption |
| r05 | condition `supply_air_hot(B)` | `component(B,crah)`, `obs(A,t_supply_air,B,C)`, `threshold(t_supply_setpoint,D)`, `threshold(t_supply_band,E)`, `C>D+E` | a1_supply_setpoint | assumption |
| r06 | condition `supply_air_normal(B)` | `component(B,crah)`, `obs(A,t_supply_air,B,C)`, `threshold(t_supply_setpoint,D)`, `threshold(t_supply_band,E)`, `C=<D+E` | a1_supply_setpoint | assumption |
| r07 | condition `fan_power_low(B)` | `component(B,crah)`, `fan_power_ratio(A,B,C)`, `threshold(fan_ratio_min,D)`, `C<D` | a6_fan_ratio | assumption |
| r08 | condition `fan_power_normal(B)` | `component(B,crah)`, `fan_power_ratio(A,B,C)`, `threshold(fan_ratio_min,D)`, `C>=D` | ashrae_hb_fans | literature |
| r09 | condition `valve_open(B)` | `obs(A,valve_position,B,C)`, `threshold(valve_open_min,D)`, `C>=D` | a3_valve_open | assumption |
| r10 | condition `chw_flow_low(B)` | `chw_flow_ratio(A,B,C)`, `threshold(chw_flow_ratio_min,D)`, `C<D` | a4_chw_flow | assumption |
| r20 | fault `crah_fan_failure(B)` | `cond(A,row_inlet_hot)`, `cond(A,fan_power_low(B))` | ashrae_hb_fans | literature |
| r21 | fault `chw_supply_loss(B)` | `cond(A,supply_air_hot(B))`, `cond(A,valve_open(B))`, `cond(A,chw_flow_low(B))`, `cond(A,fan_power_normal(B))` | a4_chw_flow | assumption |
| r11 | condition `outlet_stratified(B)` | `outlet_stratification(A,B,C)`, `threshold(strat_out_max,D)`, `C>D` | a7_outlet_strat | assumption |
| r12 | condition `outlet_not_stratified(B)` | `outlet_stratification(A,B,C)`, `threshold(strat_out_max,D)`, `C=<D` | a7_outlet_strat | assumption |
| r13 | condition `inlet_not_stratified(B)` | `inlet_stratification(A,B,C)`, `threshold(strat_max,D)`, `C=<D` | a5_stratification | assumption |
| r14 | condition `filter_loaded(B)` | `component(B,crah)`, `filter_loading(A,B,C)`, `threshold(filter_loading_max,D)`, `C>D` | a8_filter | assumption |
| r15 | condition `server_fan_stopped(B)` | `obs(A,server_fan_rpm,B,C)`, `threshold(server_fan_min,D)`, `C<D` | a9_server_fan | assumption |
| r16 | condition `cpu_hot(B)` | `obs(A,t_cpu,B,C)`, `threshold(cpu_hot_min,D)`, `C>=D` | a10_cpu | assumption |
| r17 | condition `branch_overloaded(B)` | `branch_loading(A,B,C)`, `threshold(branch_loading_max,D)`, `C>D` | nec_continuous | standard |
| r18 | condition `cell_resistance_high(B)` | `component(B,battery)`, `cell_resistance_ratio(A,B,C)`, `threshold(cell_r_ratio_max,D)`, `C>D` | a11_battery | assumption |
| r19 | condition `ups_efficiency_bypass_like(B)` | `component(B,ups)`, `ups_efficiency(A,B,C)`, `threshold(ups_eff_bypass_min,D)`, `C>=D` | a12_ups | assumption |
| r40 | condition `mid_inlet_deviates(B)` | `component(B,rack)`, `mid_inlet_deviation(A,B,C)`, `threshold(neighbour_dev_max,D)`, `abs(C)>D`, `\+cond(A,inlet_rise_corroborated(B))` | a13_neighbour | assumption |
| r45 | condition `inlet_rise_corroborated(B)` | `mid_inlet_deviation(A,B,C)`, `top_inlet_deviation(A,B,D)`, `C*D>0`, `threshold(neighbour_dev_max,E)`, `abs(D)>E` | a13_neighbour | assumption |
| r46 | condition `top_inlet_sensor_suspect(B)` | `component(B,rack)`, `inlet_stratification(A,B,C)`, `threshold(neighbour_dev_max,D)`, `C< -D`, `\+cond(A,mid_inlet_deviates(B))` | eq18_mixing | method |
| r41 | condition `top_inlet_sensor_suspect(B)` | `cond(A,inlet_stratified(B))`, `cond(A,outlet_not_stratified(B))`, `\+cond(A,mid_inlet_deviates(B))` | a7_outlet_strat | assumption |
| r42 | condition `top_inlet_sensor_suspect(B)` | `cond(A,outlet_stratified(B))`, `cond(A,inlet_not_stratified(B))`, `\+cond(A,mid_inlet_deviates(B))` | a7_outlet_strat | assumption |
| r43 | condition `supply_sensor_inconsistent(B)` | `component(B,crah)`, `cond(A,fan_power_nominal(B))`, `supply_air_deviation(A,B,C)`, `threshold(neighbour_dev_max,D)`, `abs(C)>D`, `coil_balance_residual(A,B,E)`, `threshold(balance_resid_max,F)`, `abs(E)>F`, `coil_balance_residual_corrected(A,B,G)`, `abs(G)=<F` | eq40_uncertainty | method |
| r48 | condition `fan_power_nominal(B)` | `component(B,crah)`, `fan_power_ratio(A,B,C)`, `threshold(fan_ratio_reduced,D)`, `C>=D` | a17_fan_reduced | assumption |
| r49 | condition `fan_power_reduced(B)` | `component(B,crah)`, `fan_power_ratio(A,B,C)`, `threshold(fan_ratio_reduced,D)`, `C<D` | a17_fan_reduced | assumption |
| r47 | condition `supply_air_cold(B)` | `component(B,crah)`, `obs(A,t_supply_air,B,C)`, `threshold(t_supply_setpoint,D)`, `threshold(t_supply_band,E)`, `C<D-E` | a1_supply_setpoint | assumption |
| r44 | condition `telemetry_stale(B)` | `obs(A,sample_age,B,C)`, `threshold(sample_age_max,D)`, `C>D` | a14_telemetry | assumption |
| r36 | fault `crah_fan_failure(B)` | `cond(A,row_inlet_hot)`, `cond(A,supply_air_cold(B))`, `\+cond(A,supply_sensor_inconsistent(B))` | a1_supply_setpoint | assumption |
| r38 | fault `crah_fan_failure(B)` | `cond(A,fan_power_reduced(B))`, `cond(A,row_inlet_hot)` | a17_fan_reduced | assumption |
| r37 | fault `chw_supply_loss(B)` | `cond(A,supply_air_hot(B))`, `cond(A,valve_open(B))`, `cond(A,fan_power_normal(B))`, `\+obs(A,m_chw,B,C)`, `\+cond(A,supply_sensor_inconsistent(B))` | a4_chw_flow | assumption |
| r22 | fault `hot_air_recirculation(B)` | `cond(A,localised_inlet_hot(B))`, `serves(C,B)`, `cond(A,supply_air_normal(C))`, `cond(A,inlet_stratified(B))`, `\+cond(A,top_inlet_sensor_suspect(B))` | eu_coc_dc | standard |
| r23 | fault `hot_air_recirculation(B)` | `cond(A,inlet_stratified(B))`, `cond(A,outlet_stratified(B))`, `serves(C,B)`, `cond(A,supply_air_normal(C))` | eu_coc_dc | standard |
| r24 | fault `hot_air_recirculation(B)` | `cond(A,outlet_stratified(B))`, `cond(A,inlet_not_stratified(B))`, `serves(C,B)`, `cond(A,supply_air_normal(C))` | eu_coc_dc | standard |
| r25 | fault `filter_clogging(B)` | `cond(A,filter_loaded(B))`, `cond(A,fan_power_normal(B))` | a8_filter | assumption |
| r26 | fault `server_fan_failure(B)` | `cond(A,server_fan_stopped(B))`, `cond(A,cpu_hot(B))` | a9_server_fan | assumption |
| r27 | fault `branch_overload(B)` | `cond(A,branch_overloaded(B))` | nec_continuous | standard |
| r28 | fault `battery_degradation(B)` | `cond(A,cell_resistance_high(B))` | a11_battery | assumption |
| r29 | fault `ups_on_bypass(B)` | `component(B,ups)`, `obs(A,ups_mode,B,bypass)` | a12_ups | assumption |
| r35 | fault `ups_on_bypass(B)` | `component(B,ups)`, `\+obs(A,ups_mode,B,C)`, `cond(A,ups_efficiency_bypass_like(B))` | a12_ups | assumption |
| r50 | fault `sensor_bias(t_inlet_mid,B)` | `cond(A,mid_inlet_deviates(B))` | a13_neighbour | assumption |
| r51 | fault `sensor_bias(t_inlet_top,B)` | `cond(A,top_inlet_sensor_suspect(B))` | a7_outlet_strat | assumption |
| r52 | fault `sensor_bias(t_supply_air,B)` | `cond(A,supply_sensor_inconsistent(B))` | eq40_uncertainty | method |
| r53 | fault `telemetry_dropout(B)` | `cond(A,telemetry_stale(B))` | a14_telemetry | assumption |

Rules r30 and r31 are the closed-world conclusions in `engine/deductive.pl`. r30 concludes normal when no fault rule fires and every rack inlet is within the envelope. r31 concludes an unexplained abnormality otherwise.

## Thresholds

| Name | Value | Unit | Source |
|---|---|---|---|
| t_inlet_rec_max | 27.0 | degC | ashrae_tc99_2021 |
| t_inlet_rec_min | 18.0 | degC | ashrae_tc99_2021 |
| t_supply_setpoint | 20.0 | degC | a1_supply_setpoint |
| t_supply_band | 2.0 | kelvin | a1_supply_setpoint |
| row_hot_fraction | 0.5 | ratio | a2_row_fraction |
| valve_open_min | 50.0 | percent | a3_valve_open |
| chw_flow_ratio_min | 0.3 | ratio | a4_chw_flow |
| strat_max | 3.0 | kelvin | a5_stratification |
| fan_ratio_min | 0.5 | ratio | a6_fan_ratio |
| strat_out_max | 3.5 | kelvin | a7_outlet_strat |
| filter_loading_max | 1.7 | ratio | a8_filter |
| server_fan_min | 1000.0 | rpm | a9_server_fan |
| cpu_hot_min | 85.0 | degC | a10_cpu |
| branch_loading_max | 0.8 | ratio | nec_continuous |
| cell_r_ratio_max | 1.3 | ratio | a11_battery |
| ups_eff_bypass_min | 0.98 | ratio | a12_ups |
| neighbour_dev_max | 2.0 | kelvin | a13_neighbour |
| balance_resid_max | 0.2 | ratio | eq40_uncertainty |
| sample_age_max | 60.0 | s | a14_telemetry |
| t_supply_hot_limit | 22.0 | degC | a1_supply_setpoint |
| fan_ratio_reduced | 0.85 | ratio | a17_fan_reduced |
| t_supply_cold_limit | 18.0 | degC | a1_supply_setpoint |
| power_resid_max | 0.1 | ratio | a15_power_balance |
| sensor_noise_floor | 0.15 | kelvin | a16_noise |

## Sources

| Id | Type | Citation |
|---|---|---|
| ashrae_tc99_2021 | standard | ASHRAE TC 9.9 (2021). Thermal guidelines for data processing environments (5th ed.). ASHRAE. |
| ashrae_hb_fans | literature | ASHRAE Handbook - HVAC Systems and Equipment, fans chapter (edition to confirm). Fan affinity laws. |
| eu_coc_dc | standard | European Commission JRC. European Code of Conduct on Data Centre Energy Efficiency: Best Practice Guidelines (edition to confirm). |
| a1_supply_setpoint | assumption | Design assumption: CRAH supply-air setpoint 20 C with a 2 K tolerance band. |
| a2_row_fraction | assumption | Engineering assumption: overheating at half or more of the racks indicates a row-level cause. |
| a3_valve_open | assumption | Engineering assumption: a valve open 50% or more should produce a measurable water temperature rise. |
| a4_chw_flow | assumption | Engineering assumption: measured water flow below 30% of the valve-characteristic prediction means chilled-water supply is lost. |
| a5_stratification | assumption | Engineering assumption: a top-to-middle inlet difference above 3 K indicates hot-air recirculation. |
| a6_fan_ratio | assumption | Engineering assumption: fan power below 50% of the affinity-law prediction means the fan is not moving air. |
| closed_world | method | Closed-world assumption: normal operation is concluded when no fault rule fires and all inlets are within the envelope. |
| nec_continuous | standard | NFPA 70 National Electrical Code, continuous-load rule: 80% of breaker rating (article and edition to confirm; check the local code). |
| a7_outlet_strat | assumption | Engineering assumption: a top-to-bottom outlet difference above 3.5 K confirms recirculation. Normal racks stay below 3 K. |
| a8_filter | assumption | Engineering assumption: filter resistance 1.7 times its clean value calls for replacement (check against manufacturer final-resistance data). |
| a9_server_fan | assumption | Engineering assumption: a server fan below 1000 rpm has failed. The controller never runs it below about 5400 rpm. |
| a10_cpu | assumption | Engineering assumption: CPU temperature of 85 C or more, 10 K below the 95 C throttling limit, confirms lost server cooling. |
| a11_battery | assumption | Engineering assumption: cell internal resistance 30% above its baseline indicates degradation (check against IEEE Std 1188 and manufacturer guidance). |
| a12_ups | assumption | Engineering assumption: UPS efficiency of 0.98 or more is only reached on static bypass. Double conversion runs at about 0.95. |
| a13_neighbour | assumption | Engineering assumption: a temperature sensor more than 2 K from the median of sensors that see the same air is suspect (Stage 4 Eq. 41). |
| eq40_uncertainty | method | Residual threshold from uncertainty propagation, Stage 4 Eqs. 39 and 40, with a coverage factor of about 3. |
| a14_telemetry | assumption | Engineering assumption: a sample older than 60 s is stale, given a polling interval of about 30 s. |
| eq18_mixing | method | Physical constraint from the mixing model, Stage 4 Eq. 18: the top inlet cannot be colder than the middle inlet. |
| a15_power_balance | assumption | Engineering assumption: metered rack power and the sum of its six phase currents agree within 10% when both meters are healthy (Stage 4 Eq. 42). |
| a16_noise | assumption | Engineering assumption: temperature-sensor noise is at least 0.15 K (typical datasheet accuracy). Higher noise is estimated from the spread of middle inlets, which all see the same supply air. |
| a17_fan_reduced | assumption | Engineering assumption: fan power below 85% of the affinity-law prediction shows a partial failure such as belt slip. Healthy fans stay within 5%. |

47 rules in total. 36 of them rest on a source of type assumption and need justification in the report.
