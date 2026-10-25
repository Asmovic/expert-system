/*  tests/fidelity.pl - explanation fidelity, a test that can fail.

    ExplainabilityRate is 100% by construction: the system only reports a
    label it can justify. This test asks instead whether the justification
    is the real reason for the diagnosis. For every fault label a mode
    reports, it removes the observations the explanation cites and diagnoses
    the case again:

      Necessity  removing the cited observations removes the label.
                 A faithful explanation names evidence the label depends on.
      Control    removing the same number of uncited observations, chosen at
                 random, keeps the label. This shows that the label does not
                 vanish whenever any readings go missing.

    A removed observation is missing, not zero, which is how the system
    already treats a failed sensor.

    The cited observations of label L in case C are the union of
      - the observed evidence of the deductive proof of L, if there is one,
      - the observations behind every clearly present symptom that L
        predicts or can account for (kb/causal.pl), and
      - the observations behind every violated redundancy relation whose
        support contains L's component (kb/arr.pl).
    These are what the explanation facility reports for L.

    Run on its own, not after main.pl, because obs/4 must be dynamic:

        swipl -g "fidelity_report('docs/13_explanation_fidelity.md', 'report/tables')" -t halt tests/fidelity.pl
*/

:- dynamic(user:obs/4).
:- ensure_loaded('../main.pl').

fault_label(L) :- \+ memberchk(L, [normal, unexplained_abnormality]).

%   ---- observations an explanation cites --------------------------------

cited_obs(C, L, Os) :-
    case_symptoms(C, Syms),
    findall(O, cited_ob(C, Syms, L, O), Os0),
    sort(Os0, Os).

cited_ob(C, _, L, O) :-
    prove(fault(C, L), P),
    evidence(P, O).
cited_ob(C, Syms, L, O) :-
    member(sym(S, _, present, _), Syms),
    ( evidence(L, S, _) ; also_explains(L, S) ),
    sym_obs(C, S, O).
cited_ob(C, Syms, L, O) :-
    comp_label(Cp, L),
    member(sym(S, _, present, _), Syms),
    arr(_, S, Sup), memberchk(Cp, Sup),
    sym_obs(C, S, O).

%   sym_obs(+Case, +Symptom, -Obs): the observations a symptom is computed from.
sym_obs(C, S, O) :-
    sdef(S, C, _, _, Goal, _, _),
    goal_obs(Goal, O).
sym_obs(C, S, O) :-
    crisp_sym(S, C, Known, Present),
    ( goal_obs(Known, O) ; goal_obs(Present, O) ).
sym_obs(C, S, O) :-
    composite_sym(S, P, N),
    ( sym_obs(C, P, O) ; sym_obs(C, N, O) ).

goal_obs((A, B), O) :- !, ( goal_obs(A, O) ; goal_obs(B, O) ).
goal_obs(obs(C, V, E, X), obs(C, V, E, X)) :- !, obs(C, V, E, X).
goal_obs(prove(G, _), O) :- !, prove(G, P), evidence(P, O).
goal_obs(median_inlet_max(C, _), O) :- !,
    component(R, rack), calc_uses(inlet_max(C, R, _), O).
goal_obs(rack_power_residual(C, R, _), O) :- !,
    (   O = obs(C, p_rack, R, X), obs(C, p_rack, R, X)
    ;   phase_of_rack(R, B), O = obs(C, i_branch, B, X), obs(C, i_branch, B, X)
    ).
goal_obs(G, O) :- calc_pred(G), !, calc_uses(G, O).

%   ---- diagnosis with observations removed --------------------------------

%   diagnose_without(+Mode, +Case, +Removed, -Labels): copies the case under a
%   fresh name without the Removed observations, diagnoses the copy, and then
%   deletes it.
diagnose_without(M, C, Removed, Ls) :-
    gensym(fid_, C2),
    forall(( obs(C, V, E, X), \+ ord_memberchk(obs(C, V, E, X), Removed) ),
           assertz(obs(C2, V, E, X))),
    setup_call_cleanup(true,
                       ( diagnose_mode(M, C2, Ls0) -> msort(Ls0, Ls) ; Ls = [] ),
                       ( retractall(obs(C2, _, _, _)), clear_symptom_cache(C2) )).

random_uncited(C, Cited, N, Os) :-
    findall(obs(C, V, E, X), ( obs(C, V, E, X), \+ ord_memberchk(obs(C, V, E, X), Cited) ), Pool),
    random_permutation(Pool, Shuffled),
    length(Pool, NP), K is min(N, NP),
    length(Os0, K), append(Os0, _, Shuffled),
    sort(Os0, Os).

%   fid(Mode, Case, Label, NCited, AfterCited, AfterControl)
fidelity_rows(Split, Rows) :-
    set_random(seed(20261021)),
    modes(Ms),
    findall(fid(M, C, L, N, Lc, Lr),
            ( case_split(C, Split), member(M, Ms),
              diagnose_mode(M, C, Ls), member(L, Ls), fault_label(L),
              cited_obs(C, L, Cited), length(Cited, N),
              diagnose_without(M, C, Cited, Lc),
              random_uncited(C, Cited, N, Rand),
              diagnose_without(M, C, Rand, Lr) ),
            Rows).

%   What replaced the label once its cited evidence was gone.
outcome(L, Ls, kept) :- memberchk(L, Ls), !.
outcome(_, [normal], normal) :- !.
outcome(_, [unexplained_abnormality], unexplained) :- !.
outcome(_, _, other_label).

outcome_is(L, Ls, O) :- outcome(L, Ls, O0), O0 == O.

