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

## Sensitivity Full Sample HRI

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, nars_pre_c and
native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model
included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)). Priors
were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00),
b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00,
σ = 10.00). The model's explanatory power is substantial (R2 = 0.44, 95% CI [0.35, 0.51], adj. R2 =
0.39) and the part related to the fixed effects alone (marginal R2) is of 0.09 (95% CI [0.01,
0.19]). Within this model:

  - The effect of b Intercept (Median = 67.01, 95% CI [58.14, 76.14]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.18), and 100.00% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6125)
  - The effect of b groupRESPONSIVE (Median = 7.04, 95% CI [-1.83, 15.67]) has a 94.09% probability
of being positive (> 0), 90.56% of being significant (> 1.18), and 49.84% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 6090)
  - The effect of b nars pre c (Median = -5.56, 95% CI [-10.60, -0.69]) has a 98.66% probability of
being negative (< 0), 96.38% of being significant (< -1.18), and 27.07% of being large (< -7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 5852)
  - The effect of b native englishNonMNativeEnglish (Median = -4.96, 95% CI [-13.93, 4.50]) has a
85.43% probability of being negative (< 0), 78.63% of being significant (< -1.18), and 32.27% of
being large (< -7.06). The estimation successfully converged (Rhat = 1.001) and the indices are
reliable (ESS = 5963)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.18| and |7.06| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than
1000 (Burkner, 2017).

## Sensitivity Full Sample HRC

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, nars_pre_c and
native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model
included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)). Priors
were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00),
b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00,
σ = 10.00). The model's explanatory power is substantial (R2 = 0.60, 95% CI [0.56, 0.65], adj. R2 =
0.58) and the part related to the fixed effects alone (marginal R2) is of 0.10 (95% CI [0.01,
0.21]). Within this model:

  - The effect of b Intercept (Median = 69.85, 95% CI [60.70, 78.78]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.13), and 100.00% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 4830)
  - The effect of b groupRESPONSIVE (Median = 7.17, 95% CI [-1.97, 16.70]) has a 93.85% probability
of being positive (> 0), 90.23% of being significant (> 1.13), and 53.29% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 4640)
  - The effect of b nars pre c (Median = -3.80, 95% CI [-8.95, 1.47]) has a 92.45% probability of
being negative (< 0), 84.58% of being significant (< -1.13), and 12.38% of being large (< -6.78).
The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 4583)
  - The effect of b native englishNonMNativeEnglish (Median = -9.48, 95% CI [-18.97, 0.09]) has a
97.35% probability of being negative (< 0), 95.52% of being significant (< -1.13), and 71.58% of
being large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are
reliable (ESS = 4814)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.13| and |6.78| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than
1000 (Burkner, 2017).

## Mechanism ANalysis Full Sample HRI

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, prop_comm_breakdown,
nars_pre_c and native_english (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c
+ native_english). The model included session_id as random effects (formula: list(~1 | session_id,
~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~
Normal(μ = 0.00, σ = 10.00), b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~
Normal(μ = 0.00, σ = 10.00), b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00, σ = 10.00) and
b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power
is substantial (R2 = 0.60, 95% CI [0.55, 0.65], adj. R2 = 0.58) and the part related to the fixed
effects alone (marginal R2) is of 0.11 (95% CI [0.01, 0.21]). Within this model:

  - The effect of b Intercept (Median = 69.48, 95% CI [59.56, 79.18]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.13), and 100.00% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 4769)
  - The effect of b groupRESPONSIVE (Median = 7.43, 95% CI [-2.75, 17.52]) has a 92.42% probability
of being positive (> 0), 89.25% of being significant (> 1.13), and 55.34% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 8739)
  - The effect of b prop comm breakdown (Median = 0.96, 95% CI [-15.55, 17.49]) has a 54.26%
probability of being positive (> 0), 49.25% of being significant (> 1.13), and 24.30% of being
large (> 6.78). The estimation successfully converged (Rhat = 1.001) and the indices are reliable
(ESS = 4540)
  - The effect of b nars pre c (Median = -3.87, 95% CI [-8.99, 1.34]) has a 92.66% probability of
being negative (< 0), 84.37% of being significant (< -1.13), and 13.13% of being large (< -6.78).
The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 4599)
  - The effect of b native englishNonMNativeEnglish (Median = -9.44, 95% CI [-20.20, 1.34]) has a
95.91% probability of being negative (< 0), 93.94% of being significant (< -1.13), and 68.97% of
being large (< -6.78). The estimation successfully converged (Rhat = 1.001) and the indices are
reliable (ESS = 5206)
  - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -1.14, 95% CI [-18.87, 16.28])
has a 55.06% probability of being negative (< 0), 50.03% of being significant (< -1.13), and 26.58%
of being large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are
reliable (ESS = 8840)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.13| and |6.78| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than
1000 (Burkner, 2017).

HRI (only group and comms)

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, prop_comm_breakdown and
nars_pre_c (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c). The model
included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)). Priors
were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00),
b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and
b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power
is substantial (R2 = 0.60, 95% CI [0.56, 0.65], adj. R2 = 0.58) and the part related to the fixed
effects alone (marginal R2) is of 0.07 (95% CI [2.53e-03, 0.16]). Within this model:

  - The effect of b Intercept (Median = 65.76, 95% CI [56.70, 74.97]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.13), and 100.00% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 4211)
  - The effect of b groupRESPONSIVE (Median = 8.50, 95% CI [-1.64, 18.68]) has a 95.11% probability
