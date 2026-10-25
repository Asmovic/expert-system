/*  engine/evidence.pl - graded symptom evidence (Stage 4 Eqs. 53 and 55).

    case_symptoms(+Case, -Symptoms)
      Symptoms is a list of sym(Symptom, E, Status, Info):
        E       evidence strength in [0, 1]
        Status  present (E >= 0.75), absent (E =< 0.25) or uncertain
        Info    graded(Value, ThresholdName, Threshold, Sigma) | crisp | composite
      A symptom whose inputs are missing does not appear at all, so its
      status is unknown. Missing evidence is never treated as absent.

    Grading: d is the signed distance past the threshold and sigma the
    feature's noise. E = 0.5 + d / (4 sigma), clipped to [0, 1]. So E = 0.5
    at the threshold, and the symptom counts as present only once the value
    is one standard deviation past it.

    Noise adaptation: temperature-feature noise scales with sigma_T, the
    temperature-sensor noise estimated from the case itself. The six middle
    inlets all see the same supply air, so their spread measures sensor
    noise. The median absolute deviation is used because it ignores one
    biased sensor. Electrical features (noise type power) scale with a
    noise factor estimated the same way from the rack power balances. The
    remaining cooling-unit features have no such redundancy, so they scale
    with kappa = sigma_T / 0.15 K, on the assumption that the cooling-unit
    instruments degrade together with the temperature sensors.
*/

:- dynamic sym_cache/2.

case_symptoms(C, Syms) :-
    sym_cache(C, Syms),
    !.
case_symptoms(C, Syms) :-
    compute_symptoms(C, Syms),
    assertz(sym_cache(C, Syms)).

clear_symptom_cache :-
    retractall(sym_cache(_, _)).

clear_symptom_cache(C) :-
    retractall(sym_cache(C, _)).

compute_symptoms(C, Syms) :-
    sigma_temp(C, ST),
    threshold(sensor_noise_floor, Floor),
    (   param(scaled_noise, fixed) -> Kappa = 1.0 ; Kappa is ST / Floor ),
    kappa_power(C, KP),
    findall(sym(S, E, St, graded(X, ThN, Th, Sig)),
            ( sdef(S, C, X, ThN, Goal, Dir, Noise),
              call(Goal),
              threshold(ThN, Th),
              noise_value(Noise, ST, Kappa, KP, Sig),
              grade(Dir, X, Th, Sig, E),
              grade_status(E, St) ),
            Graded),
    findall(sym(S, E, St, crisp),
            ( crisp_sym(S, C, Known, Present),
              once(Known),
              ( once(Present) -> E = 1.0 ; E = 0.0 ),
              grade_status(E, St) ),
            Crisp0),
    sort(Crisp0, Crisp),
    append(Graded, Crisp, Base),
    findall(sym(S, E, St, composite),
            ( composite_sym(S, P, N),
              member(sym(P, EP, _, _), Base),
              memberchk(sym(N, EN, _, _), Base),
              E is min(EP, 1 - EN),
              grade_status(E, St) ),
            Comp),
    append(Base, Comp, Syms).

%   sigma_T, the estimated temperature-sensor noise in kelvin.
sigma_temp(C, S) :-
    threshold(sensor_noise_floor, Floor),
    findall(X, obs(C, t_inlet_mid, _, X), Xs),
    length(Xs, N),
    (   N >= 4
    ->  median(Xs, M),
        findall(A, ( member(X, Xs), A is abs(X - M) ), As),
        median(As, Mad),
        S is max(Floor, 1.4826 * Mad)
    ;   S = Floor
    ).

noise_value(temp(F), ST, _, _, S)    :- S is F * ST.
noise_value(scaled(S0), _, K, _, S)  :- S is S0 * K.
noise_value(power(S0), _, _, KP, S)  :- S is S0 * KP.
noise_value(abs(S), _, _, _, S).

%   kappa_power: noise scale of the electrical meters, estimated from their
%   own redundancy. Each rack's metered power should equal the sum of its six
%   phase currents (Eq. 42). Across the six racks, the median absolute
%   residual divided by 0.6745 estimates the residual's standard deviation,
%   which is compared with its nominal value of 0.011.
kappa_power(C, KP) :-
    findall(A, ( component(R, rack), rack_power_residual(C, R, Res), A is abs(Res) ), As),
    length(As, N),
    (   N >= 4
    ->  median(As, M),
        KP is max(1.0, M / 0.6745 / 0.011)
    ;   KP = 1.0
    ).

grade(above, X, Th, Sig, E) :- D is X - Th, clip_grade(D, Sig, E).
grade(below, X, Th, Sig, E) :- D is Th - X, clip_grade(D, Sig, E).

clip_grade(D, Sig0, E) :-
    Sig is max(Sig0, 1.0e-6),          % guard: noise must stay positive
    E0 is 0.5 + D / (4 * Sig),
    E is max(0.0, min(1.0, E0)).

%   The cut-offs sit k noise standard deviations either side of the
%   threshold, k = 1 by default (engine/params.pl).
grade_status(E, St) :-
    param(present_sigma, K),
    (   E >= 0.5 + K / 4 -> St = present
    ;   E =< 0.5 - K / 4 -> St = absent
    ;   St = uncertain
    ).

%   Lookups on a symptom list. The symptom must be ground.
sym_status(Syms, S, St) :- memberchk(sym(S, _, St, _), Syms).
sym_grade(Syms, S, E)   :- memberchk(sym(S, E, _, _), Syms).