mode_stats(Rows, M, s(N, NecOk, CtlOk, Norm, Unex, Oth, MeanCited)) :-
    include([fid(M2, _, _, _, _, _)]>>(M2 == M), Rows, Rs),
    length(Rs, N),
    aggregate_all(count, ( member(fid(_, _, L, _, Lc, _), Rs), \+ outcome_is(L, Lc, kept) ), NecOk),
    aggregate_all(count, ( member(fid(_, _, L, _, _, Lr), Rs), outcome_is(L, Lr, kept) ), CtlOk),
    aggregate_all(count, ( member(fid(_, _, L, _, Lc, _), Rs), outcome_is(L, Lc, normal) ), Norm),
    aggregate_all(count, ( member(fid(_, _, L, _, Lc, _), Rs), outcome_is(L, Lc, unexplained) ), Unex),
    aggregate_all(count, ( member(fid(_, _, L, _, Lc, _), Rs), outcome_is(L, Lc, other_label) ), Oth),
    aggregate_all(bag(K), member(fid(_, _, _, K, _, _), Rs), Ks),
    ( Ks == [] -> MeanCited = 0 ; sum_list(Ks, SK), MeanCited is SK / N ).

pct(K, N, P) :- ( N > 0 -> P is 100 * K / N ; P = 0 ).

%   ---- report ---------------------------------------------------------------

fidelity_report(MdFile, TexDir) :-
    fidelity_rows(holdout, Rows),
    modes(Ms),
    findall(M-St, ( member(M, Ms), mode_stats(Rows, M, St) ), Stats),
    setup_call_cleanup(open(MdFile, write, S, [encoding(utf8)]),
                       write_md(S, Rows, Stats),
                       close(S)),
    directory_file_path(TexDir, 'eval_fidelity.tex', TexFile),
    setup_call_cleanup(open(TexFile, write, T, [encoding(utf8)]),
                       write_tex(T, Stats),
                       close(T)),
    forall(member(M-s(N, Nec, Ctl, _, _, _, _), Stats),
           format("JSON {\"mode\": \"~w\", \"labels\": ~d, \"necessity\": ~d, \"control\": ~d}~n", [M, N, Nec, Ctl])).

write_md(S, Rows, Stats) :-
    format(S, "# Explanation Fidelity~n~nGenerated by `tests/fidelity.pl`. Do not edit by hand. Every case is synthetic (held-out split, seed 777).~n~n", []),
    format(S, "For every fault label a mode reports, the observations its explanation cites are removed and the case is diagnosed again. **Necessity**: the label disappears. **Control**: the label survives when the same number of uncited observations, chosen at random (seed 20261021), are removed instead. A removed observation is missing, which the system treats as unknown.~n~n", []),
    format(S, "| Mode | Labels | Mean cited observations | Necessity | Replaced by normal | by unexplained | by another label | Control |~n|---|---|---|---|---|---|---|---|~n", []),
    forall(member(M-s(N, Nec, Ctl, No, Un, Ot, Mc), Stats),
           ( mode_name(M, Nm), pct(Nec, N, PN), pct(Ctl, N, PC),
             format(S, "| ~w | ~d | ~1f | ~d (~1f%) | ~d | ~d | ~d | ~d (~1f%) |~n", [Nm, N, Mc, Nec, PN, No, Un, Ot, Ctl, PC]) )),
    format(S, "~n## Labels that survived the removal of their cited evidence~n~n", []),
    format(S, "| Mode | Case | Label | Cited | Diagnosis after removal |~n|---|---|---|---|---|~n", []),
    forall(( member(fid(M, C, L, K, Lc, _), Rows), outcome_is(L, Lc, kept) ),
           format(S, "| ~w | ~w | `~w` | ~d | `~w` |~n", [M, C, L, K, Lc])),
    format(S, "~n## Labels lost in the control~n~n", []),
    format(S, "| Mode | Case | Label | Removed | Diagnosis after removal |~n|---|---|---|---|---|~n", []),
    forall(( member(fid(M, C, L, K, _, Lr), Rows), \+ outcome_is(L, Lr, kept) ),
           format(S, "| ~w | ~w | `~w` | ~d | `~w` |~n", [M, C, L, K, Lr])).

write_tex(S, Stats) :-
    format(S, "% Generated by tests/fidelity.pl. Do not edit by hand.~n", []),
    format(S, "\\begin{table}[htbp]~n  \\centering~n  \\footnotesize~n  \\setlength{\\tabcolsep}{4pt}~n", []),
    format(S, "  \\caption{Explanation fidelity on the held-out split. Necessity: share of reported fault labels that disappear when the observations their explanation cites are removed. The next three columns say what replaced them. Control: share that survive when the same number of uncited observations are removed at random.}~n  \\label{tab:fidelity}~n", []),
    format(S, "  \\begin{tabular}{L{4.9cm}rrrrrrr}~n  \\toprule~n", []),
    format(S, "  & & Cited & & \\multicolumn{3}{c}{Replaced by} & \\\\~n  \\cmidrule(lr){5-7}~n", []),
    format(S, "  Mode & Labels & (mean) & Necessity & normal & unexpl. & other & Control \\\\~n  \\midrule~n", []),
    forall(member(M-s(N, Nec, Ctl, No, Un, Ot, Mc), Stats),
           ( mode_name(M, Nm), pct(Nec, N, PN), pct(Ctl, N, PC),
             format(S, "  ~w & ~d & ~1f & ~1f\\% & ~d & ~d & ~d & ~1f\\% \\\\~n", [Nm, N, Mc, PN, No, Un, Ot, PC]) )),
    format(S, "  \\bottomrule~n  \\end{tabular}~n\\end{table}~n", []).
