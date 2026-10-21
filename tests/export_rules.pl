/*  tests/export_rules.pl - writes the diagnostic-rule and provenance tables
    straight from the knowledge base, so the report tables always match the code.

    Run from the project folder:
        swipl -g "export_rules('docs/07_rule_table.md')" -t halt main.pl tests/export_rules.pl
*/

export_rules(File) :-
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       write_tables(S),
                       close(S)).

write_tables(S) :-
    format(S, "# Diagnostic Rule and Provenance Tables~n~n", []),
    format(S, "Generated from `kb/rules.pl`, `kb/thresholds.pl` and `kb/sources.pl` by `tests/export_rules.pl`. Do not edit by hand.~n~n", []),
    format(S, "Variables are written as capital letters. In each row `A` is the case being diagnosed. `\\+` is negation as failure.~n~n", []),
    format(S, "## Diagnostic rules~n~n| Rule | Concludes | If all of these hold | Source | Source type |~n|---|---|---|---|---|~n", []),
    forall(drule(Id, Head, Body, Src),
           ( source(Src, Type, _),
             copy_term(Head-Body, H-B),
             numbervars(H-B, 0, _),
             head_text(H, HT),
             body_text(B, BT),
             format(S, "| ~w | ~w | ~w | ~w | ~w |~n", [Id, HT, BT, Src, Type]) )),
    format(S, "~nRules r30 and r31 are the closed-world conclusions in `engine/deductive.pl`. r30 concludes normal when no fault rule fires and every rack inlet is within the envelope. r31 concludes an unexplained abnormality otherwise.~n", []),
    format(S, "~n## Thresholds~n~n| Name | Value | Unit | Source |~n|---|---|---|---|~n", []),
    forall(threshold(N, V, U, Src), format(S, "| ~w | ~w | ~w | ~w |~n", [N, V, U, Src])),
    format(S, "~n## Sources~n~n| Id | Type | Citation |~n|---|---|---|~n", []),
    forall(source(Id, Type, Cit), format(S, "| ~w | ~w | ~w |~n", [Id, Type, Cit])),
    aggregate_all(count, drule(_, _, _, _), NR),
    aggregate_all(count, (drule(_, _, _, Src), source(Src, assumption, _)), NA),
    format(S, "~n~d rules in total. ~d of them rest on a source of type assumption and need justification in the report.~n", [NR, NA]).

head_text(H, T) :-
    (   H = cond(_, X) -> Kind = condition
    ;   H = fault(_, X) -> Kind = fault
    ),
    format(atom(T), "~w `~W`", [Kind, X, [numbervars(true), quoted(false)]]).

body_text(B, T) :-
    maplist([G, A]>>format(atom(A), "`~W`", [G, [numbervars(true), quoted(false)]]), B, As),
    atomic_list_concat(As, ', ', T).
