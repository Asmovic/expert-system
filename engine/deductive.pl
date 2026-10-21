/*  engine/deductive.pl - Stage 8.1 deductive diagnosis, KB u E |= F.

    diagnose(+Case, -Diagnoses)
      Diagnoses is a list of diag(Fault, Proof). One entry per distinct
      fault, keeping the first proof found.
      R30: if no fault rule fires and no rack inlet is hot, the case is
           diagnosed normal under the closed-world assumption.
      R31: if no fault rule fires but some inlet is hot, the result is
           unexplained_abnormality, an honest "the KB does not know".
*/

diagnose(C, Ds) :-
    findall(F-P, prove(fault(C, F), P), Raw),
    dedupe_by_key(Raw, Unique),
    (   Unique == []
    ->  (   prove(cond(C, rack_inlet_hot(_)), _)
        ->  Ds = [diag(unexplained_abnormality, closed_world(r31))]
        ;   Ds = [diag(normal, closed_world(r30))]
        )
    ;   findall(diag(F, P), member(F-P, Unique), Ds)
    ).

%   diagnosed_faults(+Case, -Faults): fault labels only, for testing.
diagnosed_faults(C, Fs) :-
    diagnose(C, Ds),
    findall(F, member(diag(F, _), Ds), Fs).

dedupe_by_key([], []).
dedupe_by_key([K-V|T], [K-V|R]) :-
    exclude(same_key(K), T, T1),
    dedupe_by_key(T1, R).

same_key(K, K2-_) :-
    K2 =@= K.
