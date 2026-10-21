/*  engine/prover.pl - proof-recording meta-interpreter.

    prove(+Goal, -Proof)
      Proves Goal against the drule/4 knowledge base and returns a proof
      tree that the explanation facility can read:
        by(RuleId, Goal, SubProofs)   Goal derived by rule RuleId
        leaf(Goal)                    fact, calculation or comparison
        naf(Goal)                     Goal shown false (negation as failure)
*/

derived(cond(_, _)).
derived(fault(_, _)).

prove(\+ G, naf(G)) :-
    !,
    \+ prove(G, _).
prove(G, by(Id, G, SubProofs)) :-
    derived(G),
    !,
    drule(Id, G, Body, _),
    prove_body(Body, SubProofs).
prove(G, leaf(G)) :-
    call(G).

prove_body([], []).
prove_body([G|Gs], [P|Ps]) :-
    prove(G, P),
    prove_body(Gs, Ps).

%   proof_node(+Proof, -Node): enumerate every node of a proof tree.
proof_node(P, P).
proof_node(by(_, _, Ps), N) :-
    member(P, Ps),
    proof_node(P, N).