of being positive (> 0), 92.25% of being significant (> 1.13), and 63.10% of being large (> 6.78).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 8519)
  - The effect of b prop comm breakdown (Median = -4.60, 95% CI [-20.15, 10.97]) has a 72.28%
probability of being negative (< 0), 67.13% of being significant (< -1.13), and 39.02% of being
large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are reliable
(ESS = 4436)
  - The effect of b nars pre c (Median = -2.46, 95% CI [-7.65, 2.86]) has a 82.27% probability of
being negative (< 0), 69.19% of being significant (< -1.13), and 5.13% of being large (< -6.78).
The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 3461)
  - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -3.76, 95% CI [-20.71, 13.39])
has a 66.22% probability of being negative (< 0), 61.41% of being significant (< -1.13), and 36.44%
of being large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are
reliable (ESS = 6275)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.13| and |6.78| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than

## Mechanism ANalysis Full Sample HRC

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, prop_comm_breakdown,
nars_pre_c and native_english (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c
+ native_english). The model included session_id as random effects (formula: list(~1 | session_id,
~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~
Normal(μ = 0.00, σ = 10.00), b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~
Normal(μ = 0.00, σ = 10.00), b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00, σ = 10.00) and
b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power
is substantial (R2 = 0.44, 95% CI [0.35, 0.51], adj. R2 = 0.39) and the part related to the fixed
effects alone (marginal R2) is of 0.10 (95% CI [0.01, 0.19]). Within this model:

  - The effect of b Intercept (Median = 65.75, 95% CI [56.40, 75.01]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.18), and 100.00% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 7585)
  - The effect of b groupRESPONSIVE (Median = 8.59, 95% CI [-0.79, 18.07]) has a 96.46% probability
of being positive (> 0), 94.08% of being significant (> 1.18), and 62.83% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 12543)
  - The effect of b prop comm breakdown (Median = 6.03, 95% CI [-10.62, 22.71]) has a 75.72%
probability of being positive (> 0), 71.49% of being significant (> 1.18), and 45.01% of being
large (> 7.06). The estimation successfully converged (Rhat = 1.001) and the indices are reliable
(ESS = 7260)
  - The effect of b nars pre c (Median = -5.72, 95% CI [-10.46, -0.88]) has a 98.86% probability of
being negative (< 0), 96.71% of being significant (< -1.18), and 28.62% of being large (< -7.06).
The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 6226)
  - The effect of b native englishNonMNativeEnglish (Median = -5.78, 95% CI [-15.73, 4.49]) has a
86.81% probability of being negative (< 0), 81.36% of being significant (< -1.18), and 39.84% of
being large (< -7.06). The estimation successfully converged (Rhat = 1.000) and the indices are
reliable (ESS = 7764)
  - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -5.97, 95% CI [-23.01, 10.92])
has a 75.59% probability of being negative (< 0), 71.23% of being significant (< -1.18), and 44.85%
of being large (< -7.06). The estimation successfully converged (Rhat = 1.000) and the indices are
reliable (ESS = 10929)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.18| and |7.06| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than
1000 (Burkner, 2017).

HRC (only group and comms)

We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000
iterations and a warmup of 1000) to predict robot_trust_post with group, prop_comm_breakdown and
nars_pre_c (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c). The model
included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)). Priors
were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00),
b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and
b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power
is substantial (R2 = 0.44, 95% CI [0.35, 0.51], adj. R2 = 0.39) and the part related to the fixed
effects alone (marginal R2) is of 0.08 (95% CI [7.21e-03, 0.17]). Within this model:

  - The effect of b Intercept (Median = 63.68, 95% CI [55.33, 72.29]) has a 100.00% probability of
being positive (> 0), 100.00% of being significant (> 1.18), and 100.00% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6595)
  - The effect of b groupRESPONSIVE (Median = 9.44, 95% CI [-0.49, 18.77]) has a 96.96% probability
of being positive (> 0), 95.16% of being significant (> 1.18), and 68.82% of being large (> 7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 10419)
  - The effect of b prop comm breakdown (Median = 2.10, 95% CI [-13.34, 16.80]) has a 60.72%
probability of being positive (> 0), 54.66% of being significant (> 1.18), and 26.22% of being
large (> 7.06). The estimation successfully converged (Rhat = 1.001) and the indices are reliable
(ESS = 6664)
  - The effect of b nars pre c (Median = -4.87, 95% CI [-9.60, -0.20]) has a 97.94% probability of
being negative (< 0), 93.88% of being significant (< -1.18), and 17.57% of being large (< -7.06).
The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 5964)
  - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -7.87, 95% CI [-24.67, 9.21]) has
a 81.35% probability of being negative (< 0), 77.62% of being significant (< -1.18), and 53.66% of
being large (< -7.06). The estimation successfully converged (Rhat = 1.001) and the indices are
reliable (ESS = 8990)

Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the
median of the posterior distribution and its 95% CI (Highest Density Interval), along the
probability of direction (pd), the probability of significance and the probability of being large.
The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and
large are |1.18| and |7.06| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be
below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than
1000 (Burkner, 2017).