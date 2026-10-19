# Module 7 reliability helpers: rules as components, user-level risk, availability.

# @web-start Series and parallel systems
# Parallel system (any component fires): 1 - prod(1 - p), assuming independence.
parallel_prob <- function(p) 1 - prod(1 - p)

# Series system (all components fire): prod(p), assuming independence.
series_prob <- function(p) prod(p)
# @web-end

# Probability a user sees no missed phish in n emails, per-email hazard h.
user_reliability <- function(n, h) (1 - h)^n

mttf_emails <- function(h) 1 / h

availability <- function(mtbf, mttr) mtbf / (mtbf + mttr)
