/*  tests/metrics.pl - Stage 13 evaluation and Stage 14 reasoning-mode comparison.

    evaluation_report(+File)
      Runs all four reasoning modes on the calibration and held-out splits
      and writes every table to File as Markdown. Also prints a summary.

        swipl -g "evaluation_report('docs/08_evaluation_results.md')" -t halt main.pl tests/metrics.pl

    Metrics, following Stage 4 section 4.12:
      Exact match   predicted fault set equals the true set (EMR)
      Coverage      every true fault is in the prediction (extras allowed)
      Precision, recall and F1-score per fault class, from label-level
                    counts, then macro-averaged over the eleven true classes
      Class accuracy  (TP + TN) / N at case level for each class, averaged
      Reasoning time  mean and maximum wall-clock time per case
      ExplainabilityRate  share of cases where every reported label has a
                    justification: a deductive proof, a present abductive
                    symptom or a hit conflict, plus a maintenance plan
      PlanValidity  share of issued maintenance plans that address a fault
                    really present (a routine plan counts only for a truly
                    normal case)
*/

true_classes([normal, crah_fan_failure, chw_supply_loss, filter_clogging,
              hot_air_recirculation, server_fan_failure, branch_overload,
              battery_degradation, ups_on_bypass, sensor_bias, telemetry_dropout]).

label_class(L, K) :- ( compound(L) -> functor(L, K, _) ; K = L ).

%   run_mode(+Mode, +Split, -Results): r(Case, Category, Expected, Got, Ms)
run_mode(Mode, Split, Results) :-
    findall(C, case_split(C, Split), Cases),
    forall(member(C, Cases), ignore(diagnose_mode(Mode, C, _))),   % warm-up
    findall(r(C, Cat, E, G, Ms),
            ( member(C, Cases),
              case_category(C, Cat),
              expected(C, E0), msort(E0, E),
              clear_symptom_cache(C),
              get_time(T0),
              diagnose_mode(Mode, C, G0),
              get_time(T1),
              msort(G0, G),
              Ms is (T1 - T0) * 1000 ),
            Results).

%   ---- metric calculations ----------------------------------------------

emr(Rs, V) :-
    include([r(_, _, E, G, _)]>>(E == G), Rs, Ok),
    ratio(Ok, Rs, V).

coverage(Rs, V) :-
    include([r(_, _, E, G, _)]>>subset(E, G), Rs, Ok),
    ratio(Ok, Rs, V).

ratio(Part, All, V) :-
    length(Part, P), length(All, N),
    ( N > 0 -> V is P / N ; V = 0 ).

class_counts(Rs, K, TP, FP, FN) :-
    aggregate_all(sum(X), ( member(r(_, _, E, G, _), Rs), class_inter(E, G, K, X) ), TP),
    aggregate_all(sum(X), ( member(r(_, _, E, G, _), Rs), class_only(G, E, K, X) ), FP),
    aggregate_all(sum(X), ( member(r(_, _, E, G, _), Rs), class_only(E, G, K, X) ), FN).

class_inter(E, G, K, N) :-
    include([L]>>( label_class(L, K), memberchk(L, G) ), E, I), length(I, N).
class_only(A, B, K, N) :-
    include([L]>>( label_class(L, K), \+ memberchk(L, B) ), A, I), length(I, N).

prf(TP, FP, FN, P, R, F) :-
    ( TP + FP > 0 -> P is TP / (TP + FP) ; P = 0 ),
    ( TP + FN > 0 -> R is TP / (TP + FN) ; R = 0 ),
    ( P + R > 0 -> F is 2 * P * R / (P + R) ; F = 0 ).

macro_prf(Rs, MP, MR, MF) :-
    true_classes(Ks),
    findall(P-R-F, ( member(K, Ks), class_counts(Rs, K, TP, FP, FN), prf(TP, FP, FN, P, R, F) ), Ts),
    findall(P, member(P-_-_, Ts), Ps), mean(Ps, MP),
    findall(R, member(_-R-_, Ts), Rr), mean(Rr, MR),
    findall(F, member(_-_-F, Ts), Fs), mean(Fs, MF).

has_class(Ls, K, V) :- ( member(L, Ls), label_class(L, K) -> V = 1 ; V = 0 ).

