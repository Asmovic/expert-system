/*  kb/sources.pl - rule and threshold provenance.

    source(Id, Type, Citation).
      Type is one of: standard, literature, assumption, method.
    Every threshold/4, drule/4 and maintenance/5 fact names a source Id.
    Citations marked "confirm" must be verified before use in the report.
*/

source(ashrae_tc99_2021, standard,
       'ASHRAE TC 9.9 (2021). Thermal guidelines for data processing environments (5th ed.). ASHRAE.').
source(ashrae_hb_fans, literature,
       'ASHRAE (2020). 2020 ASHRAE Handbook - HVAC Systems and Equipment, fans chapter. Fan affinity laws.').
source(eu_coc_dc, standard,
       'Acton et al. (2018). 2018 Best Practice Guidelines for the EU Code of Conduct on Data Centre Energy Efficiency, v9.1.0 (European Commission JRC), practice 5.1.4.').
source(a1_supply_setpoint, assumption,
       'Design assumption: CRAH supply-air setpoint 20 C with a 2 K tolerance band.').
source(a2_row_fraction, assumption,
       'Engineering assumption: overheating at half or more of the racks indicates a row-level cause.').
source(a3_valve_open, assumption,
       'Engineering assumption: a valve open 50% or more should produce a measurable water temperature rise.').
source(a4_chw_flow, assumption,
       'Engineering assumption: measured water flow below 30% of the valve-characteristic prediction means chilled-water supply is lost.').
source(a5_stratification, assumption,
       'Engineering assumption: a top-to-middle inlet difference above 3 K indicates hot-air recirculation.').
source(a6_fan_ratio, assumption,
       'Engineering assumption: fan power below 50% of the affinity-law prediction means the fan is not moving air.').
source(closed_world, method,
       'Closed-world assumption: normal operation is concluded when no fault rule fires and all inlets are within the envelope.').
source(nec_continuous, standard,
       'NFPA (2023). NFPA 70 National Electrical Code, continuous-load rule: 80% of breaker rating. Local codes may differ.').
source(a7_outlet_strat, assumption,
       'Engineering assumption: a top-to-bottom outlet difference above 3.5 K confirms recirculation. Normal racks stay below 3 K.').
source(a8_filter, assumption,
       'Engineering assumption: filter resistance 1.7 times its clean value calls for replacement (check against manufacturer final-resistance data).').
source(a9_server_fan, assumption,
       'Engineering assumption: a server fan below 1000 rpm has failed. The controller never runs it below about 5400 rpm.').
source(a10_cpu, assumption,
       'Engineering assumption: CPU temperature of 85 C or more, 10 K below the 95 C throttling limit, confirms lost server cooling.').
source(a11_battery, assumption,
       'Engineering assumption: cell internal resistance 30% above its baseline indicates degradation (check against IEEE Std 1188 and manufacturer guidance).').
source(a12_ups, assumption,
       'Engineering assumption: UPS efficiency of 0.98 or more is only reached on static bypass. Double conversion runs at about 0.95.').
source(a13_neighbour, assumption,
       'Engineering assumption: a temperature sensor more than 2 K from the median of sensors that see the same air is suspect (Stage 4 Eq. 41).').
source(eq40_uncertainty, method,
       'Residual threshold from uncertainty propagation, Stage 4 Eqs. 39 and 40, with a coverage factor of about 3.').
source(a14_telemetry, assumption,
       'Engineering assumption: a sample older than 60 s is stale, given a polling interval of about 30 s.').
source(eq18_mixing, method,
       'Physical constraint from the mixing model, Stage 4 Eq. 18: the top inlet cannot be colder than the middle inlet.').
source(a15_power_balance, assumption,
       'Engineering assumption: metered rack power and the sum of its six phase currents agree within 10% when both meters are healthy (Stage 4 Eq. 42).').
source(a16_noise, assumption,
       'Engineering assumption: temperature-sensor noise is at least 0.15 K (typical datasheet accuracy). Higher noise is estimated from the spread of middle inlets, which all see the same supply air.').
source(a17_fan_reduced, assumption,
       'Engineering assumption: fan power below 85% of the affinity-law prediction shows a partial failure such as belt slip. Healthy fans stay within 5%.').
