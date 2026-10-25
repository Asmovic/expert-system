/*  engine/params.pl - reasoning parameters set by engineering judgement.

    param(+Name, -Value) gives the value in use. The defaults are the values
    behind every reported result. tests/param_sensitivity.pl overrides them
    one at a time with param_override/2 to measure their effect.

      deductive_bonus     added to the confidence of an abductive hypothesis
                          that the deductive rules also prove
      present_sigma       k: a graded symptom is present once its value is k
                          noise standard deviations past the threshold
                          (E >= 0.5 + k/4) and absent at k before it
                          (E =< 0.5 - k/4)
      search_bound        largest explanation (abduction) and largest
                          diagnosis (consistency-based search) considered
      weight_mode         kb: the causal weights in kb/causal.pl
                          uniform: every weight 1
                          perturbed(Seed): each weight times a factor in
                          [0.5, 1.5], fixed per hypothesis and symptom type
      scaled_noise        tied: features without their own redundancy scale
                          their noise with the temperature-sensor noise
                          estimated from the case; fixed: they keep their
                          nominal noise
*/

:- dynamic param_override/2.

param(N, V) :- param_override(N, V0), !, V = V0.
param(N, V) :- param_default(N, V).

param_default(deductive_bonus, 0.1).
param_default(present_sigma,   1.0).
param_default(search_bound,    4).
param_default(weight_mode,     kb).
param_default(scaled_noise,    tied).
