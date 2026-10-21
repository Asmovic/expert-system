# Stage 2: Fault Taxonomy

**Status:** Draft v0.1.

The fault universe has eight physical faults, two instrumentation faults and normal operation:

F = {F1, F2, F3, F4, F5, F6, F7, F8, S1, S2, FN}

Each fault is included because it is a recognised failure mode with a distinct, observable signature inside the system boundary. Physical faults (F) are kept apart from instrumentation faults (S). Test E needs that split, because a sensor fault calls for a different maintenance action than an equipment fault.

## 2.1 Fault table

| ID | Fault | Physical meaning | Typical causes | Observable symptoms | Consequences |
|---|---|---|---|---|---|
| FN | Normal operation | Every variable is within the Stage 1 envelope and every energy balance closes | None | Inlets 18 to 27 °C, supply air at setpoint, fan power matches its speed, water temperature rise near design | None |
| F1 | CRAH supply fan failure | The fan delivers little or no airflow even though a speed is commanded | Motor burnout, broken belt or coupling, drive trip, seized bearing | Fan power far below the affinity-law prediction. All rack inlets hot across the row. Supply air may be *colder* than setpoint because the coil sees little air | Row-wide overheating, CPU throttling, possible server shutdowns |
| F2 | Chilled-water supply loss or stuck valve | The coil receives no useful chilled-water flow | Valve actuator seized closed, plant pump trip, closed isolation valve, air lock in the coil | Valve open, but measured water flow far below what the valve characteristic predicts. Supply air above setpoint. Fan power normal | Row-wide overheating that develops over minutes |
| F3 | CRAH air filter clogging | Dust loading raises the filter pressure drop and cuts airflow at a given fan speed | Missed filter replacement, construction dust | Filter pressure drop above the manufacturer's final value. Fan speed rising to hold airflow. Supply air near normal | Higher fan energy. Leads to F1-like airflow loss if ignored |
| F4 | Hot-air recirculation at a rack | Hot exhaust re-enters the server inlets | Missing blanking panels, open containment doors, unsealed cable openings | Top inlet much hotter than the middle inlet on one or a few racks. Other racks and the CRAH are normal | Local overheating and throttling of the upper servers |
| F5 | Server fan failure | One server loses internal airflow | Fan motor or bearing wear, failed fan controller | Server fan speed near zero, CPU temperature high, CPU frequency reduced. Rack inlet normal | Throttling or shutdown of a single server |
| F6 | Rack PDU branch overload | A branch carries more than its continuous rating | Added servers, workload peaks, unbalanced phase assignment | Branch current above 80% of the breaker rating | Nuisance breaker trip that drops every server on the branch |
| F7 | UPS battery degradation | Battery capacity has faded, so the ride-through time is shorter than designed | Age, high battery temperature, sulphation, dry-out | Cell internal resistance well above its baseline, abnormal float voltage, high battery temperature | Load drops during a utility outage before the generator picks up |
| F8 | UPS on static bypass | The UPS has moved the load to bypass after an internal fault | Inverter or rectifier fault, UPS overload | Mode flag shows bypass. Output power equals input power, so efficiency is about 1.0 | The load gets raw utility power with no battery protection |
| S1 | Temperature sensor bias | A temperature sensor reports a value offset from the truth | Drift, poor placement, loose mounting | One sensor disagrees with its neighbours and with the energy balance, while the physically linked variables are normal | False alarms or a masked real fault |
| S2 | Telemetry dropout | Readings are missing or stale | Monitoring agent crash, network loss, failed controller | Sample age above the limit, or a missing value | Incomplete evidence, so diagnosis confidence must be lowered |

## 2.2 Justification notes

- **F1 versus F2** both overheat the whole row. They are told apart by fan power and by chilled-water flow against valve position, which is why all three variables are in the observation vector. An earlier draft used a near-zero water temperature rise as the F2 signature. The simulator showed this is physically wrong: low flow makes the rise larger, because the little water that flows picks up more heat.
- **F3 versus F1** are different points on the same airflow-loss path. F3 is the gradual cause and F1 is the abrupt one. They need different maintenance actions: replace the filter versus repair the fan.
- **F4** is a rack-level airflow fault. The CRAH is healthy, so the signature is local, not row-wide.
- **F5** is a server-level fault. It shows that the system reasons across three levels: server, rack and row.
- **F6, F7 and F8** cover the power path, so the project is not only a thermal diagnosis.
- **S1 and S2** are needed for Test E and Test G.

## 2.3 Multiple and interacting faults for Test F

| Combination | Interaction |
|---|---|
| F3 and F4 | Reduced airflow makes recirculation at a leaky rack worse |
| F1 with F5-like symptoms | A fan failure throttles many servers. The system must not report six separate server-fan faults |
| F2 at high IT load | Overheating develops faster, so the maintenance priority goes up |
| S1 masking F4 | An inlet sensor reading low hides a real recirculation hot spot |
| F7 with F8 | The load sits on bypass while the battery is weak. This is a compound risk to power continuity |

## 2.4 Fault propagation (causal chain sketch for the Stage 21 figure)

```
F3 filter clogging --> reduced airflow --+
F1 fan failure ------> no airflow -------+--> row inlets hot --> CPU throttling --> service impact
F2 water loss -------> supply air hot ---+
F4 recirculation ----> local inlet hot ---------------------> CPU throttling (upper servers)
F5 server fan -------> server internal hot -----------------> CPU throttling (one server)
F6 branch overload --> breaker trip ------------------------> servers on branch lose power
F7 battery fade -----> short ride-through --+
F8 UPS on bypass ----> no ride-through -----+--> outage during a utility event
```
