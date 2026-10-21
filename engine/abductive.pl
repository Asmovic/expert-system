/*  engine/abductive.pl - Stage 8.2 abductive diagnosis, D u KB |= E.

    Parsimonious covering (Peng and Reggia, 1990) over the causal knowledge
    in kb/causal.pl.

    abduce(+Case, -Result)
      Result = abd(Syms, Present, Unexplained, Covers, Hyps)
        Syms         graded symptoms of the case (engine/evidence.pl)
        Present      clearly present symptoms that need explaining
        Unexplained  present symptoms that no admissible hypothesis explains
        Covers       every explanation of minimum size, as sorted lists
        Hyps         hyp(H, Conf, Verdict) for every candidate hypothesis

    An explanation D is a set of hypotheses such that:
      1. every explainable present symptom is explained by some h in D,
      2. no h in D requires a symptom that is clearly absent, unless another
         member of D masks that symptom (consistency, D u KB u E is not false),
      3. no smaller set satisfies 1 and 2 (parsimony, D* = argmin |D|).
    Uncertain and unknown symptoms never have to be explained, so weak or
    noise-level readings cannot force extra faults into an explanation.

    Conf(h) is Stage 4 Eq. 56: E_h / (E_h + E_not_h + 0.01). It is a ranking
    score, not a probability.
*/

max_explanation_size(4).

abduce(C, abd(Syms, Present, Unexplained, Covers, Hyps)) :-
    case_symptoms(C, Syms),
    findall(S, ( member(sym(S, _, present, _), Syms), \+ context_symptom(S) ), P0),
    sort(P0, Present),
    candidates(Syms, Present, Cands),
    partition(explainable(Syms, Cands), Present, ToCover, Unexplained),
    minimal_covers(Syms, Cands, ToCover, Covers),
    hyp_verdicts(Syms, Cands, Covers, Hyps).

%   Candidates: hypotheses that explain at least one present symptom.
candidates(Syms, Present, Cands) :-
    findall(H, ( member(S, Present), explains(H, S), ground(H) ), H0),
    sort(H0, H1),
    include(admissible(Syms, H1), H1, Cands).

%   A candidate is admissible if each clearly absent symptom it requires
%   could be masked by some other candidate.
admissible(Syms, Pool, H) :-
    forall(blocked_by(Syms, H, S),
           ( member(H2, Pool), H2 \== H, masks(H2, S) )).

blocked_by(Syms, H, S) :-
    requires(H, S),
    sym_status(Syms, S, absent).

explainable(Syms, Cands, S) :-
    member(H, Cands),
    explains(H, S),
    !,
    Syms = Syms.

minimal_covers(_, _, [], [[]]) :- !.
minimal_covers(Syms, Cands, ToCover, Covers) :-
    max_explanation_size(Max),
    between(1, Max, K),
    findall(D, ( subset_of_size(K, Cands, D), covers(D, ToCover), consistent_set(Syms, D) ), Ds),
    Ds \== [],
    !,
    Covers = Ds.
minimal_covers(_, _, _, []).

covers(D, ToCover) :-
    forall(member(S, ToCover), ( member(H, D), explains(H, S) )).

consistent_set(Syms, D) :-
    forall(( member(H, D), blocked_by(Syms, H, S) ),
           ( member(H2, D), H2 \== H, masks(H2, S) )).

%   subset_of_size(+K, +List, -Subset): subsets in list order.
subset_of_size(0, _, []) :- !.
subset_of_size(K, [X|Xs], [X|Ys]) :-
    K1 is K - 1,
    subset_of_size(K1, Xs, Ys).
subset_of_size(K, [_|Xs], Ys) :-
    K > 0,
    subset_of_size(K, Xs, Ys).

%   hyp_conf(+Syms, +H, -Conf, -Support, -Against): Stage 4 Eq. 56.
hyp_conf(Syms, H, Conf, Ep, En) :-
    findall(V, ( evidence(H, S, W), sym_grade(Syms, S, E), V is W * E ), Vs),
    sum_list(Vs, Ep),
    findall(V, ( requires(H, S), evidence(H, S, W), sym_grade(Syms, S, E), V is W * (1 - E) ), Ns),
    sum_list(Ns, En),
    Conf is Ep / (Ep + En + 0.01).

hyp_verdicts(Syms, Cands, Covers, Hyps) :-
    findall(hyp(H, Conf, V),
            ( member(H, Cands),
              hyp_conf(Syms, H, Conf, _, _),
              (   member(D, Covers), memberchk(H, D) -> V = in_explanation
              ;   V = not_needed
              ) ),
            In),
    findall(hyp(H, Conf, rejected(S)),
            ( member(Sy, Syms), Sy = sym(S0, _, present, _), \+ context_symptom(S0),
              explains(H, S0), ground(H), \+ memberchk(H, Cands),
              blocked_by(Syms, H, S),
              hyp_conf(Syms, H, Conf, _, _) ),
            Rej0),
    sort(Rej0, Rej),
    append(In, Rej, Hyps).

%   cover_score(+Syms, +Bonus, +D, -Score): summed confidence, plus Bonus for
%   each hypothesis that the deductive rules also prove.
cover_score(Syms, BonusSet, D, Score) :-
    findall(V, ( member(H, D), hyp_conf(Syms, H, Cf, _, _),
                 ( memberchk(H, BonusSet) -> V is Cf + 0.1 ; V = Cf ) ), Vs),
    sum_list(Vs, Score).

rank_covers(Syms, BonusSet, Covers, Ranked) :-
    findall(Neg-D, ( member(D, Covers), cover_score(Syms, BonusSet, D, Sc), Neg is -Sc ), Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Ranked).
