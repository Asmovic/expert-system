/*  kb/causal.pl - causal knowledge for abductive diagnosis.

    evidence(Hypothesis, Symptom, Weight)
      The hypothesis predicts the symptom. Weight is w_jk in Stage 4 Eq. 56.
      Every evidence symptom is also one the hypothesis can explain.
    requires(Hypothesis, Symptom)
      If the symptom is clearly absent, the hypothesis is rejected, unless
      another hypothesis in the same explanation masks the symptom.
    also_explains(Hypothesis, Symptom)
      Symptoms the hypothesis can account for without predicting them,
      such as a biased sensor producing a false stratification reading.
    masks(Hypothesis, Symptom)
      The hypothesis can hide the symptom, as a low-reading sensor hides a
      real temperature rise.

    The signatures come from the fault table in docs/02_fault_taxonomy.md.
*/

:- discontiguous evidence/3, requires/2, also_explains/2, masks/2.

%   F1 CRAH supply fan failure
evidence(crah_fan_failure(U), fan_power_low(U),         1.0).
evidence(crah_fan_failure(U), fan_power_reduced(U),     0.8).
evidence(crah_fan_failure(U), row_inlet_hot,            0.6) :- component(U, crah).
evidence(crah_fan_failure(U), supply_air_cold(U),       0.6).
evidence(crah_fan_failure(U), supply_mid_mismatch(U),   0.3).
evidence(crah_fan_failure(U), coil_balance_violated(U), 0.3).
requires(crah_fan_failure(U), fan_power_reduced(U)).

%   F2 chilled-water supply loss
evidence(chw_supply_loss(U), chw_flow_low(U),         1.0).
evidence(chw_supply_loss(U), supply_air_hot(U),       0.6).
evidence(chw_supply_loss(U), row_inlet_hot,           0.4) :- component(U, crah).
evidence(chw_supply_loss(U), supply_mid_mismatch(U),  0.2).
requires(chw_supply_loss(U), chw_flow_low(U)).

%   F3 filter clogging
evidence(filter_clogging(U), filter_loaded(U),         1.0).
evidence(filter_clogging(U), coil_balance_violated(U), 0.3).
requires(filter_clogging(U), filter_loaded(U)).

%   F4 hot-air recirculation
evidence(hot_air_recirculation(R), outlet_stratified(R),  1.0).
evidence(hot_air_recirculation(R), inlet_stratified(R),   0.8).
evidence(hot_air_recirculation(R), mid_inlet_deviates(R), 0.3).
requires(hot_air_recirculation(R), outlet_stratified(R)).
requires(hot_air_recirculation(R), inlet_stratified(R)).

%   F5 server fan failure
evidence(server_fan_failure(S), server_fan_stopped(S), 1.0).
evidence(server_fan_failure(S), cpu_hot(S),            0.8).
requires(server_fan_failure(S), server_fan_stopped(S)).

%   F6 to F8 power path
evidence(branch_overload(B), branch_overloaded(B), 1.0).
requires(branch_overload(B), branch_overloaded(B)).

evidence(battery_degradation(B), cell_resistance_high(B), 1.0).
requires(battery_degradation(B), cell_resistance_high(B)).

evidence(ups_on_bypass(U), ups_bypass_mode(U),     1.0).
evidence(ups_on_bypass(U), ups_efficiency_high(U), 0.5).
requires(ups_on_bypass(U), ups_bypass_mode(U)).

%   S1 sensor bias: supply-air sensor
evidence(sensor_bias(t_supply_air, U), supply_sensor_inconsistent(U), 1.0).
evidence(sensor_bias(t_supply_air, U), supply_mid_mismatch(U),        0.5).
evidence(sensor_bias(t_supply_air, U), supply_air_hot(U),             0.3).
evidence(sensor_bias(t_supply_air, U), supply_air_cold(U),            0.3).
evidence(sensor_bias(t_supply_air, U), coil_balance_violated(U),      0.3).
requires(sensor_bias(t_supply_air, U), supply_sensor_inconsistent(U)).

%   S1 sensor bias: middle inlet sensor. A biased middle reading also
%   distorts the top-minus-middle difference in either direction.
evidence(sensor_bias(t_inlet_mid, R), mid_inlet_deviates(R), 1.0).
requires(sensor_bias(t_inlet_mid, R), mid_inlet_deviates(R)).
also_explains(sensor_bias(t_inlet_mid, R), inlet_stratified(R)).
also_explains(sensor_bias(t_inlet_mid, R), top_below_mid(R)).
also_explains(sensor_bias(t_inlet_mid, R), top_reads_high(R)).
masks(sensor_bias(t_inlet_mid, R), inlet_stratified(R)).

%   S1 sensor bias: top inlet sensor. It has no symptom of its own. Its
%   evidence is that the top reading disagrees with the rack exhaust, or
%   reads below the middle sensor, which the mixing model rules out.
evidence(sensor_bias(t_inlet_top, R), top_reads_high(R), 1.0).
evidence(sensor_bias(t_inlet_top, R), top_reads_low(R),  1.0).
evidence(sensor_bias(t_inlet_top, R), top_below_mid(R),  1.0).
also_explains(sensor_bias(t_inlet_top, R), inlet_stratified(R)).
masks(sensor_bias(t_inlet_top, R), inlet_stratified(R)).

%   S2 telemetry dropout
evidence(telemetry_dropout(G), telemetry_stale(G), 1.0).
requires(telemetry_dropout(G), telemetry_stale(G)).

%   explains(?Hypothesis, ?Symptom)
explains(H, S) :- evidence(H, S, _).
explains(H, S) :- also_explains(H, S).
