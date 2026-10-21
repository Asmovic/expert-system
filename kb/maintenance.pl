/*  kb/maintenance.pl - corrective-maintenance knowledge.

    maintenance(FaultType, Priority, Actions, Rationale, SourceId).
      FaultType is the functor of the fault term, so crah_fan_failure
      covers crah_fan_failure(crah_1).
      Priority is one of: urgent, high, routine.
*/

maintenance(crah_fan_failure, urgent,
    [ 'Check the fan drive fault log and the motor current',
      'Inspect the motor, belt or coupling, and bearings; repair or replace the failed part',
      'Bring redundant cooling online or raise the output of neighbouring units during the repair',
      'After repair, confirm fan power matches the affinity-law prediction and rack inlets fall below 27 C' ],
    'A fan that draws far less power than its commanded speed predicts is not moving air, so the whole row loses cooling airflow.',
    ashrae_hb_fans).

maintenance(chw_supply_loss, urgent,
    [ 'Confirm chilled-water plant status: pumps running and isolation valves open',
      'Compare commanded and actual valve stroke; repair or replace a seized actuator',
      'Vent trapped air from the coil',
      'Confirm water flow matches the valve position and supply air is back at setpoint' ],
    'An open valve passing far less water than its characteristic predicts means the coil cannot absorb the heat load, so the supply air warms up.',
    a4_chw_flow).

maintenance(hot_air_recirculation, high,
    [ 'Inspect the rack for missing blanking panels and unsealed cable openings',
      'Check containment doors and roof panels for gaps',
      'Install blanking panels and seal the openings',
      'Re-measure top and middle inlet temperatures to confirm the difference is below 3 K' ],
    'Hot exhaust air re-entering the front of the rack heats the upper servers while the cooling unit itself is healthy.',
    eu_coc_dc).

maintenance(normal, routine,
    [ 'No corrective action. Continue routine monitoring.' ],
    'All monitored conditions are within the operating envelope.',
    ashrae_tc99_2021).

maintenance(unexplained_abnormality, high,
    [ 'Verify the affected sensors before acting',
      'Escalate to a technician for manual investigation' ],
    'The knowledge base has no rule that explains the observed abnormality.',
    closed_world).

maintenance(filter_clogging, high,
    [ 'Replace the CRAH air filters',
      'Check the filter differential pressure gauge against a reference',
      'Review the filter replacement interval and recent dust sources such as building work',
      'After replacement, confirm filter pressure drop and fan speed are back to normal' ],
    'High filter resistance cuts airflow at a given fan speed, so the fan works harder and cooling margin shrinks.',
    a8_filter).

maintenance(server_fan_failure, high,
    [ 'Check the server management controller event log for the failed fan module',
      'Migrate or reduce the workload on the server until it is repaired',
      'Hot-swap the failed fan module',
      'Confirm CPU temperature and clock frequency return to normal' ],
    'A server with a stopped fan loses internal airflow, so its CPU throttles and may shut down.',
    a9_server_fan).

maintenance(branch_overload, urgent,
    [ 'Identify the servers on the overloaded phase from the rack power records',
      'Rebalance server power supplies across the three phases',
      'Check for equipment added without a capacity review',
      'Confirm every phase is below 80% of its breaker rating' ],
    'A phase above its continuous rating can trip its breaker and drop every server on that circuit.',
    nec_continuous).

maintenance(battery_degradation, high,
    [ 'Confirm with a capacity discharge test as IEEE Std 1188 recommends',
      'Check battery room temperature and its cooling',
      'Replace weak blocks or the whole string, depending on the test result',
      'Record a new resistance baseline after replacement' ],
    'Rising internal resistance means fading capacity, so the battery may not carry the load until the generator starts.',
    a11_battery).

maintenance(ups_on_bypass, urgent,
    [ 'Read the UPS alarm log to find why it transferred to bypass',
      'Call the UPS service engineer to repair the inverter or rectifier fault',
      'Postpone any upstream electrical work while the load has no battery protection',
      'Return the UPS to double conversion after the repair and confirm normal efficiency' ],
    'On static bypass the load gets raw utility power with no battery ride-through.',
    a12_ups).

maintenance(sensor_bias, high,
    [ 'Check the sensor against a calibrated reference instrument',
      'Check the sensor mounting and position',
      'Recalibrate or replace the sensor',
      'Do not act on readings from this sensor until it is verified' ],
    'One sensor disagrees with independent sensors that measure the same air, so the sensor is more likely wrong than the equipment.',
    a13_neighbour).

maintenance(telemetry_dropout, high,
    [ 'Check the monitoring agent, controller and network link for this telemetry group',
      'Restore the data feed',
      'Treat the equipment status as unknown until fresh data arrives',
      'Inspect critical equipment on site if the feed cannot be restored quickly' ],
    'Stale readings hide the real state of the equipment, so other diagnoses for it cannot be trusted.',
    a14_telemetry).

/*  plan_interaction(FaultA, FaultB, Advice)
    When FaultA and FaultB are diagnosed together, their plans interact.
    Usually the plan for FaultA ends with a check that relies on the sensor
    or data feed that FaultB says is unreliable, so FaultB must be resolved
    first. Advice is a format string whose one argument is the entity.
*/
plan_interaction(hot_air_recirculation(R), sensor_bias(t_inlet_top, R),
    'Fix the top inlet sensor on ~w first. The last step of the recirculation plan re-measures with that sensor.').
plan_interaction(hot_air_recirculation(R), sensor_bias(t_inlet_mid, R),
    'Fix the middle inlet sensor on ~w first. The last step of the recirculation plan re-measures with that sensor.').
plan_interaction(F, sensor_bias(t_supply_air, U), 'Fix the supply-air sensor on ~w first. The final check of this plan relies on the supply-air reading.') :-
    member(F, [crah_fan_failure(U), chw_supply_loss(U), filter_clogging(U)]).
plan_interaction(F, telemetry_dropout(G), 'Restore the telemetry feed from ~w first. The final check of this plan needs fresh readings from it.') :-
    F \= telemetry_dropout(_),
    F =.. [_, E | _],
    atom(E),
    sub_atom(E, 0, _, _, G).