%   Case-level accuracy for class K: (TP + TN) / N, framework Eq. 17.
mean_class_accuracy(Rs, V) :-
    true_classes(Ks),
    findall(A, ( member(K, Ks), class_accuracy2(Rs, K, A) ), As),
    mean(As, V).

class_accuracy2(Rs, K, A) :-
    include(same_presence(K), Rs, Ok),
    ratio(Ok, Rs, A).

same_presence(K, r(_, _, E, G, _)) :-
    has_class(E, K, X), has_class(G, K, Y), X =:= Y.

mean([], 0) :- !.
mean(Xs, M) :- sum_list(Xs, S), length(Xs, N), M is S / N.

times(Rs, Mean, Max) :-
    findall(Ms, member(r(_, _, _, _, Ms), Rs), Ts),
    mean(Ts, Mean), max_list(Ts, Max).

explainability_rate(Rs, V) :-
    include([r(C, _, _, G, _)]>>forall(member(L, G), label_explained(C, L)), Rs, Ok),
    ratio(Ok, Rs, V).

label_explained(_, normal) :- !.
label_explained(_, unexplained_abnormality) :- !.
label_explained(C, L) :-
    label_class(L, K),
    maintenance(K, _, _, _, _),
    (   prove(fault(C, L), _)
    ->  true
    ;   case_symptoms(C, Syms),
        (   evidence(L, S, _), sym_status(Syms, S, present)
        ->  true
        ;   comp_label(Cp, L), conflicts(Syms, Ks), member(K2, Ks), memberchk(Cp, K2)
        )
    ),
    !.

plan_validity(Rs, V) :-
    aggregate_all(count, ( member(r(_, _, _, G, _), Rs), member(_, G) ), NPlans),
    aggregate_all(count, ( member(r(_, _, E, G, _), Rs), member(L, G), memberchk(L, E) ), NValid),
    ( NPlans > 0 -> V is NValid / NPlans ; V = 0 ).

%   ---- report -------------------------------------------------------------

evaluation_report(File) :-
    modes(Ms),
    findall(Sp-M-Rs, ( member(Sp, [calibration, holdout]), member(M, Ms), run_mode(M, Sp, Rs) ), All),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       write_report(S, All),
                       close(S)),
    format("~nWrote ~w~n", [File]),
    write_summary(user_output, All).

write_report(S, All) :-
    format(S, "# Stage 13 and 14: Evaluation Results~n~n", []),
    format(S, "Generated by `tests/metrics.pl` from the current knowledge base and datasets. Do not edit by hand. All cases are synthetic.~n~n", []),
    format(S, "The calibration split (seed 20261020) was used to check thresholds. The held-out split (seed 777) was not used to choose anything, so it gives the reported performance.~n", []),
    forall(member(Sp, [holdout, calibration]),
           ( format(S, "~n## Reasoning-mode comparison: ~w split~n~n", [Sp]),
             ablation_table(S, All, Sp) )),
    forall(member(Sp, [holdout, calibration]),
           ( format(S, "~n## Exact match by test category: ~w split~n~n", [Sp]),
             category_table(S, All, Sp) )),
    member(holdout-full-RsF, All), !,
    format(S, "~n## Per-class results: complete system, held-out split~n~n", []),
    class_table(S, RsF),
    format(S, "~n## Confusion matrix: complete system, held-out split~n~n", []),
    format(S, "Single-label cases only (normal, single-fault and instrumentation categories). Rows are the true class and columns the predicted class. `multiple` means more than one label was predicted, and `unexpl.` means an unexplained abnormality.~n~n", []),
    confusion_table(S, RsF).

ablation_table(S, All, Sp) :-
    format(S, "| Mode | Exact match | Coverage | Macro precision | Macro recall | Macro F1 | Mean class accuracy | Mean time (ms) | Max time (ms) | ExplainabilityRate | PlanValidity |~n", []),
    format(S, "|---|---|---|---|---|---|---|---|---|---|---|~n", []),
    forall(( member(Sp-M-Rs, All) ),
           ( mode_name(M, Name),
             emr(Rs, E), coverage(Rs, Cv), macro_prf(Rs, P, R, F), mean_class_accuracy(Rs, A),
             times(Rs, Tm, Tx), explainability_rate(Rs, X), plan_validity(Rs, PV),
             format(S, "| ~w | ~1f% | ~1f% | ~3f | ~3f | ~3f | ~1f% | ~3f | ~3f | ~1f% | ~1f% |~n",
                    [Name, E*100, Cv*100, P, R, F, A*100, Tm, Tx, X*100, PV*100]) )).

