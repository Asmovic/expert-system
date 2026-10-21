/*  kb/rules.pl - diagnostic rules represented as data.

    drule(RuleId, Head, Body, SourceId).
      Head is cond(Case, Condition) or fault(Case, Fault).
      Body is a list of goals. A goal is a derived goal (cond/2, fault/2),
      a fact (obs/4, threshold/2, component/2, serves/2), a calculation
      (see calc_pred/1) or an arithmetic comparison.

    Rules are stored as data rather than plain Prolog clauses so that the
    prover in engine/prover.pl can record which rules fired. That record
    is what the explanation facility reports. Each rule is still a Horn
    clause: Head :- Body.
*/

%   ---- Derived engineering conditions --------------------------------

%   R01  A rack inlet is above the ASHRAE recommended maximum.
drule(r01, cond(C, rack_inlet_hot(R)),
      [ component(R, rack), inlet_max(C, R, T),
        threshold(t_inlet_rec_max, Th), T > Th ],
      ashrae_tc99_2021).

%   R02  Overheating is row-wide: half or more of the racks are hot.
drule(r02, cond(C, row_inlet_hot),
      [ hot_rack_fraction(C, F), threshold(row_hot_fraction, Th), F >= Th ],
      a2_row_fraction).

%   R03  Overheating is localised to rack R.
drule(r03, cond(C, localised_inlet_hot(R)),
      [ cond(C, rack_inlet_hot(R)), hot_rack_fraction(C, F),
        threshold(row_hot_fraction, Th), F < Th ],
      a2_row_fraction).

%   R04  Rack R shows vertical inlet stratification.
drule(r04, cond(C, inlet_stratified(R)),
      [ inlet_stratification(C, R, D), threshold(strat_max, Th), D > Th ],
      a5_stratification).

%   R05  CRAH supply air is above setpoint plus tolerance band.
drule(r05, cond(C, supply_air_hot(U)),
      [ component(U, crah), obs(C, t_supply_air, U, T),
        threshold(t_supply_setpoint, Sp), threshold(t_supply_band, B),
        T > Sp + B ],
      a1_supply_setpoint).

%   R06  CRAH supply air is at or below setpoint plus tolerance band.
drule(r06, cond(C, supply_air_normal(U)),
      [ component(U, crah), obs(C, t_supply_air, U, T),
        threshold(t_supply_setpoint, Sp), threshold(t_supply_band, B),
        T =< Sp + B ],
      a1_supply_setpoint).

%   R07  Fan power is far below the affinity-law prediction.
drule(r07, cond(C, fan_power_low(U)),
      [ component(U, crah), fan_power_ratio(C, U, Rho),
        threshold(fan_ratio_min, Th), Rho < Th ],
      a6_fan_ratio).

%   R08  Fan power is consistent with the commanded speed.
drule(r08, cond(C, fan_power_normal(U)),
      [ component(U, crah), fan_power_ratio(C, U, Rho),
        threshold(fan_ratio_min, Th), Rho >= Th ],
      ashrae_hb_fans).

%   R09  The chilled-water valve is substantially open.
drule(r09, cond(C, valve_open(U)),
      [ obs(C, valve_position, U, V), threshold(valve_open_min, Th), V >= Th ],
      a3_valve_open).

%   R10  Measured chilled-water flow is far below what the valve opening
%        predicts (Stage 4 Eq. 34). Replaces an earlier rule on water
%        temperature rise: low flow makes that rise larger, not smaller.
drule(r10, cond(C, chw_flow_low(U)),
      [ chw_flow_ratio(C, U, Rho), threshold(chw_flow_ratio_min, Th), Rho < Th ],
      a4_chw_flow).

%   ---- Fault rules ---------------------------------------------------

%   R20  F1: row-wide overheating while the fan draws almost no power.
drule(r20, fault(C, crah_fan_failure(U)),
      [ cond(C, row_inlet_hot), cond(C, fan_power_low(U)) ],
      ashrae_hb_fans).

%   R21  F2: hot supply air, open valve, water flow far below the valve
%        prediction, healthy fan.
drule(r21, fault(C, chw_supply_loss(U)),
      [ cond(C, supply_air_hot(U)), cond(C, valve_open(U)),
        cond(C, chw_flow_low(U)), cond(C, fan_power_normal(U)) ],
      a4_chw_flow).

%   ---- Further derived conditions --------------------------------------

%   R11  The rack exhaust is stratified: upper servers run hotter.
drule(r11, cond(C, outlet_stratified(R)),
      [ outlet_stratification(C, R, D), threshold(strat_out_max, Th), D > Th ],
      a7_outlet_strat).

%   R12  The rack exhaust is not stratified.
drule(r12, cond(C, outlet_not_stratified(R)),
      [ outlet_stratification(C, R, D), threshold(strat_out_max, Th), D =< Th ],
      a7_outlet_strat).

%   R13  The rack inlet is not stratified.
drule(r13, cond(C, inlet_not_stratified(R)),
      [ inlet_stratification(C, R, D), threshold(strat_max, Th), D =< Th ],
      a5_stratification).

