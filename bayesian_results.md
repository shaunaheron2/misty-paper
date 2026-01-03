## Eligible Sample HRI
We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, nars_pre_c and
native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model
included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)).
Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00,
σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and b_native_englishNonMNativeEnglish ~
Normal(μ = 0.00, σ = 10.00). The model's explanatory power is substantial (R2 = 0.64, 95% CI
[0.59, 0.68], adj. R2 = 0.61) and the part related to the fixed effects alone (marginal R2) is
of 0.16 (95% CI [0.03, 0.29]). Within this model:

  - The effect of b Intercept (Median = 66.58, 95% CI [57.41, 75.69]) has a 100.00% probability
of being positive (> 0), 100.00% of being significant (> 1.15), and 100.00% of being large (>
6.88). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS
= 4982)
  - The effect of b groupRESPONSIVE (Median = 12.73, 95% CI [2.93, 22.17]) has a 99.38%
probability of being positive (> 0), 98.99% of being significant (> 1.15), and 88.67% of being
large (> 6.88). The estimation successfully converged (Rhat = 1.001) and the indices are
reliable (ESS = 5325)
  - The effect of b nars pre c (Median = -3.85, 95% CI [-9.46, 1.71]) has a 91.38% probability
of being negative (< 0), 83.44% of being significant (< -1.15), and 14.08% of being large (<
-6.88). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS
= 4578)
  - The effect of b native englishNonMNativeEnglish (Median = -10.38, 95% CI [-20.53, -0.05])
has a 97.54% probability of being negative (< 0), 96.08% of being significant (< -1.15), and
75.62% of being large (< -6.88). The estimation successfully converged (Rhat = 1.000) and the
indices are reliable (ESS = 4958)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we
report the median of the posterior distribution and its 95% CI (Highest Density Interval),
along the probability of direction (pd), the probability of significance and the probability
of being large. The thresholds beyond which the effect is considered as significant (i.e.,
non-negligible) and large are |1.15| and |6.88| (corresponding respectively to 0.05 and 0.30
of the outcome's SD). Convergence and stability of the Bayesian sampling has been assessed
using R-hat, which should be below 1.01 (Vehtari et al., 2019), and Effective Sample Size
(ESS), which should be greater than 1000 (Burkner, 2017).

## Eligible Sample HRC

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000 iterations and a warmup of 1000) to predict robot_trust_post with group,
nars_pre_c and native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model included session_id as random effects (formula: list(~1 |
session_id, ~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ
= 10.00) and b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power is substantial (R2 = 0.42, 95% CI [0.32, 0.50], adj. R2 = 0.37)
and the part related to the fixed effects alone (marginal R2) is of 0.21 (95% CI [0.09, 0.32]). Within this model:

  - The effect of b Intercept (Median = 63.27, 95% CI [56.04, 70.61]) has a 100.00% probability of being positive (> 0), 100.00% of being significant (> 1.12), and 100.00% of
being large (> 6.74). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 7280)
  - The effect of b groupRESPONSIVE (Median = 14.86, 95% CI [7.20, 22.09]) has a 99.98% probability of being positive (> 0), 99.94% of being significant (> 1.12), and 98.02%
of being large (> 6.74). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6609)
  - The effect of b nars pre c (Median = -6.95, 95% CI [-11.10, -2.75]) has a 99.91% probability of being negative (< 0), 99.65% of being significant (< -1.12), and 54.42% of
being large (< -6.74). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6210)
  - The effect of b native englishNonMNativeEnglish (Median = -7.78, 95% CI [-15.60, 0.39]) has a 96.90% probability of being negative (< 0), 94.45% of being significant (<
-1.12), and 60.02% of being large (< -6.74). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6556)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the median of the posterior distribution and its 95% CI (Highest Density
Interval), along the probability of direction (pd), the probability of significance and the probability of being large. The thresholds beyond which the effect is considered
as significant (i.e., non-negligible) and large are |1.12| and |6.74| (corresponding respectively to 0.05 and 0.30 of the outcome's SD). Convergence and stability of the
Bayesian sampling has been assessed using R-hat, which should be below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than 1000
(Burkner, 2017).

## Full Sample HRI

## Full Sample HRC