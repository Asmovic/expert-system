/*  engine/consistency.pl - Stage 8.3 consistency-based diagnosis,
    KB u D u E is consistent (Reiter, 1987; de Kleer and Williams, 1987).

    conflicts(+Syms, -Conflicts)
      Every clearly violated relation in kb/arr.pl gives a conflict: the set
      of components that cannot all be healthy.

    cbd_diagnoses(+Syms, -Diagnoses)
      Subset-minimal sets of abnormal components that
        1. hit every conflict (Reiter's minimal hitting sets), and
        2. respect the fault models: an abnormal component whose fault model
           predicts a violation that clearly did not happen is exonerated,
           unless another abnormal component in that relation masks it.
      When a candidate breaks a fault model, the search tries adding a
      masking component, which finds multiple-fault diagnoses such as a
      recirculating rack whose top sensor reads low.

    consistent_delta(+Syms, +Conflicts, +Delta)
      Checks whether one candidate set of abnormal components is a diagnosis.
*/

max_diagnosis_size(M) :- param(search_bound, M).

conflicts(Syms, Ks) :-
    findall(Sup, ( member(sym(S, _, present, _), Syms), arr(_, S, Sup) ), K0),
    sort(K0, Ks).

%   fm_violation(+Syms, +Delta, -C, -ArrId, -Support)
fm_violation(Syms, Delta, C, Id, Sup) :-
    member(C, Delta),
    fm(C, Id),
    arr(Id, S, Sup),
    sym_status(Syms, S, absent),
    \+ ( member(C2, Delta), C2 \== C, memberchk(C2, Sup) ).

consistent_delta(Syms, Ks, Delta) :-
    forall(member(K, Ks), ( member(X, K), memberchk(X, Delta) )),
    \+ fm_violation(Syms, Delta, _, _, _).

cbd_diagnoses(Syms, Ds) :-
    conflicts(Syms, Ks),
    findall(R, cbd_search(Syms, Ks, [], 0, R), R0),
    sort(R0, R1),
    exclude(has_proper_subset(R1), R1, Ds).

cbd_search(Syms, Ks, Delta, Depth, Result) :-
    max_diagnosis_size(Max),
    (   unhit_conflict(Ks, Delta, K)
    ->  Depth < Max,
        D1 is Depth + 1,
        member(X, K),
        cbd_search(Syms, Ks, [X|Delta], D1, Result)
    ;   once(fm_violation(Syms, Delta, C, _, Sup))
    ->  Depth < Max,
        D1 is Depth + 1,
        member(M, Sup), M \== C, \+ memberchk(M, Delta),
        cbd_search(Syms, Ks, [M|Delta], D1, Result)
    ;   msort(Delta, Result)
    ).

unhit_conflict(Ks, Delta, K) :-
    member(K, Ks),
    \+ ( member(X, K), memberchk(X, Delta) ),
    !.

has_proper_subset(All, D) :-
    member(D2, All),
    D2 \== D,
    subset(D2, D).

%   Component sets and fault labels.
comps_of_labels(Ls, Delta) :-
    findall(Cp, ( member(L, Ls), comp_label(Cp, L) ), D0),
    sort(D0, Delta).

labels_of_comps(Delta, Ls) :-
    findall(L, ( member(Cp, Delta), comp_label(Cp, L) ), L0),
    msort(L0, Ls).

%   prune_delta(+Syms, +Ks, +Delta, -Pruned): drops components that hit no
%   conflict and mask nothing. Minimal diagnoses never contain them.
prune_delta(Syms, Ks, Delta, Pruned) :-
    include(useful_comp(Syms, Ks, Delta), Delta, Pruned).

useful_comp(_, Ks, _, C) :-
    member(K, Ks), memberchk(C, K), !.
useful_comp(Syms, _, Delta, C) :-
    member(C2, Delta), C2 \== C,
    fm(C2, Id), arr(Id, S, Sup),
    memberchk(C, Sup),
    sym_status(Syms, S, absent), !.

%   best_diagnosis(+Ds, +Prefer, -Best): most overlap with the preferred set,
%   then fewest sensor components, then smallest. Fewer sensors first means
%   equal-size ties go to a physical fault, the safer maintenance assumption.
best_diagnosis(Ds, Prefer, Best) :-
    findall(k(NegOv, NS, Sz)-D,
            ( member(D, Ds),
              intersection(D, Prefer, I), length(I, Ov), NegOv is -Ov,
              include([X]>>(X = sensor(_, _)), D, Sn), length(Sn, NS),
              length(D, Sz) ),
            Pairs),
    keysort(Pairs, [_-Best|_]).
