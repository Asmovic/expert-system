# Data Centre Cooling and Power Expert System

An explainable Prolog expert system that diagnoses faults in the cooling and power infrastructure of one data centre row. It also recommends corrective maintenance. MSc Knowledge Representation and Reasoning mini-project.

## Status

| Part | State |
|---|---|
| Stage 1 to 4 design documents and dataset document | Drafts in `docs/` |
| Knowledge base: thresholds, rules, maintenance, provenance | 47 rules covering all 11 classes: normal, F1 to F8, S1 and S2 |
| Deductive reasoning with proof recording | Working |
| Explanation facility | Working |
| Abductive and consistency-based reasoning | Working, with noise-adaptive graded evidence. See `docs/09_reasoning_modules.md` |
| Evaluation: metrics, confusion matrix, reasoning-mode comparison | Working. Results in `docs/08_evaluation_results.md` |
| Sensitivity analysis: noise, missing data, multiple faults, sensor bias, thresholds | Working. Analysis in `docs/10_sensitivity_analysis.md` |
| Model-mismatch experiment and threshold re-baselining | Working. `tests/mismatch.py`, results in `docs/12_model_mismatch.md` |
| Explanation fidelity: remove cited evidence, rediagnose | Working. `tests/fidelity.pl`, results in `docs/13_explanation_fidelity.md` |
| Sensitivity to the reasoning parameters set by judgement (`engine/params.pl`) | Working. `tests/param_sensitivity.py`, results in `docs/15_parameter_sensitivity.md` |
| Variability over five held-out seeds, with pooled significance tests | Working. `tests/seeds.py`, results in `docs/16_seed_variability.md` |
| Simulator for synthetic test cases | Working: a calibration split and a held-out split of 255 cases each |
| LaTeX report | Complete draft, 96 pages: abstract and all seven chapters, 13 figures, generated tables. Bibliography has 70 entries that the author still has to verify, then export from EndNote |

## Requirements

- SWI-Prolog 10.0.2 or later. Tested on Windows 11.
- No extra Prolog packages are needed.
- Python 3 with the standard library only, to regenerate the dataset. Tested with Python 3.13.
- Optional: scikit-learn 1.9 (with NumPy), only for the data-driven baseline `tests/baseline.py`. The expert system and every other script work without it.
- MiKTeX with Strawberry Perl, to build the report. From `report/`: `pdflatex figures_preview.tex` checks every figure.

## Running

From this folder:

```
python simulator/dc_sim.py      # optional: regenerate the calibration split (seed 20261020)
swipl main.pl
?- run_suite.                   % every case, results by category and by fault
?- run_suite(single_fault).     % one category, listing each failure
?- why(f01).                    % complete-system explanation with competing hypotheses
?- why_deductive(f01).          % deductive proof only
?- diagnose_mode(full, h188, D).  % modes: deductive, ded_abd, ded_cbd, full
```

To check that everything reproduces, about 20 seconds (regenerates both datasets and compares checksums, then reruns every mode on every split):

```
python tests/reproduce.py            # 35 checks; exit code 0 if all pass
python tests/reproduce.py --tables   # also regenerate every report table
```

Or non-interactively:

```
swipl -g run_suite -t halt main.pl
```

Expected result of `run_suite` at this stage: 4 of 4 smoke cases, 227 of 255 calibration cases and 232 of 255 held-out cases. The command that regenerates the held-out split is in `docs/06_dataset_and_simulator.md`. In VS Code, open `run.pl` and press the Prolog Runner button.

To regenerate the evaluation tables, with all four reasoning modes on both splits:

```
swipl -g "evaluation_report('docs/08_evaluation_results.md')" -t halt main.pl tests/metrics.pl
```

To rerun the Stage 14 sensitivity analysis, about 12 minutes, which writes `docs/10_sensitivity_results.md`, `docs/10b_threshold_sensitivity.md` and the figures in `report/figures/`:

```
python tests/sensitivity.py
```

To regenerate the rule and provenance tables for the report:

```
swipl -g "export_rules('docs/07_rule_table.md')" -t halt main.pl tests/export_rules.pl
```

## Layout

```
main.pl                 entry point, loads everything
kb/sources.pl           provenance of every rule and threshold
kb/thresholds.pl        reference values
kb/components.pl        structure of the row, ratings, variable dictionary
kb/calculations.pl      engineering equations as predicates
kb/rules.pl             diagnostic rules stored as data: drule(Id, Head, Body, Source)
kb/maintenance.pl       corrective-maintenance actions per fault
engine/prover.pl        meta-interpreter that records proof trees
engine/deductive.pl     deductive diagnosis
kb/symptoms.pl          graded symptom definitions with noise models
kb/causal.pl            causal signatures for abduction
kb/arr.pl               redundancy relations and fault models for consistency-based diagnosis
engine/evidence.pl      noise-adaptive evidence grading
engine/abductive.pl     abductive diagnosis by parsimonious covering
engine/consistency.pl   consistency-based diagnosis by minimal hitting sets
engine/hybrid.pl        the four reasoning configurations
engine/explain.pl       explanation facility
data/cases.pl           four hand-written smoke-test cases
data/generated_cases.*  calibration split as Prolog facts and CSV, with ground truth in JSON
data/holdout_cases.*    held-out split, same formats
tests/run_suite.pl      test runner
tests/export_rules.pl   writes docs/07_rule_table.md from the knowledge base
tests/metrics.pl        writes docs/08_evaluation_results.md
tests/sensitivity.pl    threshold perturbation and sweep metrics
tests/sensitivity.py    drives the Stage 14 sweeps and writes the figures
tests/metrics_latex.pl  writes the evaluation tables for the report
tests/export_latex.pl   writes the rule, threshold and provenance tables for the report
tests/reproduce.py      one-command reproduction check
simulator/dc_sim.py     steady-state physics simulator that generates the test cases
run.pl                  one-click runner for the VS Code Prolog Runner extension
docs/                   design documents for Stages 1 to 4, knowledge acquisition and the dataset
report/                 LaTeX report: main.tex, sections/, figures/ (8 TikZ diagrams, 5 pgfplots charts)
report/figures_preview.tex  compiles every figure on its own page for checking
```

## Data origin

Every case in `data/cases.pl` and `data/generated_cases.pl` is **synthetic** and is labelled as synthetic in its `case/3` fact. See `docs/06_dataset_and_simulator.md`. No value in this repository is a measurement from a real facility. Measured data, synthetic test cases, engineering assumptions and literature-supported rules are kept apart. Each threshold and rule names its source type in `kb/sources.pl`.

## Design note

Rules are stored as `drule/4` facts and executed by a small meta-interpreter, not written as plain Prolog clauses. The meta-interpreter returns a proof tree for every conclusion. The explanation facility reads that tree to report the evidence, the rules fired and their sources. Every rule is still a Horn clause, and the core reasoning stays in Prolog.
