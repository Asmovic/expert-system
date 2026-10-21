# Stages 8 to 10: Reasoning Modules, Explanation and Maintenance Planning

**Status:** Draft v0.1. The numbers below come from [08_evaluation_results.md](08_evaluation_results.md), which `tests/metrics.pl` regenerates.

## 8.1 Architecture

The system has four layers. All reasoning is in Prolog.

1. **Engineering calculations,** `kb/calculations.pl`. They implement the Stage 4 equations.
2. **Deductive rules,** `kb/rules.pl` and `engine/deductive.pl`. 47 Horn-clause rules, run by a meta-interpreter that records a proof tree.
3. **Graded symptoms,** `kb/symptoms.pl` and `engine/evidence.pl`. Each symptom gets an evidence strength between 0 and 1, scaled to the noise level estimated from the case itself.
4. **Two model-based modules on top of the symptoms:**
   - **Abductive diagnosis,** `kb/causal.pl` and `engine/abductive.pl`.
   - **Consistency-based diagnosis,** `kb/arr.pl` and `engine/consistency.pl`.

`engine/hybrid.pl` combines them in the four configurations that Stage 14 compares.

## 8.2 Graded, noise-adaptive evidence

The deductive rules compare each feature with a crisp threshold. A reading just past the threshold counts as fully as one far past it. Under heavy sensor noise this produced many false findings.

The symptom layer instead grades each feature, following Stage 4 equation 55. Here d is the signed distance past the threshold and σ is the feature's noise:

```
E = 0.5 + d / (4 σ), clipped to [0, 1]
present   if E ≥ 0.75, meaning at least one σ past the threshold
absent    if E ≤ 0.25
uncertain otherwise
unknown   if an input reading is missing
```

**The noise σ comes from the case itself.** Three sensor families are handled differently:

- **Temperature sensors.** The six middle inlet sensors all see the same supply air, so their spread measures sensor noise. The median absolute deviation, scaled by 1.4826, is used because one biased sensor cannot distort it. The datasheet accuracy of 0.15 K acts as a floor.
- **Electrical meters.** Each rack's metered power should equal the sum of its six phase currents. The median residual across the six racks measures the meters' noise.
- **Cooling-unit instruments.** These have no redundancy of their own, so they scale with the temperature noise. That rests on the assumption that the instruments degrade together.

Each feature's nominal σ is propagated from the datasheet accuracy of the sensors it uses. Equation 11a, for example, has 2√2 times the noise of one temperature sensor.

**Missing evidence is never treated as absent.** That matters for the incomplete-evidence tests.

## 8.3 Abductive diagnosis

This follows parsimonious covering theory (Peng and Reggia, 1990 *[verify]*).

**Causal knowledge.** Each hypothesis is described by four relations:

- `evidence(H, S, W)`: hypothesis H predicts symptom S, with weight W.
- `requires(H, S)`: H is impossible if S is clearly absent.
- `also_explains(H, S)`: H can account for S without predicting it. A biased middle sensor, for example, distorts the top-minus-middle difference.
- `masks(H, S)`: H can hide S. A top sensor that reads low hides real stratification.

**An explanation D is a set of hypotheses that satisfies three conditions:**

1. It explains every clearly present symptom that any admissible hypothesis can explain.
2. It is consistent. No member requires a clearly absent symptom, unless another member masks it. This is the condition that D ∪ KB ∪ E is not contradictory.
3. It is parsimonious. No smaller set satisfies conditions 1 and 2, which is the condition D* = argmin |D|.

Uncertain and unknown symptoms never have to be explained. A noise-level reading therefore cannot force an extra fault into the answer. This is the main reason abduction more than doubles accuracy in the high-noise test.

**Ranking.** Explanations of the minimum size are ranked by the summed confidence of their members, Stage 4 equation 56. Hypotheses that the deductive rules also prove get a bonus of 0.1. Confidence is a ranking score, not a probability.

**Competing hypotheses.** Every candidate is reported with its confidence and its verdict: part of the explanation, not needed, or rejected. A rejected hypothesis is reported together with the required symptom that was clearly absent. This gives the framework's "reasons for rejecting weaker alternatives".

## 8.4 Consistency-based diagnosis

This follows Reiter (1987) and de Kleer and Williams (1987). Analytical redundancy relations bridge it to engineering fault detection (Cordier et al., 2004 *[verify]*). Fault models extend it as in Struss and Dressler (1989) *[verify]*.

**Components** include equipment such as the cooling fan, filter, chilled-water supply, rack seals, server fans, branch circuits, battery, UPS inverter and telemetry links. **Sensors are components too.** That is what lets the module blame a sensor instead of equipment.

**Relations.** There are 20 analytical redundancy relations. Each holds when its support set of components is healthy. Examples:

- The fan affinity law holds when the fan and its power and speed sensors are healthy.
- The rack power balance holds when the rack meter and its six phase-current sensors are healthy.

A clearly violated relation gives a **conflict**: at least one supporting component is abnormal.

