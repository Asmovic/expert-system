# Stage 1: System Definition

**System:** Cooling and power infrastructure for one row of a data centre.
**Status:** Draft v0.1. Values marked *[assumption]* or *[verify]* still need a source before they go into the report.

## 1.1 Purpose and function

The system keeps IT equipment inside its thermal envelope and gives it continuous, conditioned electrical power. In practice it does two things:

1. **Cooling.** It removes the heat the servers dissipate, so every server inlet stays within the ASHRAE recommended temperature range.
2. **Power.** It delivers clean power to every server, with backup that lasts long enough to ride through a utility outage.

## 1.2 System boundary

To keep the project tractable, the scope is **one row of six racks (A01 to A06)** in a hot-aisle containment layout. The row is served by:

- one chilled-water **computer-room air handler** (CRAH-1);
- one **double-conversion UPS** (UPS-1) with a valve-regulated lead-acid (VRLA) battery string;
- one **row power distribution unit** (PDU-1); and
- one **rack PDU** (rPDU) per rack, with branch circuit breakers.

| Inside the boundary | Outside the boundary (treated as inputs) |
|---|---|
| Servers, server fans, racks, blanking panels, containment | Chiller plant and cooling towers |
| CRAH-1: supply fan with drive, cooling coil, control valve, air filter | Utility supply and standby generator |
| UPS-1, battery string, PDU-1, rPDUs | Building management network |
| Every sensor listed in Stage 3 | Humidity control (excluded, see limitations) |

## 1.3 Major components

| ID | Component | Function |
|---|---|---|
| C1 | Servers, 20 per rack | Run the IT workload and convert electrical power into heat |
| C2 | Server fans | Pull cold-aisle air through each server |
| C3 | Racks with blanking panels | Hold the servers and stop hot exhaust from returning to the server inlets |
| C4 | Hot-aisle containment | Separates the hot exhaust from the cold supply air |
| C5 | CRAH-1 supply fan with variable-frequency drive | Moves air through the coil and into the cold aisle |
| C6 | CRAH-1 cooling coil | Transfers heat from the air into the chilled water |
| C7 | CRAH-1 chilled-water control valve | Modulates water flow to hold the supply-air setpoint |
| C8 | CRAH-1 air filter | Removes particulates, which adds pressure drop |
| C9 | UPS-1 rectifier, inverter and static bypass | Double conversion from AC to DC and back to AC. Bypass is used on fault |
| C10 | VRLA battery string | Stores energy for ride-through during an outage |
| C11 | PDU-1 | Distributes three-phase power to the row |
| C12 | Rack PDUs with branch breakers | Distribute power inside each rack and protect each branch |

## 1.4 Inputs and outputs

| Inputs | Outputs |
|---|---|
| Utility AC power at three phases, 400 V *[verify for the local grid]* | Conditioned AC power to the servers |
| Chilled water at a supply temperature T_ws | Warmed chilled water at a return temperature T_wr |
| IT workload as CPU utilisation u | Heat rejected to the chilled water |
| Setpoints for supply air and fan speed | Telemetry: temperatures, power, currents, status flags |

## 1.5 Energy and material flows

- **Electrical path.** Utility, then UPS-1, then PDU-1, then rPDU, then the servers. Almost all of the electrical energy the servers draw ends up as heat.
- **Air path.** CRAH-1 supply, then the cold aisle, then the server inlets, then the server exhausts, then the hot aisle, then CRAH-1 return, through the filter and the coil.
- **Water path.** Chilled water from the plant passes through the valve and the coil, then returns to the plant.
- **Heat path.** Server heat is carried by the air, transferred to the chilled water at the coil, and leaves the boundary. UPS and PDU losses add to the room heat load.

In steady state, the heat removed by the air must equal the IT power plus the distribution losses. The same heat must also equal what the water absorbs. **These two balances provide analytical redundancy.** They are the main tool for telling sensor faults apart from equipment faults in Stage 8.

## 1.6 Operating conditions

