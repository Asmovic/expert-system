/*  data/cases.pl - test cases.

    ALL CASES IN THIS FILE ARE SYNTHETIC. They were hand-constructed to
    exercise the prototype and are not measurements from a real facility.
    They are the smoke-test set. The evaluation set is generated_cases.pl.

    case(Id, Description, Origin).      Origin: synthetic | measured
    expected(Id, Faults).               ground-truth label
    obs(Id, Variable, Entity, Value).   see docs/03_observation_variables.md
*/

:- multifile case/3, case_category/2, case_split/2, expected/2, obs/4.

case(n01, 'Normal operation at nominal load',  synthetic).
case(f01, 'CRAH supply fan failure',           synthetic).
case(f02, 'Chilled-water supply loss',         synthetic).
case(f03, 'Hot-air recirculation at rack A04', synthetic).

case_category(n01, smoke).
case_category(f01, smoke).
case_category(f02, smoke).
case_category(f03, smoke).

case_split(n01, smoke).
case_split(f01, smoke).
case_split(f02, smoke).
case_split(f03, smoke).

expected(n01, [normal]).
expected(f01, [crah_fan_failure(crah_1)]).
expected(f02, [chw_supply_loss(crah_1)]).
expected(f03, [hot_air_recirculation(rack_a04)]).

%   ---- n01: normal ---------------------------------------------------
obs(n01, t_supply_air,   crah_1, 20.1).
obs(n01, t_return_air,   crah_1, 33.5).
obs(n01, fan_speed,      crah_1, 70.0).
obs(n01, fan_power,      crah_1, 1.85).
obs(n01, valve_position, crah_1, 76.0).
obs(n01, m_chw,          crah_1, 3.18).
obs(n01, t_chw_supply,   crah_1, 10.0).
obs(n01, t_chw_return,   crah_1, 16.0).
obs(n01, t_inlet_mid, rack_a01, 21.0).  obs(n01, t_inlet_top, rack_a01, 22.5).
obs(n01, t_inlet_mid, rack_a02, 21.4).  obs(n01, t_inlet_top, rack_a02, 22.8).
obs(n01, t_inlet_mid, rack_a03, 20.8).  obs(n01, t_inlet_top, rack_a03, 22.1).
obs(n01, t_inlet_mid, rack_a04, 21.6).  obs(n01, t_inlet_top, rack_a04, 23.0).
obs(n01, t_inlet_mid, rack_a05, 21.2).  obs(n01, t_inlet_top, rack_a05, 22.6).
obs(n01, t_inlet_mid, rack_a06, 21.0).  obs(n01, t_inlet_top, rack_a06, 22.4).

%   ---- f01: CRAH fan failure ------------------------------------------
%   Fan commanded to 70% but drawing 0.12 kW against about 1.89 kW
%   predicted. The coil sees little air, so supply air is cold while
%   every rack overheats.
obs(f01, t_supply_air,   crah_1, 17.6).
obs(f01, t_return_air,   crah_1, 35.0).
obs(f01, fan_speed,      crah_1, 70.0).
obs(f01, fan_power,      crah_1, 0.12).
obs(f01, valve_position, crah_1, 40.0).
obs(f01, m_chw,          crah_1, 0.77).
obs(f01, t_chw_supply,   crah_1, 10.0).
obs(f01, t_chw_return,   crah_1, 12.5).
obs(f01, t_inlet_mid, rack_a01, 29.5).  obs(f01, t_inlet_top, rack_a01, 31.0).
obs(f01, t_inlet_mid, rack_a02, 30.2).  obs(f01, t_inlet_top, rack_a02, 31.9).
obs(f01, t_inlet_mid, rack_a03, 30.8).  obs(f01, t_inlet_top, rack_a03, 32.4).
obs(f01, t_inlet_mid, rack_a04, 30.4).  obs(f01, t_inlet_top, rack_a04, 32.0).
obs(f01, t_inlet_mid, rack_a05, 29.9).  obs(f01, t_inlet_top, rack_a05, 31.5).
obs(f01, t_inlet_mid, rack_a06, 29.1).  obs(f01, t_inlet_top, rack_a06, 30.6).

%   ---- f02: chilled-water supply loss ---------------------------------
%   Valve fully open, but water flow is 0.9 kg/s against 8 kg/s predicted
%   by the valve characteristic. The little water that flows warms by 20.7 K.
%   The fan is healthy.
obs(f02, t_supply_air,   crah_1, 27.4).
obs(f02, t_return_air,   crah_1, 40.5).
obs(f02, fan_speed,      crah_1, 70.0).
obs(f02, fan_power,      crah_1, 1.90).
obs(f02, valve_position, crah_1, 100.0).
obs(f02, m_chw,          crah_1, 0.9).
obs(f02, t_chw_supply,   crah_1, 10.2).
obs(f02, t_chw_return,   crah_1, 30.9).
obs(f02, t_inlet_mid, rack_a01, 27.8).  obs(f02, t_inlet_top, rack_a01, 29.0).
obs(f02, t_inlet_mid, rack_a02, 28.3).  obs(f02, t_inlet_top, rack_a02, 29.6).
obs(f02, t_inlet_mid, rack_a03, 28.6).  obs(f02, t_inlet_top, rack_a03, 29.9).
obs(f02, t_inlet_mid, rack_a04, 28.4).  obs(f02, t_inlet_top, rack_a04, 29.7).
obs(f02, t_inlet_mid, rack_a05, 28.0).  obs(f02, t_inlet_top, rack_a05, 29.2).
obs(f02, t_inlet_mid, rack_a06, 27.6).  obs(f02, t_inlet_top, rack_a06, 28.8).

%   ---- f03: hot-air recirculation at rack A04 --------------------------
%   CRAH healthy. Rack A04 top inlet 7.4 K hotter than its middle inlet.
obs(f03, t_supply_air,   crah_1, 20.1).
obs(f03, t_return_air,   crah_1, 33.8).
obs(f03, fan_speed,      crah_1, 70.0).
obs(f03, fan_power,      crah_1, 1.86).
obs(f03, valve_position, crah_1, 76.0).
obs(f03, m_chw,          crah_1, 3.2).
obs(f03, t_chw_supply,   crah_1, 10.0).
obs(f03, t_chw_return,   crah_1, 16.1).
obs(f03, t_inlet_mid, rack_a01, 21.1).  obs(f03, t_inlet_top, rack_a01, 22.6).
obs(f03, t_inlet_mid, rack_a02, 21.3).  obs(f03, t_inlet_top, rack_a02, 22.9).
obs(f03, t_inlet_mid, rack_a03, 20.9).  obs(f03, t_inlet_top, rack_a03, 22.3).
obs(f03, t_inlet_mid, rack_a04, 23.2).  obs(f03, t_inlet_top, rack_a04, 30.6).
obs(f03, t_inlet_mid, rack_a05, 21.4).  obs(f03, t_inlet_top, rack_a05, 22.9).
obs(f03, t_inlet_mid, rack_a06, 21.0).  obs(f03, t_inlet_top, rack_a06, 22.5).
