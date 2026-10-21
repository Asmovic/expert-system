/*  engine/explain.pl - Stage 9 explanation facility.

    why(+Case)
      Explains the complete system's diagnosis. For every reported fault it
      gives the deductive proof when the rules prove it: observed evidence,
      derived quantities, reference values with provenance, derived
      conditions, rules activated, the reasoning trace and the maintenance
      action. Otherwise it gives the abductive evidence. It then lists the
      competing hypotheses with their confidence, the reason each weaker or
      rejected one lost, and the result of the consistency check.

    why_deductive(+Case)
      The same detail for the deductive rules only.
*/

why(C) :-
    case(C, Desc, Origin),
    format("~n=== Case ~w: ~w  [data origin: ~w] ===~n", [C, Desc, Origin]),
    full_diagnosis(C, Ls, trace(abd(Syms, Present, Unexp, _, Hyps), Ks, Ranked, How, Ds)),
    format("~nFINAL DIAGNOSIS (complete system): ~w~n", [Ls]),
    how_text(How, HowText),
    format("  Decided by: ~w~n", [HowText]),
    forall(member(L, Ls), explain_label(C, Syms, L)),
    explain_plan_interactions(Ls),
    explain_competition(Syms, Present, Unexp, Hyps, Ranked),
    explain_consistency(Ks, How, Ds).

why_deductive(C) :-
    case(C, Desc, Origin),
    format("~n=== Case ~w: ~w  [data origin: ~w] ===~n", [C, Desc, Origin]),
    diagnose(C, Ds),
    forall(member(D, Ds), explain_diag(D)).

how_text(abductive_and_consistent(_), 'the best-ranked abductive explanation, confirmed consistent with every conflict and fault model').
how_text(consistency_fallback(_), 'no abductive explanation was consistent, so the closest minimal consistent diagnosis was used').
how_text(abductive_only(_), 'the best abductive explanation; the consistency check found no alternative').

explain_label(C, _, L) :-
    memberchk(L, [normal, unexplained_abnormality]),
    !,
    (   L == normal
    ->  format("~nDIAGNOSIS: normal~n  No symptom is clearly present, and no fault rule fires (closed-world assumption, rule r30).~n", [])
    ;   format("~nDIAGNOSIS: unexplained_abnormality~n  Some symptoms are clearly present, but no hypothesis in the knowledge base explains them consistently.~n", [])
    ),
    print_maintenance(L),
    C = C.
explain_label(C, _, L) :-
    prove(fault(C, L), Proof),
    !,
    explain_diag(diag(L, Proof)).
explain_label(_, Syms, L) :-
    format("~nDIAGNOSIS: ~w~n  No deductive rule proves this fault on its own. It comes from abduction and consistency checking.~n", [L]),
    format("~n  Supporting symptoms:~n"),
    forall(( evidence(L, S, W), memberchk(sym(S, E, St, I), Syms) ),
           print_symptom(S, E, St, I, W)),
    print_maintenance(L).

print_symptom(S, E, St, graded(X, ThN, Th, Sig), W) :-
    !,
    threshold(ThN, _, Unit, Src),
    format("    - ~w: value ~3f against ~w = ~w ~w (noise ~3f), evidence ~2f, ~w, weight ~w  [source: ~w]~n",
           [S, X, ThN, Th, Unit, Sig, E, St, W, Src]).
print_symptom(S, E, St, _, W) :-
    format("    - ~w: evidence ~2f, ~w, weight ~w~n", [S, E, St, W]).

explain_competition(Syms, Present, Unexp, Hyps, Ranked) :-
    format("~n  Clearly present symptoms: ~w~n", [Present]),
    (   Unexp == [] -> true
    ;   format("  Present symptoms no hypothesis can explain: ~w~n", [Unexp])
    ),
    format("~n  Competing hypotheses (Conf is Stage 4 Eq. 56, a ranking score, not a probability):~n"),
    findall(Neg-h(H, Cf, V), ( member(hyp(H, Cf, V), Hyps), Neg is -Cf ), Ps),
    keysort(Ps, Sorted),
    (   Sorted == []
    ->  format("    none\n")
    ;   forall(member(_-h(H, Cf, V), Sorted), print_hyp(Syms, H, Cf, V))
    ),
    (   Ranked = [_, _|_]
    ->  format("~n  Alternative explanations of the same minimal size, in rank order:~n"),
        forall(member(D, Ranked), format("    - ~w~n", [D]))
    ;   true
    ).

print_hyp(_, H, Cf, in_explanation) :-
    format("    - ~w  Conf ~2f: part of a minimal explanation~n", [H, Cf]).
print_hyp(_, H, Cf, not_needed) :-
    format("    - ~w  Conf ~2f: not needed, because the chosen explanation already covers its symptoms with fewer faults~n", [H, Cf]).
print_hyp(_, H, Cf, rejected(S)) :-
    format("    - ~w  Conf ~2f: rejected, because it requires ~w, which is clearly absent~n", [H, Cf, S]).

explain_consistency(Ks, How, Ds) :-
    length(Ks, NK),
    format("~n  Consistency check: ~d conflict set(s) from violated redundancy relations.~n", [NK]),
    forall(member(K, Ks), format("    - at least one of ~w is abnormal~n", [K])),
    (   How = consistency_fallback(_)
    ->  length(Ds, ND),
        format("  Minimal consistent diagnoses found: ~d. The first five:~n", [ND]),
        forall(( nth1(I, Ds, D), I =< 5 ), format("    - ~w~n", [D]))
    ;   true
    ).

