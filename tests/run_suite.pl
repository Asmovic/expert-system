/*  tests/run_suite.pl - test runner.

    run_suite/0      every case, reported separately for the smoke,
                     calibration and held-out splits: summary by category
                     and by expected fault, plus timing.
    run_suite(+Cat)  one category across all splits (smoke, normal, single_fault,
                     instrumentation, multiple, noisy, incomplete,
                     borderline), listing each failing case.

    A case passes when the diagnosed fault set equals the expected set
    exactly. Stage 13 will add precision, recall, F1-score, coverage,
    ExplainabilityRate, PlanValidity and a confusion matrix.
*/

run_suite :-
    forall(member(Split, [smoke, calibration, holdout]),
           (   findall(C, case_split(C, Split), Cases),
               Cases \== []
           ->  run_split(Split, Cases)
           ;   true
           )).

run_split(Split, Cases) :-
    run_cases(Cases, Results),
    format("~n==== Split: ~w (deductive mode only) ====~n", [Split]),
    (   Split == smoke
    ->  true
    ;   format("~nResults by test category~n"),
        print_breakdown(Results, category),
        format("~nResults by expected fault, single-fault and instrumentation cases only~n"),
        include(single_label, Results, Singles),
        print_breakdown(Singles, fault)
    ),
    print_totals(Results).

run_suite(Cat) :-
    findall(C, case_category(C, Cat), Cases),
    (   Cases == []
    ->  format("No cases in category ~w~n", [Cat])
    ;   run_cases(Cases, Results),
        format("~nFailures in category ~w:~n", [Cat]),
        forall(member(r(C, fail, Exp, Got, _), Results),
               ( case(C, Desc, _),
                 format("  ~w  ~w~n      expected:  ~w~n      diagnosed: ~w~n", [C, Desc, Exp, Got]) )),
        print_totals(Results)
    ).

%   run_cases(+Cases, -Results): Results are r(Case, pass|fail, Expected, Got, Ms).
run_cases(Cases, Results) :-
    % Warm-up pass so one-off library autoloading is not counted as reasoning time.
    forall(member(C, Cases), ignore(diagnosed_faults(C, _))),
    maplist(run_case, Cases, Results).

run_case(C, r(C, Result, Exp, Got, Ms)) :-
    expected(C, Exp),
    get_time(T0),
    diagnosed_faults(C, Got),
    get_time(T1),
    Ms is (T1 - T0) * 1000,
    (   msort(Exp, S), msort(Got, S) -> Result = pass ; Result = fail ).

single_label(r(C, _, [_], _, _)) :-
    case_category(C, Cat),
    memberchk(Cat, [single_fault, instrumentation, normal]).

%   Group key of a result: its category, or the functor of its single label.
result_key(category, r(C, _, _, _, _), K) :-
    case_category(C, K).
result_key(fault, r(_, _, [F], _, _), K) :-
    ( compound(F) -> functor(F, K, _) ; K = F ).

print_breakdown(Results, How) :-
    findall(K, ( member(R, Results), result_key(How, R, K) ), Ks0),
    sort(Ks0, Ks),
    format("  ~w~t~28|~w~t~38|~w~t~46|~w~n", [group, passed, total, rate]),
    forall(member(K, Ks),
           ( findall(Res, ( member(R, Results), result_key(How, R, K), R = r(_, Res, _, _, _) ), Rs),
             include(==(pass), Rs, Ps),
             length(Rs, N), length(Ps, P),
             Rate is 100.0 * P / N,
             format("  ~w~t~28|~d~t~38|~d~t~46|~1f%~n", [K, P, N, Rate]) )).

print_totals(Results) :-
    length(Results, N),
    include([r(_, pass, _, _, _)]>>true, Results, Passed),
    length(Passed, P),
    findall(Ms, member(r(_, _, _, _, Ms), Results), Times),
    sum_list(Times, Sum),
    max_list(Times, Max),
    Acc is 100.0 * P / N,
    Mean is Sum / N,
    format("~nExact-match accuracy: ~d/~d (~1f%)~n", [P, N, Acc]),
    format("Reasoning time: mean ~3f ms, max ~3f ms~n", [Mean, Max]).