%   R14  The filter resistance is well above its clean value.
drule(r14, cond(C, filter_loaded(U)),
      [ component(U, crah), filter_loading(C, U, L),
        threshold(filter_loading_max, Th), L > Th ],
      a8_filter).

%   R15  A server fan has stopped.
drule(r15, cond(C, server_fan_stopped(S)),
      [ obs(C, server_fan_rpm, S, W), threshold(server_fan_min, Th), W < Th ],
      a9_server_fan).

%   R16  A CPU is close to its throttling limit.
drule(r16, cond(C, cpu_hot(S)),
      [ obs(C, t_cpu, S, T), threshold(cpu_hot_min, Th), T >= Th ],
      a10_cpu).

%   R17  A rack PDU phase carries more than 80% of its breaker rating.
drule(r17, cond(C, branch_overloaded(B)),
      [ branch_loading(C, B, L), threshold(branch_loading_max, Th), L > Th ],
      nec_continuous).

%   R18  Battery cell resistance is well above its baseline.
drule(r18, cond(C, cell_resistance_high(B)),
      [ component(B, battery), cell_resistance_ratio(C, B, Rho),
        threshold(cell_r_ratio_max, Th), Rho > Th ],
      a11_battery).

%   R19  UPS efficiency is only reachable on static bypass.
drule(r19, cond(C, ups_efficiency_bypass_like(U)),
      [ component(U, ups), ups_efficiency(C, U, Eta),
        threshold(ups_eff_bypass_min, Th), Eta >= Th ],
      a12_ups).

%   R40  A middle inlet sensor disagrees with every other middle inlet.
drule(r40, cond(C, mid_inlet_deviates(R)),
      [ component(R, rack), mid_inlet_deviation(C, R, D),
        threshold(neighbour_dev_max, Th), abs(D) > Th,
        \+ cond(C, inlet_rise_corroborated(R)) ],
      a13_neighbour).

%   R45  Both inlet sensors of rack R deviate from their neighbours in the
%        same direction. Real air does that. One biased sensor does not.
drule(r45, cond(C, inlet_rise_corroborated(R)),
      [ mid_inlet_deviation(C, R, D1), top_inlet_deviation(C, R, D2),
        D1 * D2 > 0, threshold(neighbour_dev_max, Th), abs(D2) > Th ],
      a13_neighbour).

%   R46  Top inlet sensor suspect: it reads colder than the middle inlet.
%        The mixing model (Stage 4 Eq. 18) rules that out physically.
drule(r46, cond(C, top_inlet_sensor_suspect(R)),
      [ component(R, rack), inlet_stratification(C, R, D),
        threshold(neighbour_dev_max, Th), D < -Th,
        \+ cond(C, mid_inlet_deviates(R)) ],
      eq18_mixing).

%   R41  Top inlet sensor suspect: the inlet looks stratified but the
%        exhaust does not confirm it, and the middle sensor is fine.
drule(r41, cond(C, top_inlet_sensor_suspect(R)),
      [ cond(C, inlet_stratified(R)), cond(C, outlet_not_stratified(R)),
        \+ cond(C, mid_inlet_deviates(R)) ],
      a7_outlet_strat).

%   R42  Top inlet sensor suspect: the exhaust is stratified but the
%        inlet reading is not. A low-reading sensor can hide recirculation.
drule(r42, cond(C, top_inlet_sensor_suspect(R)),
      [ cond(C, outlet_stratified(R)), cond(C, inlet_not_stratified(R)),
        \+ cond(C, mid_inlet_deviates(R)) ],
      a7_outlet_strat).

%   R43  The supply-air sensor disagrees with the middle inlets that the
%        supply air feeds, and the coil energy balance does not close.
%        Replacing its reading with the inlet median must close the balance,
%        otherwise the residual has a physical cause such as lost airflow.
drule(r43, cond(C, supply_sensor_inconsistent(U)),
      [ component(U, crah), cond(C, fan_power_nominal(U)),
        supply_air_deviation(C, U, D), threshold(neighbour_dev_max, Th), abs(D) > Th,
        coil_balance_residual(C, U, Res), threshold(balance_resid_max, Tr), abs(Res) > Tr,
        coil_balance_residual_corrected(C, U, Res2), abs(Res2) =< Tr ],
      eq40_uncertainty).

%   R48  Fan power is within 15% of the affinity-law prediction.
drule(r48, cond(C, fan_power_nominal(U)),
      [ component(U, crah), fan_power_ratio(C, U, Rho),
        threshold(fan_ratio_reduced, Th), Rho >= Th ],
      a17_fan_reduced).

%   R49  Fan power is clearly reduced, as with a slipping belt.
drule(r49, cond(C, fan_power_reduced(U)),
      [ component(U, crah), fan_power_ratio(C, U, Rho),
        threshold(fan_ratio_reduced, Th), Rho < Th ],
      a17_fan_reduced).

%   R47  Supply air is well below setpoint.
drule(r47, cond(C, supply_air_cold(U)),
      [ component(U, crah), obs(C, t_supply_air, U, T),
        threshold(t_supply_setpoint, Sp), threshold(t_supply_band, B),
        T < Sp - B ],
      a1_supply_setpoint).

