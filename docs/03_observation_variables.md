# Stage 3: Observation Variables

**Status:** Draft v0.1.

The observation vector is x = [x1, x2, ..., x26]^T. Every variable used in an equation, rule or Prolog predicate must appear in this table. The "Prolog name" column is the name used in `obs(Case, Variable, Entity, Value)` facts.

## 3.1 Measured variables

| Symbol | Variable | Unit | Sensor or source | Prolog name | Diagnostic relevance |
|---|---|---|---|---|---|
| x1 | Rack inlet temperature, middle height | °C | Rack front probe | `t_inlet_mid` | Compared with the ASHRAE envelope |
| x2 | Rack inlet temperature, top height | °C | Rack front probe | `t_inlet_top` | Stratification shows recirculation (F4) |
| x3 | Rack outlet temperature | °C | Rack rear probe | `t_outlet` | Rack temperature rise and air-side balance |
| x4 | CRAH supply-air temperature | °C | CRAH discharge sensor | `t_supply_air` | Separates F2 from F1 |
| x5 | CRAH return-air temperature | °C | CRAH return sensor | `t_return_air` | Air-side energy balance |
| x6 | CRAH fan speed command | % | Drive feedback | `fan_speed` | Input to the affinity-law prediction |
| x7 | CRAH fan electrical power | kW | Drive power meter | `fan_power` | Low ratio to prediction signals F1 |
| x8 | Filter differential pressure | Pa | Differential pressure transmitter | `dp_filter` | F3 |
| x9 | Chilled-water supply temperature | °C | Pipe sensor | `t_chw_supply` | Water-side balance |
| x10 | Chilled-water return temperature | °C | Pipe sensor | `t_chw_return` | Water-side balance, F2 |
| x11 | Chilled-water valve position | % | Actuator feedback | `valve_position` | Open valve with no temperature rise signals F2 |
| x12 | rPDU branch current | A | rPDU metering | `i_branch` | F6 |
| x13 | Rack IT power | kW | rPDU metering | `p_rack` | Energy balance, expected heat |
| x14 | Server CPU utilisation | – | Operating system or hypervisor | `cpu_util` | Expected server power |
| x15 | Server CPU temperature | °C | Baseboard management controller | `t_cpu` | F5, throttling |
| x16 | Server CPU frequency | GHz | Operating system | `f_cpu` | Throttling evidence |
| x17 | Server fan speed | rpm | Baseboard management controller | `server_fan_rpm` | F5 |
| x18 | UPS input power | kW | UPS meter | `p_ups_in` | UPS efficiency, F8 |
| x19 | UPS output power | kW | UPS meter | `p_ups_out` | UPS efficiency, F8 |
| x20 | UPS operating mode | enum | UPS status | `ups_mode` | F8 |
| x21 | Battery string float voltage | V | Battery monitor | `v_battery` | F7 |
| x22 | Cell internal resistance | mΩ | Battery monitor | `r_cell` | F7 |
| x23 | Battery temperature | °C | Battery monitor | `t_battery` | F7 and ageing |
| x24 | Telemetry sample age | s | Monitoring pipeline | `sample_age` | S2 |
| x25 | Chilled-water mass flow | kg/s | Flow meter on the coil branch | `m_chw` | Water-side heat balance, Stage 4 equation 30 |
| x26 | Rack outlet temperature at the top | °C | Rack rear probe | `t_outlet_top` | Recirculation fraction, Stage 4 equation 19 |

## 3.2 Design constants and reference values

| Symbol | Meaning | Value | Unit | Source |
|---|---|---|---|---|
| P_f,rated | CRAH fan rated power at 100% speed | 5.5 | kW | *[assumption]* nameplate |
| N_rated | Rated fan speed | 100 | % | Definition |
| T_sp | Supply-air setpoint | 20.0 | °C | *[assumption]* |
| ΔT_band | Supply-air tolerance band | 2.0 | K | *[assumption]* |
| T_rec,max | Recommended maximum inlet temperature | 27.0 | °C | ASHRAE TC 9.9 (2021) |
| T_rec,min | Recommended minimum inlet temperature | 18.0 | °C | ASHRAE TC 9.9 (2021) |
| T_all,max | Allowable maximum inlet temperature, class A1 | 32.0 | °C | ASHRAE TC 9.9 (2021) |
| c_p,a | Specific heat of air | 1.006 | kJ/(kg·K) | Standard property |
| c_p,w | Specific heat of water | 4.186 | kJ/(kg·K) | Standard property |
| ρ_a | Air density | 1.2 | kg/m³ | Standard property near 20 °C |

## 3.3 Derived quantities, previewing Stage 4

| Symbol | Meaning | Prolog predicate |
|---|---|---|
| T_in,max(r) | max(x1, x2) for rack r | `inlet_max/3` |
| ΔT_strat(r) | x2 − x1 for rack r | `inlet_stratification/3` |
| φ_hot | Fraction of racks with T_in,max above T_rec,max | `hot_rack_fraction/2` |
| P_f,exp | P_f,rated · (x6 / N_rated)³, from the fan affinity law | `expected_fan_power/3` |
| ρ_f | x7 / P_f,exp, the fan power ratio | `fan_power_ratio/3` |
| ΔT_w | x10 − x9, the chilled-water temperature rise | `chw_delta_t/3` |
| η_UPS | x19 / x18 | planned |
| SHI, RHI | Supply and return heat indices (Sharma et al., 2002) | planned |
| RCI_HI, RCI_LO | Rack cooling indices (Herrlin, 2005) | planned |
| r_E | Air-side minus electrical energy balance residual | planned |