| Condition | Low | Nominal | High |
|---|---|---|---|
| Average CPU utilisation | 10% | 50% | 90% |
| Row IT load from Stage 4 equations 1 to 3 *[assumption]* | 54 kW | 78 kW | 102 kW |
| CRAH fan speed | 40% | 70% | 100% |

## 1.7 Control variables

- The CRAH supply-air temperature setpoint is held by modulating the chilled-water valve.
- CRAH fan speed is controlled to meet airflow demand.
- Server fan speed is set by each server's own baseboard controller from its internal temperatures.
- The UPS operating mode is either double conversion, on battery, or static bypass.

## 1.8 Measurable variables

See Stage 3 for the full dictionary. In summary, the measurable variables are:

- rack inlet temperatures at two heights, and rack outlet temperatures;
- CRAH supply and return air temperatures, fan speed, fan power and filter pressure drop;
- chilled-water supply and return temperatures, and valve position;
- rPDU branch currents and rack power;
- server CPU utilisation, CPU temperature, CPU frequency and fan speed;
- UPS input and output power, mode, battery voltage, cell internal resistance and battery temperature; and
- the age of every telemetry sample.

## 1.9 Governing principles

| Domain | Principle | Use in diagnosis |
|---|---|---|
| Heat transfer | Sensible heat: Q equals mass flow times specific heat times temperature rise | Air-side and water-side energy balances |
| Thermodynamics | First law over the row: heat removed equals IT power plus losses | Cross-check between independent sensors |
| Fluid mechanics | Fan affinity laws: flow scales with speed, pressure with speed squared, power with speed cubed | Expected fan power at a given speed |
| Fluid mechanics | Filter pressure drop grows with loading at constant flow | Detecting filter clogging |
| Electrical | Three-phase power equals root-three times line voltage, current and power factor | Rack power and branch loading |
| Electrical | Continuous load limited to 80% of the breaker rating *[verify against NEC 210.20 or the local code]* | Branch overload |
| Electrochemistry | Battery internal resistance rises as capacity fades | Battery degradation |
| Computing | Server power grows roughly linearly with CPU utilisation (Fan et al., 2007) | Expected IT heat from utilisation |
| Computing | A CPU throttles its clock when it reaches its junction temperature limit | Seeing the thermal consequences of a fault |

## 1.10 Normal operating envelope

| Variable | Normal range | Source |
|---|---|---|
| Rack inlet temperature | 18 to 27 °C. The allowable range for class A1 is 15 to 32 °C | ASHRAE TC 9.9 (2021) |
| Inlet stratification, top minus middle | below 3 K | *[assumption]* |
| CRAH supply-air temperature | 20 °C ± 2 K | *[assumption]* design setpoint |
| Chilled-water temperature rise | about 6 K at design load | *[assumption, verify]* |
| Fan power ratio, measured over affinity-law prediction | 0.8 to 1.2 | *[assumption]* |
| Filter pressure drop | below the manufacturer's final value | *[verify]* manufacturer data |
| Branch current | at most 80% of breaker rating | *[verify]* electrical code |
| UPS efficiency in double conversion | about 0.94 to 0.97 | *[verify]* manufacturer data |
| VRLA float voltage | about 2.25 to 2.30 V per cell at 25 °C | *[verify]* manufacturer data |
| Battery temperature | about 20 to 25 °C | *[verify]* IEEE 1188 |
| Cell internal resistance | within a set percentage of the commissioning baseline | *[verify]* IEEE 1188 or manufacturer |
| Telemetry sample age | below 60 s | *[assumption]* |

**Abnormal operation** is any sustained departure from this envelope. It is also any break in the energy balances in section 1.5 that exceeds the combined sensor uncertainty.

## 1.11 Scope limitations

- Humidity and dew-point control are excluded to keep the model sensible-heat only.
- The chiller plant and generator are treated as boundary inputs and are not diagnosed.
- Only steady-state behaviour is modelled. Transients are only flagged by the telemetry-age checks.
- Every test case is synthetic, generated by the simulator from the models above. No case is presented as a measurement from a real plant.