%   R44  A telemetry group has stopped reporting fresh samples.
drule(r44, cond(C, telemetry_stale(G)),
      [ obs(C, sample_age, G, A), threshold(sample_age_max, Th), A > Th ],
      a14_telemetry).

%   ---- Fault rules for hot-air recirculation (F4) ------------------------

%   R36  F1 backup evidence: the row overheats while the supply air is
%        unusually cold, because the coil over-cools the little air left.
%        Used when fan power is missing or ambiguous (Stage 4 Eq. 28).
drule(r36, fault(C, crah_fan_failure(U)),
      [ cond(C, row_inlet_hot), cond(C, supply_air_cold(U)),
        \+ cond(C, supply_sensor_inconsistent(U)) ],
      a1_supply_setpoint).

%   R38  F1 partial failure: fan power clearly reduced while the row
%        overheats.
drule(r38, fault(C, crah_fan_failure(U)),
      [ cond(C, fan_power_reduced(U)), cond(C, row_inlet_hot) ],
      a17_fan_reduced).

%   R37  F2 backup when the flow reading is missing: hot supply air with
%        the valve open and a healthy fan.
drule(r37, fault(C, chw_supply_loss(U)),
      [ cond(C, supply_air_hot(U)), cond(C, valve_open(U)),
        cond(C, fan_power_normal(U)), \+ obs(C, m_chw, U, _),
        \+ cond(C, supply_sensor_inconsistent(U)) ],
      a4_chw_flow).

%   R22  F4: one rack is hot and stratified while its CRAH is healthy,
%        and nothing suggests the top inlet sensor is wrong.
drule(r22, fault(C, hot_air_recirculation(R)),
      [ cond(C, localised_inlet_hot(R)), serves(U, R),
        cond(C, supply_air_normal(U)), cond(C, inlet_stratified(R)),
        \+ cond(C, top_inlet_sensor_suspect(R)) ],
      eu_coc_dc).

%   R23  F4 confirmed by two independent sensor sets: inlet and exhaust
%        are both stratified. Catches recirculation before the inlet
%        exceeds 27 C.
drule(r23, fault(C, hot_air_recirculation(R)),
      [ cond(C, inlet_stratified(R)), cond(C, outlet_stratified(R)),
        serves(U, R), cond(C, supply_air_normal(U)) ],
      eu_coc_dc).

%   R24  F4 from exhaust evidence alone, when the top inlet sensor is
%        suspect because it reads low.
drule(r24, fault(C, hot_air_recirculation(R)),
      [ cond(C, outlet_stratified(R)), cond(C, inlet_not_stratified(R)),
        serves(U, R), cond(C, supply_air_normal(U)) ],
      eu_coc_dc).

%   ---- Fault rules for the other physical faults --------------------------

%   R25  F3: filter resistance high while the fan itself is healthy.
drule(r25, fault(C, filter_clogging(U)),
      [ cond(C, filter_loaded(U)), cond(C, fan_power_normal(U)) ],
      a8_filter).

%   R26  F5: a server fan has stopped and its CPU is near the limit.
drule(r26, fault(C, server_fan_failure(S)),
      [ cond(C, server_fan_stopped(S)), cond(C, cpu_hot(S)) ],
      a9_server_fan).

%   R27  F6: a rack PDU phase is overloaded.
drule(r27, fault(C, branch_overload(B)),
      [ cond(C, branch_overloaded(B)) ],
      nec_continuous).

%   R28  F7: battery cell resistance is high.
drule(r28, fault(C, battery_degradation(B)),
      [ cond(C, cell_resistance_high(B)) ],
      a11_battery).

%   R29  F8: the UPS reports static bypass.
drule(r29, fault(C, ups_on_bypass(U)),
      [ component(U, ups), obs(C, ups_mode, U, bypass) ],
      a12_ups).

%   R35  F8 when the mode reading is missing: efficiency shows bypass.
drule(r35, fault(C, ups_on_bypass(U)),
      [ component(U, ups), \+ obs(C, ups_mode, U, _),
        cond(C, ups_efficiency_bypass_like(U)) ],
      a12_ups).

%   ---- Fault rules for instrumentation faults ----------------------------

%   R50  S1: biased middle inlet sensor.
drule(r50, fault(C, sensor_bias(t_inlet_mid, R)),
      [ cond(C, mid_inlet_deviates(R)) ],
      a13_neighbour).

%   R51  S1: biased top inlet sensor.
drule(r51, fault(C, sensor_bias(t_inlet_top, R)),
      [ cond(C, top_inlet_sensor_suspect(R)) ],
      a7_outlet_strat).

%   R52  S1: biased supply-air sensor.
drule(r52, fault(C, sensor_bias(t_supply_air, U)),
      [ cond(C, supply_sensor_inconsistent(U)) ],
      eq40_uncertainty).

%   R53  S2: telemetry dropout.
drule(r53, fault(C, telemetry_dropout(G)),
      [ cond(C, telemetry_stale(G)) ],
      a14_telemetry).

%   R30 (normal) and R31 (unexplained) are closed-world conclusions and
%   live in engine/deductive.pl because they use negation over all faults.
