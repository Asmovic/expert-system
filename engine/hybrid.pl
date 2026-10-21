/*  engine/hybrid.pl - the four reasoning configurations compared in Stage 14.

    diagnose_mode(+Mode, +Case, -Labels)
      deductive  rules in kb/rules.pl only (engine/deductive.pl)
      ded_abd    deductive plus abductive: the best parsimonious explanation,
                 with a small bonus for hypotheses the rules also prove
      ded_cbd    deductive plus consistency-based: the deductive faults are
                 kept if they form a consistent diagnosis, after dropping any
                 that hit no conflict; otherwise the closest minimal
                 consistent diagnosis replaces them
      full       abduction proposes, consistency disposes: the best-ranked
                 explanation that is also a consistent diagnosis

    full_diagnosis(+Case, -Labels, -Trace) also returns what the explanation
    facility needs.
*/

modes([deductive, ded_abd, ded_cbd, full]).

mode_name(deductive, 'Deductive only').
mode_name(ded_abd,   'Deductive + abductive').
mode_name(ded_cbd,   'Deductive + consistency-based').
mode_name(full,      'Complete system').

diagnose_mode(deductive, C, Ls) :-
    diagnosed_faults(C, Ls).
diagnose_mode(ded_abd, C, Ls) :-
    diagnosed_faults(C, Ld),
    abduce(C, abd(Syms, _, Unexp, Covers, _)),
    rank_covers(Syms, Ld, Covers, Ranked),
    (   Ranked = [D|_] -> true ; D = [] ),
    final_labels(D, Unexp, Ls).
diagnose_mode(ded_cbd, C, Ls) :-
    diagnosed_faults(C, Ld),
    case_symptoms(C, Syms),
    conflicts(Syms, Ks),
    comps_of_labels(Ld, D0),
    prune_delta(Syms, Ks, D0, D1),
    (   consistent_delta(Syms, Ks, D1)
    ->  (   D1 == [], Ks == []
        ->  ( Ld == [unexplained_abnormality] -> Ls = Ld ; Ls = [normal] )
        ;   labels_of_comps(D1, Ls)
        )
    ;   cbd_diagnoses(Syms, Ds),
        (   Ds == []
        ->  ( D1 == [] -> Ls = [unexplained_abnormality] ; labels_of_comps(D1, Ls) )
        ;   best_diagnosis(Ds, D1, Best),
            labels_of_comps(Best, Ls)
        )
    ).
diagnose_mode(full, C, Ls) :-
    full_diagnosis(C, Ls, _).

full_diagnosis(C, Ls, trace(Abd, Ks, Ranked, How, Ds)) :-
    diagnosed_faults(C, Ld),
    abduce(C, Abd),
    Abd = abd(Syms, _, Unexp, Covers, _),
    rank_covers(Syms, Ld, Covers, Ranked),
    conflicts(Syms, Ks),
    (   member(D, Ranked),
        comps_of_labels(D, Delta),
        consistent_delta(Syms, Ks, Delta)
    ->  How = abductive_and_consistent(D),
        Ds = [],
        final_labels(D, Unexp, Ls)
    ;   cbd_diagnoses(Syms, Ds),
        Ds \== []
    ->  ( Ranked = [Top|_] -> comps_of_labels(Top, Pref) ; Pref = [] ),
        best_diagnosis(Ds, Pref, Best),
        How = consistency_fallback(Best),
        labels_of_comps(Best, Ls)
    ;   (   Ranked = [Top|_] -> true ; Top = [] ),
        How = abductive_only(Top),
        Ds = [],
        final_labels(Top, Unexp, Ls)
    ).

final_labels([], [], [normal]) :- !.
final_labels([], _, [unexplained_abnormality]) :- !.
final_labels(D, _, Ls) :- msort(D, Ls).
