/*  kb/thresholds.pl - reference values used by the diagnostic rules.

    threshold(Name, Value, Unit, SourceId).
*/

threshold(t_inlet_rec_max,   27.0, degC,    ashrae_tc99_2021).
threshold(t_inlet_rec_min,   18.0, degC,    ashrae_tc99_2021).
threshold(t_supply_setpoint, 20.0, degC,    a1_supply_setpoint).
threshold(t_supply_band,      2.0, kelvin,  a1_supply_setpoint).
threshold(row_hot_fraction,   0.5, ratio,   a2_row_fraction).
threshold(valve_open_min,    50.0, percent, a3_valve_open).
threshold(chw_flow_ratio_min, 0.3, ratio,   a4_chw_flow).
threshold(strat_max,          3.0, kelvin,  a5_stratification).
threshold(fan_ratio_min,      0.5, ratio,   a6_fan_ratio).


%   Added with the rules for F3, F5 to F8, S1 and S2.
threshold(strat_out_max,       3.5,    kelvin,  a7_outlet_strat).
threshold(filter_loading_max,  1.7,    ratio,   a8_filter).
threshold(server_fan_min,      1000.0, rpm,     a9_server_fan).
threshold(cpu_hot_min,         85.0,   degC,    a10_cpu).
threshold(branch_loading_max,  0.8,    ratio,   nec_continuous).
threshold(cell_r_ratio_max,    1.3,    ratio,   a11_battery).
threshold(ups_eff_bypass_min,  0.98,   ratio,   a12_ups).
threshold(neighbour_dev_max,   2.0,    kelvin,  a13_neighbour).
threshold(balance_resid_max,   0.2,    ratio,   eq40_uncertainty).
threshold(sample_age_max,      60.0,   s,       a14_telemetry).

%   Added with the abductive and consistency-based modules.
threshold(t_supply_hot_limit,  22.0,   degC,    a1_supply_setpoint).
threshold(fan_ratio_reduced,   0.85,   ratio,   a17_fan_reduced).
threshold(t_supply_cold_limit, 18.0,   degC,    a1_supply_setpoint).
threshold(power_resid_max,     0.1,    ratio,   a15_power_balance).
threshold(sensor_noise_floor,  0.15,   kelvin,  a16_noise).

%   threshold(+Name, -Value): short form used inside rule bodies and symptom
%   definitions. The sensitivity analysis (tests/sensitivity.pl) can shift a
%   threshold by an offset or scale it by a factor. Normally neither is set.
:- dynamic thr_offset/2, thr_factor/2.

threshold(Name, Value) :-
    threshold(Name, V0, _, _),
    (   thr_offset(Name, D) -> Value is V0 + D
    ;   thr_factor(Name, F) -> Value is V0 * F
    ;   Value = V0
    ).
