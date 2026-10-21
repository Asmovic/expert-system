/*  kb/components.pl - structural knowledge about the row.

    component(Id, Type).
    serves(CoolingUnit, Rack).
    rated(Component, Parameter, Value, Unit).
    variable(Name, Description, Unit).   Prolog side of the Stage 3 dictionary.
*/

:- discontiguous rated/4.

component(crah_1, crah).
component(rack_a01, rack).
component(rack_a02, rack).
component(rack_a03, rack).
component(rack_a04, rack).
component(rack_a05, rack).
component(rack_a06, rack).
component(ups_1, ups).
component(battery_1, battery).

serves(crah_1, rack_a01).
serves(crah_1, rack_a02).
serves(crah_1, rack_a03).
serves(crah_1, rack_a04).
serves(crah_1, rack_a05).
serves(crah_1, rack_a06).

%   Ratings. These must match the design constants in simulator/dc_sim.py.
rated(crah_1, fan_power_rated,    5.5,   kw).
rated(crah_1, fan_speed_rated,    100.0, percent).
rated(crah_1, chw_flow_max,       8.0,   kg_per_s).
rated(crah_1, valve_rangeability, 50.0,  ratio).
rated(crah_1, airflow_rated,      7.0,   m3_per_s).
rated(crah_1, filter_k_clean,     2.041, pa_s2_per_m6).
rated(ups_1, efficiency_double_conversion, 0.955, ratio).
rated(battery_1, cells_in_series, 240,   count).
rated(battery_1, r_cell_baseline, 0.65,  mohm).
rated(breaker, current,           32.0,  ampere).

%   Telemetry groups: each reports its own sample_age.
%   Server entities are named <rack>_sNN and rack PDU phases <rack>_lN.

variable(t_inlet_mid,    'rack inlet temperature, middle', degC).
variable(t_inlet_top,    'rack inlet temperature, top',    degC).
variable(t_supply_air,   'CRAH supply-air temperature',    degC).
variable(t_return_air,   'CRAH return-air temperature',    degC).
variable(fan_speed,      'CRAH fan speed command',         percent).
variable(fan_power,      'CRAH fan electrical power',      kw).
variable(t_chw_supply,   'chilled-water supply temperature', degC).
variable(t_chw_return,   'chilled-water return temperature', degC).
variable(valve_position, 'chilled-water valve position',   percent).
variable(m_chw,          'chilled-water mass flow',        kg_per_s).
variable(dp_filter,      'filter differential pressure',   pa).
variable(t_outlet,       'rack outlet temperature',        degC).
variable(t_outlet_top,   'rack outlet temperature, top',   degC).
variable(p_rack,         'rack IT power',                  kw).
variable(cpu_util,       'mean CPU utilisation',           ratio).
variable(i_branch,       'rack PDU phase current',         ampere).
variable(t_cpu,          'CPU temperature',                degC).
variable(server_fan_rpm, 'server fan speed',               rpm).
variable(f_cpu,          'CPU clock frequency',            ghz).
variable(p_ups_in,       'UPS input power',                kw).
variable(p_ups_out,      'UPS output power',               kw).
variable(ups_mode,       'UPS operating mode',             enum).
variable(v_battery,      'battery string float voltage',   volt).
variable(r_cell,         'highest cell internal resistance', mohm).
variable(t_battery,      'battery temperature',            degC).
variable(sample_age,     'telemetry sample age',           s).

%   Rack PDU electrical ratings, used by the rack power balance.
rated(rack_pdu, v_ln,         230.0, volt).
rated(rack_pdu, power_factor, 0.95,  ratio).
