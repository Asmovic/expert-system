/*  tests/rebaseline.pl - re-baselining thresholds from normal operating data.

    Under strong model mismatch the normal operating envelope moves, and fixed
    thresholds tuned to the nominal model then fire on healthy equipment.
    A real site has plenty of normal operating data, so the envelope
    thresholds can be re-baselined from it.

    rebaseline(+NominalSplit, +SiteSplit, -Offsets)
      For each envelope feature, the largest value seen in the normal cases
      of each split. Each threshold is shifted by how far the normal envelope
      moved, which keeps the original margin above normal operation.
      Only normal cases of SiteSplit are used: no fault labels are needed.

    Used by tests/mismatch.py.
*/

envelope_feature(strat_max,     C, X) :- component(R, rack), inlet_stratification(C, R, X).
envelope_feature(strat_out_max, C, X) :- component(R, rack), outlet_stratification(C, R, X).
envelope_feature(cpu_hot_min,   C, X) :- obs(C, t_cpu, _, X).

normal_max(Split, Name, Max) :-
    findall(X, ( case_split(C, Split), case_category(C, normal), envelope_feature(Name, C, X) ), Xs),
    Xs \== [],
    max_list(Xs, Max).

rebaseline(Nominal, Site, Offsets) :-
    findall(Name-D,
            ( member(Name, [strat_max, strat_out_max, cpu_hot_min]),
              normal_max(Nominal, Name, M0),
              normal_max(Site, Name, M1),
              D is max(0.0, M1 - M0) ),
            Offsets).

apply_offsets(Offsets) :-
    retractall(thr_offset(_, _)),
    retractall(thr_factor(_, _)),
    forall(member(N-D, Offsets), assertz(thr_offset(N, D))),
    clear_symptom_cache.
