/*  kb/arr.pl - knowledge for consistency-based diagnosis.

    arr(Id, Symptom, Support)
      An analytical redundancy relation (Cordier et al., 2004). It holds
      when every component in Support behaves normally. It is violated
      when Symptom is clearly present, and then Support is a conflict set.
      Sensors are components, written sensor(Variable, Entity).

    fm(Component, ArrId)
      Fault model (Struss and Dressler, 1989). If Component is abnormal,
      relation ArrId must be violated too. When that relation clearly holds,
      the component is exonerated, unless another abnormal component in the
      relation's support masks the effect.

    comp_label(Component, FaultLabel)
      Maps an abnormal component to the fault label used everywhere else.
*/

:- discontiguous arr/3, fm/2.

%   Cooling unit
arr(a_fan(U), fan_power_reduced(U),
    [crah_fan(U), sensor(fan_power, U), sensor(fan_speed, U)]).
arr(a_valve(U), chw_flow_low(U),
    [chw_supply(U), sensor(m_chw, U), sensor(valve_position, U)]).
arr(a_filter(U), filter_loaded(U),
    [crah_filter(U), sensor(dp_filter, U), sensor(fan_speed, U)]).
arr(a_balance(U), coil_balance_violated(U),
    [crah_fan(U), crah_filter(U), sensor(t_supply_air, U), sensor(t_return_air, U),
     sensor(m_chw, U), sensor(t_chw_supply, U), sensor(t_chw_return, U), sensor(fan_speed, U)]).
arr(a_supply_hot(U), supply_air_hot(U),
    [chw_supply(U), sensor(t_supply_air, U)]).
arr(a_supply_cold(U), supply_air_cold(U),
    [crah_fan(U), sensor(t_supply_air, U)]).
arr(a_supply_vs_mid(U), supply_mid_mismatch(U),
    [sensor(t_supply_air, U), crah_fan(U), crah_filter(U), chw_supply(U)]).
arr(a_row(U), row_inlet_hot,
    [crah_fan(U), crah_filter(U), chw_supply(U)]) :- component(U, crah).

%   Racks
arr(a_in_strat(R), inlet_stratified(R),
    [rack_seal(R), sensor(t_inlet_top, R), sensor(t_inlet_mid, R)]).
arr(a_out_strat(R), outlet_stratified(R),
    [rack_seal(R), sensor(t_outlet_top, R), sensor(t_outlet, R)]).
arr(a_top_mid(R), top_below_mid(R),
    [sensor(t_inlet_top, R), sensor(t_inlet_mid, R)]).
arr(a_mid_nb(R), mid_inlet_deviates(R),
    [sensor(t_inlet_mid, R)]).
arr(a_rack_power(R), rack_power_mismatch(R), [sensor(p_rack, R) | Phases]) :-
    component(R, rack),
    findall(sensor(i_branch, B), phase_of_rack(R, B), Phases).

%   Servers
arr(a_srv_fan(S), server_fan_stopped(S),
    [server_fan(S), sensor(server_fan_rpm, S)]).
arr(a_cpu(S), cpu_hot(S),
    [server_fan(S), sensor(t_cpu, S)]).

%   Power path
arr(a_branch(B), branch_overloaded(B),
    [branch(B), sensor(i_branch, B)]).
arr(a_cell(B), cell_resistance_high(B),
    [battery_string(B), sensor(r_cell, B)]).
arr(a_mode(U), ups_bypass_mode(U),
    [ups_inverter(U)]).
arr(a_eff(U), ups_efficiency_high(U),
    [ups_inverter(U), sensor(p_ups_in, U), sensor(p_ups_out, U)]).

%   Telemetry
arr(a_age(G), telemetry_stale(G),
    [telemetry(G)]).

%   Fault models
fm(crah_fan(U), a_fan(U)).
fm(chw_supply(U), a_valve(U)).
fm(crah_filter(U), a_filter(U)).
fm(rack_seal(R), a_out_strat(R)).
fm(rack_seal(R), a_in_strat(R)).
fm(sensor(t_inlet_mid, R), a_mid_nb(R)).
fm(sensor(t_supply_air, U), a_supply_vs_mid(U)).
fm(server_fan(S), a_srv_fan(S)).
fm(branch(B), a_branch(B)).
fm(sensor(i_branch, B), a_rack_power(R)) :- phase_of_rack(R, B).
fm(sensor(p_rack, R), a_rack_power(R)).
fm(battery_string(B), a_cell(B)).
fm(ups_inverter(U), a_mode(U)).
fm(telemetry(G), a_age(G)).

%   phase_of_rack(?Rack, ?Phase): rack PDU phase circuits, feeds a and b.
phase_of_rack(R, B) :-
    component(R, rack),
    member(F, [a, b]),
    member(P, [1, 2, 3]),
    format(atom(B), "~w_~w_l~w", [R, F, P]).

comp_label(crah_fan(U),       crah_fan_failure(U)).
comp_label(chw_supply(U),     chw_supply_loss(U)).
comp_label(crah_filter(U),    filter_clogging(U)).
comp_label(rack_seal(R),      hot_air_recirculation(R)).
comp_label(server_fan(S),     server_fan_failure(S)).
comp_label(branch(B),         branch_overload(B)).
comp_label(battery_string(B), battery_degradation(B)).
comp_label(ups_inverter(U),   ups_on_bypass(U)).
comp_label(telemetry(G),      telemetry_dropout(G)).
comp_label(sensor(V, E),      sensor_bias(V, E)).
