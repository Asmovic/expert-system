/*  kb/symptoms.pl - graded symptom definitions shared by the abductive and
    consistency-based modules.

    sdef(Symptom, Case, Value, ThresholdName, Goal, Direction, Noise)
      Goal computes Value for the case and binds the symptom's entity.
      Direction is above or below the threshold.
      Noise gives the standard deviation used to grade the evidence:
        temp(F)  F times the case's estimated temperature-sensor noise
        scaled(S) S at nominal noise, multiplied by the case's noise scale
                  kappa = sigma_T / nominal sigma_T. S is propagated from the
                  datasheet accuracy of the sensors the feature uses.
        power(S) like scaled(S), with the noise scale of the electrical meters
        abs(S)   a fixed standard deviation S in the feature's own unit
      The evidence grade follows Stage 4 Eq. 55. See engine/evidence.pl.

    crisp_sym(Symptom, Case, KnownGoal, PresentGoal)
      A yes/no symptom. It is known when KnownGoal succeeds.

    composite_sym(Symptom, Pos, Neg)
      Evidence is min(e(Pos), 1 - e(Neg)): Pos is present while Neg is absent.

    context_symptom(Symptom)
      Used by the consistency-based module only. Abduction does not have to
      explain it.
*/

:- discontiguous sdef/7.

%   Cooling at row level.
sdef(row_inlet_hot, C, X, t_inlet_rec_max,
     median_inlet_max(C, X), above, temp(1.0)).
sdef(supply_air_hot(U), C, X, t_supply_hot_limit,
     ( component(U, crah), obs(C, t_supply_air, U, X) ), above, temp(1.0)).
sdef(supply_air_cold(U), C, X, t_supply_cold_limit,
     ( component(U, crah), obs(C, t_supply_air, U, X) ), below, temp(1.0)).
sdef(supply_mid_mismatch(U), C, X, neighbour_dev_max,
     ( component(U, crah), supply_air_deviation(C, U, D), X is abs(D) ), above, temp(1.1)).
sdef(fan_power_low(U), C, X, fan_ratio_min,
     ( component(U, crah), fan_power_ratio(C, U, X) ), below, scaled(0.02)).
sdef(fan_power_reduced(U), C, X, fan_ratio_reduced,
     ( component(U, crah), fan_power_ratio(C, U, X) ), below, scaled(0.02)).
sdef(chw_flow_low(U), C, X, chw_flow_ratio_min,
     ( component(U, crah), chw_flow_ratio(C, U, X) ), below, scaled(0.02)).
sdef(filter_loaded(U), C, X, filter_loading_max,
     ( component(U, crah), filter_loading(C, U, X) ), above, scaled(0.05)).
sdef(coil_balance_violated(U), C, X, balance_resid_max,
     ( component(U, crah), coil_balance_residual(C, U, R), X is abs(R) ), above, scaled(0.04)).

%   Rack airflow and inlet sensors. Noise factors follow from Eq. 11 (difference
%   of two sensors, root 2), Eq. 11a (twice a difference, 2 root 2) and Eq. 41.
sdef(inlet_stratified(R), C, X, strat_max,
     ( component(R, rack), inlet_stratification(C, R, X) ), above, temp(1.414)).
sdef(outlet_stratified(R), C, X, strat_out_max,
     ( component(R, rack), outlet_stratification(C, R, X) ), above, temp(2.828)).
sdef(top_below_mid(R), C, X, neighbour_dev_max,
     ( component(R, rack), inlet_stratification(C, R, D), X is -D ), above, temp(1.414)).
sdef(mid_inlet_deviates(R), C, X, neighbour_dev_max,
     ( component(R, rack), mid_inlet_deviation(C, R, D), X is abs(D) ), above, temp(1.1)).

%   Servers.
sdef(server_fan_stopped(S), C, X, server_fan_min,
     obs(C, server_fan_rpm, S, X), below, scaled(100)).
sdef(cpu_hot(S), C, X, cpu_hot_min,
     obs(C, t_cpu, S, X), above, scaled(1.0)).

%   Power path.
sdef(branch_overloaded(B), C, X, branch_loading_max,
     branch_loading(C, B, X), above, power(0.008)).
sdef(rack_power_mismatch(R), C, X, power_resid_max,
     ( component(R, rack), rack_power_residual(C, R, Res), X is abs(Res) ), above, power(0.011)).
sdef(cell_resistance_high(B), C, X, cell_r_ratio_max,
     ( component(B, battery), cell_resistance_ratio(C, B, X) ), above, scaled(0.026)).
sdef(ups_efficiency_high(U), C, X, ups_eff_bypass_min,
     ( component(U, ups), ups_efficiency(C, U, X) ), above, power(0.007)).

%   Telemetry.
sdef(telemetry_stale(G), C, X, sample_age_max,
     obs(C, sample_age, G, X), above, abs(5)).

crisp_sym(ups_bypass_mode(U), C,
          ( component(U, ups), obs(C, ups_mode, U, _) ),
          obs(C, ups_mode, U, bypass)).
crisp_sym(supply_sensor_inconsistent(U), C,
          ( component(U, crah), supply_air_deviation(C, U, _), coil_balance_residual(C, U, _) ),
          prove(cond(C, supply_sensor_inconsistent(U)), _)).

composite_sym(top_reads_high(R), inlet_stratified(R), outlet_stratified(R)).
composite_sym(top_reads_low(R),  outlet_stratified(R), inlet_stratified(R)).

context_symptom(rack_power_mismatch(_)).
