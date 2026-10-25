/*  tests/param_sensitivity.pl - sensitivity to the reasoning parameters set
    by judgement (engine/params.pl). tests/param_sensitivity.py drives it.

    param_sweep(+Split)
      Changes one parameter at a time from its default, runs the reasoning
      modes on every case in Split, and prints one line per variant and mode,
      starting with "JSON ". Deduction uses none of these parameters, so it
      is run once, at the defaults, as the reference.
*/

variant(default,       []).
variant(bonus_0,       [deductive_bonus-0.0]).
variant(bonus_005,     [deductive_bonus-0.05]).
variant(bonus_02,      [deductive_bonus-0.2]).
variant(bonus_05,      [deductive_bonus-0.5]).
variant(sigma_05,      [present_sigma-0.5]).
variant(sigma_15,      [present_sigma-1.5]).
variant(sigma_20,      [present_sigma-2.0]).
variant(bound_2,       [search_bound-2]).
variant(bound_3,       [search_bound-3]).
variant(bound_5,       [search_bound-5]).
variant(weights_uniform, [weight_mode-uniform]).
variant(weights_p1,    [weight_mode-perturbed(1)]).
variant(weights_p2,    [weight_mode-perturbed(2)]).
variant(weights_p3,    [weight_mode-perturbed(3)]).
variant(weights_p4,    [weight_mode-perturbed(4)]).
variant(weights_p5,    [weight_mode-perturbed(5)]).
variant(noise_fixed,   [scaled_noise-fixed]).

set_variant(Settings) :-
    retractall(param_override(_, _)),
    forall(member(N-V, Settings), assertz(param_override(N, V))).

param_sweep(Split) :-
    set_variant([]),
    exact_counts_on(deductive, Split, KD, N),
    format("JSON {\"variant\": \"default\", \"mode\": \"deductive\", \"correct\": ~d, \"n\": ~d}~n", [KD, N]),
    forall(variant(Name, Settings),
           ( set_variant(Settings),
             forall(member(M, [ded_abd, ded_cbd, full]),
                    ( get_time(T0),
                      exact_counts_on(M, Split, K, N2),
                      get_time(T1), Ms is (T1 - T0) * 1000 / max(1, N2),
                      format("JSON {\"variant\": \"~w\", \"mode\": \"~w\", \"correct\": ~d, \"n\": ~d, \"ms_per_case\": ~3f}~n",
                             [Name, M, K, N2, Ms]) )) )),
    set_variant([]),
    clear_symptom_cache.

exact_counts_on(Mode, Split, Ok, N) :-
    clear_symptom_cache,
    findall(C, case_split(C, Split), Cases),
    length(Cases, N),
    aggregate_all(count, ( member(C, Cases), expected(C, E0), msort(E0, S),
                           diagnose_mode(Mode, C, G0), msort(G0, S) ), Ok).
