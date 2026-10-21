# Stage 14: Sensitivity and Ablation Analysis

**Status:** Draft v0.1. All numbers come from two generated files. [10_sensitivity_results.md](10_sensitivity_results.md) has the sweeps and [10b_threshold_sensitivity.md](10b_threshold_sensitivity.md) the thresholds. To regenerate both, together with the report figures `report/figures/sens_*.tex`:

```
python tests/sensitivity.py
```

The full run takes about 12 minutes. Every case is synthetic. Each sweep point has 60 new cases, and one seed per sweep keeps neighbouring levels paired.

## 14.1 Comparison of reasoning modes

The framework asks for four configurations. The held-out results are in [09_reasoning_modules.md](09_reasoning_modules.md) section 8.6. In short, adding abduction raises exact-match accuracy from 91.0% to 94.5%. Adding consistency checking alone raises it to 93.3%. The complete system reaches 93.7%. The sweeps below show where each module earns its place.

## 14.2 Sensor noise

| Noise multiple | Deductive | Deductive + abductive | Deductive + consistency | Complete |
|---|---|---|---|---|
| 1 | 100% | 100% | 100% | 100% |
| 2 | 92% | 98% | 93% | 98% |
| 3 | 58% | 82% | 60% | 80% |
| 4 | 42% | 73% | 52% | 70% |
| 5 | 25% | 55% | 37% | 55% |
| 8 | 5% | 33% | 17% | 23% |

**Noise is a precision problem, not a recall problem.** The deductive rules still find the true fault in 85 to 100% of noisy cases. Their exact match collapses because crisp thresholds turn noise into extra findings. PlanValidity drops with it: at four times normal noise, only 38% of deductive maintenance plans address a real fault.

**The modes with abduction degrade far more gracefully,** for two reasons. Evidence is graded against noise estimated from the case itself. And the parsimony principle keeps faults that are supported only by uncertain symptoms out of the answer. At four times normal noise, the abductive mode keeps 73% exact match and 66% PlanValidity.

**Consistency checking costs accuracy under heavy noise.** Chance violations of the electrical and energy balances become conflicts, which the module explains as sensor faults.

## 14.3 Missing observations

| Readings removed | Deductive | Deductive + abductive | Deductive + consistency | Complete |
|---|---|---|---|---|
| 0% | 98% | 100% | 98% | 100% |
| 10% | 78% | 92% | 90% | 92% |
| 20% | 60% | 82% | 80% | 82% |
| 30% | 50% | 72% | 72% | 72% |
| 40% | 43% | 65% | 65% | 65% |

The gap between the model-based modes and deduction widens with the share of missing readings, from about 7 points at 5% missing to about 22 points at 20% and beyond. Two design choices cause this. A missing reading makes its symptom *unknown*, never *absent*, so no hypothesis is rejected for lack of data. And a hypothesis can be accepted on its remaining evidence. A deductive rule, by contrast, fails as soon as one reading in its body is missing. Accuracy still falls steadily, because some faults have a single key reading, such as the battery's cell resistance. When that reading is gone, nothing else can reveal the fault.

## 14.4 Multiple simultaneous faults

| Faults at once | Deductive | Deductive + abductive | Deductive + consistency | Complete | Complete system recall | Complete system mean time |
|---|---|---|---|---|---|---|
| 1 | 98% | 100% | 98% | 100% | 1.00 | 3.1 ms |
| 2 | 83% | 88% | 88% | 85% | 0.97 | 4.9 ms |
| 3 | 65% | 68% | 73% | 68% | 0.92 | 3.7 ms |
| 4 | 37% | 48% | 57% | 48% | 0.75 | 4.4 ms |

**Precision stays near 1.0 at every fault count, and recall falls.** The system rarely invents a fault, but it misses more as faults interact. The cause is physical. Two cooling faults together, such as a fan failure with chilled-water loss, overlap in their symptoms. One fault can then explain most of what the pair shows, and parsimony prefers one fault to two.

**Consistency checking handles the most faults best,** with 57% exact match at four faults. A fault model forces it to keep a second fault whose own relation was violated, even when abduction could explain the symptoms with one.