explain_diag(diag(F, closed_world(Rule))) :-
    !,
    format("~nDIAGNOSIS: ~w~n", [F]),
    closed_world_text(Rule, Text),
    format("  Rule ~w: ~w~n", [Rule, Text]),
    print_maintenance(F).
explain_diag(diag(F, Proof)) :-
    format("~nDIAGNOSIS: ~w~n", [F]),
    format("~n  Observed evidence:~n"),
    forall(distinct(G, evidence(Proof, G)), print_obs(G)),
    format("~n  Derived engineering quantities:~n"),
    forall(distinct(G, proof_leaf_kind(Proof, G, calculation)),
           ( pretty(G, PG), format("    - ~w~n", [PG]) )),
    format("~n  Reference values:~n"),
    forall(distinct(G, proof_leaf_kind(Proof, G, reference)), print_threshold(G)),
    format("~n  Derived conditions:~n"),
    forall(distinct(X-Id, proof_node(Proof, by(Id, cond(_, X), _))),
           format("    - ~w  (by ~w)~n", [X, Id])),
    format("~n  Rules activated:~n"),
    findall(Id, proof_node(Proof, by(Id, _, _)), Ids0),
    list_to_set(Ids0, Ids),
    forall(member(Id, Ids), print_rule(Id)),
    format("~n  Reasoning trace:~n"),
    print_tree(Proof, 4),
    print_maintenance(F).

closed_world_text(r30, 'no fault rule fired and every rack inlet is within the recommended envelope (closed-world assumption).').
closed_world_text(r31, 'a rack inlet is outside the envelope but no fault rule explains it.').

%   evidence(+Proof, -Obs): observations used directly or through a calculation.
evidence(Proof, G) :-
    proof_leaf_kind(Proof, G, observation).
evidence(Proof, G) :-
    proof_leaf_kind(Proof, Calc, calculation),
    calc_uses(Calc, G).

%   Classify proof leaves for reporting.
proof_leaf_kind(Proof, G, Kind) :-
    proof_node(Proof, leaf(G)),
    leaf_kind(G, Kind).

leaf_kind(obs(_, _, _, _), observation) :- !.
leaf_kind(threshold(_, _), reference) :- !.
leaf_kind(G, calculation) :- calc_pred(G), !.
leaf_kind(G, check) :- G =.. [Op, _, _], memberchk(Op, [>, <, >=, =<]), !.
leaf_kind(_, structure).

print_obs(obs(_, Var, Ent, Val)) :-
    (   variable(Var, Desc, Unit) -> true ; Desc = Var, Unit = '' ),
    format("    - ~w of ~w = ~w ~w~n", [Desc, Ent, Val, Unit]).

print_threshold(threshold(Name, Val)) :-
    threshold(Name, Val, Unit, Src),
    format("    - ~w = ~w ~w  [source: ~w]~n", [Name, Val, Unit, Src]).

print_rule(Id) :-
    drule(Id, _, _, Src), !,
    source(Src, Type, _),
    format("    - ~w  [source: ~w, ~w]~n", [Id, Src, Type]).

print_tree(by(Id, G, Ps), Ind) :-
    !,
    goal_label(G, L),
    format("~t~*|~w  [~w]~n", [Ind, L, Id]),
    Ind2 is Ind + 2,
    forall(member(P, Ps), print_tree(P, Ind2)).
print_tree(leaf(G), Ind) :-
    !,
    pretty(G, PG),
    format("~t~*|~w~n", [Ind, PG]).
print_tree(naf(G), Ind) :-
    format("~t~*|not ~w~n", [Ind, G]).

%   pretty(+Term, -Pretty): round every float to 3 decimals for display only.
pretty(X, Y) :- float(X), !, Y is round(X * 1000) / 1000.
pretty(X, X) :- \+ compound(X), !.
pretty(X, Y) :- X =.. [F|As], maplist(pretty, As, Bs), Y =.. [F|Bs].

goal_label(cond(_, X), cond(X)) :- !.
goal_label(fault(_, X), fault(X)) :- !.
goal_label(G, G).

print_maintenance(F) :-
    (   compound(F)
    ->  F =.. [Type|Args], atomic_list_concat(Args, ' on ', Ent)
    ;   Type = F, Ent = row
    ),
    maintenance(Type, Prio, Actions, Rationale, Src),
    format("~n  Recommended corrective maintenance for ~w  [priority: ~w]:~n", [Ent, Prio]),
    forall(nth1(I, Actions, A), format("    ~d. ~w~n", [I, A])),
    format("  Rationale: ~w  [source: ~w]~n", [Rationale, Src]).

explain_plan_interactions(Ls) :-
    findall(A-B-T, ( member(A, Ls), member(B, Ls), A \== B, plan_interaction(A, B, T) ), Is),
    (   Is == []
    ->  true
    ;   format("~n  Plan interactions (order the work as follows):~n"),
        forall(member(_-B-T, Is),
               ( B =.. [_|Args], last(Args, E), format(atom(Msg), T, [E]), format("    - ~w~n", [Msg]) ))
    ).
