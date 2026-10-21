/*  run.pl - one-click runner for the VS Code "Prolog Runner" extension.

    Open this file and press the Run button. It loads the system, runs the
    full test suite, and prints explanations for the hand-written cases.
    For interactive use, load main.pl instead:  swipl main.pl
*/

:- ensure_loaded('main.pl').

:- initialization(run_all).

run_all :-
    run_suite,
    forall(case_category(C, smoke), why(C)).