**Reasoning stays tractable.** Mean time stays under 5 ms per case at every fault count. The bounded searches, capped at four faults, keep the worst case at a few tens of milliseconds.

## 14.5 Contradictory evidence: sensor bias size

| Bias | Deductive | Deductive + abductive | Deductive + consistency | Complete |
|---|---|---|---|---|
| 1 K | 5% | 0% | 0% | 0% |
| 2 K | 37% | 15% | 32% | 22% |
| 3 K | 75% | 75% | 87% | 87% |
| 4 K | 97% | 93% | 97% | 97% |
| 6 K and above | 100% | 100% | 100% | 100% |

A biased sensor contradicts its neighbours and the energy balances. Biases below the 2 K neighbour threshold are rarely detected, which is the expected limit of the design. Above 4 K, every mode detects nearly every bias. At 3 K, the consistency-based modes do best, because a single sensor fault is the only minimal diagnosis that removes every conflict. The graded modes are deliberately more cautious than deduction at 2 K, because they want one noise standard deviation of margin past the threshold.

## 14.6 Threshold changes

Each threshold was perturbed on its own on the held-out split. Temperatures moved by ±1 and ±2 K. Everything else was scaled by 0.8, 0.9, 1.1 and 1.2.

**Most thresholds are robust.** 11 of the 23 thresholds change nothing at any of the four levels, because backup rules or symptoms cover them, or because no case lies near them. At ±1 K or ±10%, all but three change complete-system accuracy by less than 3 points. The three exceptions:

- Outlet stratification at +1 K costs 4.3 points. Borderline recirculation cases fall below it.
- Branch loading scaled to 0.88 costs 3.9 points. The weakest overloads fall below it.
- UPS efficiency scaled to 0.88 costs 84 points, explained below.

**The large drops share one cause.** Each happens when the perturbed threshold moves inside the scatter of normal operation:

| Threshold, perturbed | Normal range | Complete system change |
|---|---|---|
| Inlet stratification 3 K, moved to 1 K | 1.0 to 2.2 K | -77 points |
| Neighbour deviation 2 K, moved to 0 K | about 0 to 0.4 K | -85 points |
| Cell resistance ratio 1.3, scaled to 1.04 | 0.95 to 1.14 | -30 points |
| Reduced fan power 0.85, scaled to 1.02 | 0.95 to 1.05 | -46 points |

This is evidence that each threshold sits in a real margin between the normal envelope and the fault envelope. The table also measures how wide each margin is.

**Consistency checking is fragile against a wrong relation threshold.** Scaling the UPS-efficiency threshold to 0.88 puts every double-conversion UPS, which runs near 0.955, above it. Deduction loses only 1.2 points, because its UPS rule relies on the mode flag. The complete system loses 84 points. The wrong relation produces a conflict in every case, so the consistency module rejects every correct explanation. A redundancy relation is a hard constraint, so a mis-set relation threshold corrupts every diagnosis. This argues for deriving relation thresholds from sensor uncertainty, as in Stage 4 equations 39 and 40, and for validating them on normal data before deployment.

## 14.7 Summary

| Question from the framework | Finding |
|---|---|
| Effect of threshold changes | Robust within ±1 K or ±10%. Failure only when a threshold enters normal scatter. Consistency checking is sensitive to wrong relation thresholds |
| Effect of missing observations | The model-based modes lead deduction by about 7 points at 5% missing, widening to about 22 points at 20% and beyond |
| Effect of contradictory evidence | Sensor biases of 3 K and more are reliably found. Consistency checking is best at the detection limit |
| Effect of noisy data | Abduction with noise-adaptive evidence is the most robust mode |
| Multiple-fault capability | Precision stays near 1.0. Recall falls to 0.75 at four faults, because interacting faults share symptoms |
| Reasoning time | Under 5 ms mean per case in every sweep |

**Limitation.** Each sweep point has only 60 cases, so a single case moves accuracy by about 1.7 points. Differences of a few points between modes are within that resolution.