**Diagnoses** are minimal sets of components that hit every conflict, so-called minimal hitting sets, and that respect the fault models.

**Fault models.** A fault model says that if a component is abnormal, a named relation must also be violated. A failed fan, for example, must show in fan power. If that relation clearly holds, the component is exonerated, unless another abnormal component in the relation masks the effect. When a candidate breaks a fault model, the search tries adding a masking component. That is how it finds the two-fault diagnosis of recirculation hidden by a low-reading sensor.

**Telling sensor faults from equipment faults.** Three examples show how this works:

- **Branch overload against a faulty current sensor.** A faulty current sensor would break the rack power balance. When that balance holds, the sensor is exonerated, which leaves the overload as the only diagnosis.
- **Top inlet sensor reading high.** Recirculation would also stratify the exhaust. When the exhaust is not stratified, the rack seal is exonerated.
- **Supply-air sensor bias.** The fan, filter and chilled water each have fault models that clearly did not fire. That leaves the sensor as the only single-component diagnosis. This is how the complete system catches a 3.2 K bias that the deductive and abductive modes both miss.

## 8.5 Combining the modes

| Configuration | How it decides |
|---|---|
| Deductive only | The rules in `kb/rules.pl` |
| Deductive + abductive | The best parsimonious explanation, ranked with the deductive bonus |
| Deductive + consistency-based | The deductive faults, minus any that hit no conflict, if they form a consistent diagnosis. Otherwise the minimal consistent diagnosis closest to them |
| Complete system | Abduction proposes, consistency disposes. The best-ranked abductive explanation that is also a consistent diagnosis. If none is consistent, the minimal consistent diagnosis closest to the top explanation |

When several consistent diagnoses tie, the one with fewer sensor components wins. Assuming a physical fault is the safer maintenance choice.

## 8.6 Results on the held-out split

| Configuration | Exact match | Macro F1 | High-noise cases | Borderline cases | Mean time |
|---|---|---|---|---|---|
| Deductive only | 91.0% | 0.924 | 3 of 15 | 6 of 15 | 0.2 ms |
| Deductive + abductive | 94.5% | 0.958 | 9 of 15 | 9 of 15 | 1.1 ms |
| Deductive + consistency-based | 93.3% | 0.950 | 5 of 15 | 9 of 15 | 1.0 ms |
| Complete system | 93.7% | 0.954 | 7 of 15 | 9 of 15 | 1.2 ms |

Every configuration gets all normal, single-fault and instrumentation cases right on the held-out split, and explains 100% of its outputs.

**The complete system is not the most accurate configuration.** That is a finding to report honestly:

- **What consistency checking adds.** It is the only mode that finds the smallest supply-sensor bias. It also refuses explanations that leave a violated relation unexplained.
- **What it costs under heavy noise.** At five times normal noise, it occasionally takes a chance violation of the power balance at face value and reports a meter fault. That lowers sensor-fault precision to 0.66.
- **Where the trade-off lies.** Abduction alone ignores those relations, which helps on noisy data but would also miss real meter faults. A real deployment should choose based on how noisy its instruments are. Repeated readings, with the filter in Stage 4 equation 54, would reduce the problem for both.

## 9. Explanation facility

`why(Case)` explains the complete system's diagnosis in five parts:

1. The final diagnosis and how it was decided.
2. For each fault, the deductive proof if the rules prove it: observed readings, derived quantities, thresholds with sources, derived conditions, rules fired and the full reasoning trace. Otherwise, the graded supporting symptoms, each with its value, threshold, noise, evidence strength and source.
3. The maintenance plan for each fault, and any plan interactions.
4. The competing hypotheses, each with its confidence and the reason it was used, not needed or rejected.
5. The consistency check: every conflict set and, where it was used, the minimal consistent diagnoses.

`why_deductive(Case)` gives the deductive detail alone.

## 10. Corrective-maintenance planner

Every fault class has a plan in `kb/maintenance.pl`. Each plan has a priority, ordered actions, an engineering rationale and a source.

**Plan interactions.** When two diagnoses interact, the planner orders the work. If recirculation and a biased top inlet sensor are diagnosed together, it says to fix the sensor first. Otherwise the recirculation plan's final check would re-measure with the faulty sensor. Similar rules cover the supply-air sensor and stale telemetry.

**PlanValidity.** This is the share of issued plans that address a fault really present. It rises from 85% with deductive reasoning alone to 93 to 94% once abduction removes spurious findings.

## Limitations to state in the report

- **Common noise level.** The noise of the cooling-unit instruments is inferred from the temperature sensors. That assumes they degrade together.
- **Expert-assigned weights.** The confidence weights in `kb/causal.pl` were set by engineering judgement and not fitted to data. Confidence is a ranking, not a probability.
- **Bounded search.** Explanations and diagnoses are capped at four faults. That is enough for every test case, and it keeps worst-case time at a few milliseconds.
- **One physical interaction is not modelled.** A failed server fan inside a recirculating rack reduces exhaust stratification. One such multiple-fault case is then reported as a sensor fault.