category_table(S, All, Sp) :-
    modes(Ms),
    findall(N, ( member(M, Ms), mode_name(M, N) ), Ns),
    atomic_list_concat(Ns, ' | ', Header),
    format(S, "| Category | ~w |~n|---|---|---|---|---|~n", [Header]),
    forall(member(Cat, [normal, single_fault, instrumentation, multiple, incomplete, borderline, noisy]),
           ( findall(Cell, ( member(M, Ms), member(Sp-M-Rs, All),
                             include([r(_, K, _, _, _)]>>(K == Cat), Rs, In),
                             include([r(_, _, E, G, _)]>>(E == G), In, Ok),
                             length(In, N), length(Ok, P),
                             format(atom(Cell), "~d of ~d", [P, N]) ), Cells),
             atomic_list_concat(Cells, ' | ', Row),
             format(S, "| ~w | ~w |~n", [Cat, Row]) )).

class_table(S, Rs) :-
    format(S, "| Class | TP | FP | FN | Precision | Recall | F1 | Class accuracy |~n|---|---|---|---|---|---|---|---|~n", []),
    true_classes(Ks),
    forall(member(K, Ks),
           ( class_counts(Rs, K, TP, FP, FN), prf(TP, FP, FN, P, R, F), class_accuracy2(Rs, K, A),
             format(S, "| ~w | ~d | ~d | ~d | ~3f | ~3f | ~3f | ~1f% |~n", [K, TP, FP, FN, P, R, F, A*100]) )).

confusion_table(S, Rs) :-
    true_classes(Ks),
    append(Ks, [multiple, unexplained_abnormality], Cols),
    findall(H, ( member(K, Cols), short(K, H) ), Hs),
    atomic_list_concat(Hs, ' | ', Header),
    length(Cols, NC), NCols is NC + 1,
    findall('---', between(1, NCols, _), Dashes), atomic_list_concat(Dashes, '|', DashRow),
    format(S, "| True \\ predicted | ~w |~n|~w|~n", [Header, DashRow]),
    include([r(_, Cat, [_], _, _)]>>memberchk(Cat, [normal, single_fault, instrumentation]), Rs, Singles),
    forall(member(K, Ks),
           ( findall(Cell, ( member(P, Cols),
                             aggregate_all(count, ( member(r(_, _, [L], G, _), Singles), label_class(L, K),
                                                    predicted_class(G, P) ), N),
                             ( N =:= 0 -> Cell = '.' ; format(atom(Cell), "~d", [N]) ) ), Cells),
             atomic_list_concat(Cells, ' | ', Row),
             short(K, KH),
             format(S, "| ~w | ~w |~n", [KH, Row]) )).

predicted_class([L], K) :- !, label_class(L, K).
predicted_class(_, multiple).

short(normal, 'normal').
short(crah_fan_failure, 'F1 fan').
short(chw_supply_loss, 'F2 chw').
short(filter_clogging, 'F3 filter').
short(hot_air_recirculation, 'F4 recirc').
short(server_fan_failure, 'F5 srv fan').
short(branch_overload, 'F6 branch').
short(battery_degradation, 'F7 battery').
short(ups_on_bypass, 'F8 bypass').
short(sensor_bias, 'S1 sensor').
short(telemetry_dropout, 'S2 telemetry').
short(multiple, 'multiple').
short(unexplained_abnormality, 'unexpl.').

write_summary(S, All) :-
    format(S, "~n~w~t~46|~w~t~58|~w~t~70|~w~t~80|~w~n", ['Split / mode', 'Exact', 'Macro F1', 'Mean ms', 'Explain']),
    forall(member(Sp-M-Rs, All),
           ( mode_name(M, N), emr(Rs, E), macro_prf(Rs, _, _, F), times(Rs, Tm, _), explainability_rate(Rs, X),
             format(atom(L), "~w / ~w", [Sp, N]),
             format(S, "~w~t~46|~1f%~t~58|~3f~t~70|~3f~t~80|~1f%~n", [L, E*100, F, Tm, X*100]) )).
