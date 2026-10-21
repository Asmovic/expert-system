/*  main.pl - entry point for the data centre cooling and power expert system.

    Load:   swipl main.pl
    Query:  ?- why(f01).                explain one case
            ?- run_suite.               all cases, summary by category
            ?- run_suite(single_fault). one category, with each failure listed
            ?- run_suite(smoke).        the four hand-written cases
*/

:- ensure_loaded('kb/sources.pl').
:- ensure_loaded('kb/thresholds.pl').
:- ensure_loaded('kb/components.pl').
:- ensure_loaded('kb/calculations.pl').
:- ensure_loaded('kb/rules.pl').
:- ensure_loaded('kb/maintenance.pl').
:- ensure_loaded('kb/symptoms.pl').
:- ensure_loaded('kb/causal.pl').
:- ensure_loaded('kb/arr.pl').
:- ensure_loaded('engine/prover.pl').
:- ensure_loaded('engine/deductive.pl').
:- ensure_loaded('engine/evidence.pl').
:- ensure_loaded('engine/abductive.pl').
:- ensure_loaded('engine/consistency.pl').
:- ensure_loaded('engine/hybrid.pl').
:- ensure_loaded('engine/explain.pl').
:- ensure_loaded('data/cases.pl').
:- ensure_loaded('data/generated_cases.pl').   % calibration split, seed 20261020
:- ensure_loaded('data/holdout_cases.pl').     % held-out split, seed 777
:- ensure_loaded('tests/run_suite.pl').
