-- =============================================================================
-- Tabby (SaaS) — Practice Exercises
-- =============================================================================
-- Try each before peeking at solutions.sql. Hints are inline as comments.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXERCISE 1 — SCD type choice
-- -----------------------------------------------------------------------------
-- Tabby wants to add a "discount_percent" attribute to dim_account for accounts
-- that have negotiated a lower rate. Should it be SCD Type 1, 2, or 3?
-- Defend your choice in a sentence.
--
-- Hint: Will finance ever need to RECONSTRUCT a historical invoice at the
--       negotiated rate that was in effect at the time? If yes, you need
--       history -> Type 2. If "what's their discount today?" is enough, Type 1.


-- -----------------------------------------------------------------------------
-- EXERCISE 2 — SCD2 as-of lookup
-- -----------------------------------------------------------------------------
-- Write a query against dim_account returning the plan Whisker Labs (ACC_WL)
-- was on as of 2025-05-01. Your result should have exactly ONE row showing
-- plan_id = 'PRO'.
--
-- Hint: DATE '2025-05-01' BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31').


-- -----------------------------------------------------------------------------
-- EXERCISE 3 — Snapshot vs. invoice disagreement
-- -----------------------------------------------------------------------------
-- Whisker Labs upgraded Pro -> Enterprise on 2025-07-15. The July MRR snapshot
-- shows $499 (month-end state). The July invoice shows a $6 proration credit
-- plus a $252 partial-month Enterprise charge. In 2-3 sentences, explain (a)
-- why these differ and (b) which one finance typically prefers for revenue
-- recognition, and why.
--
-- Hint: The snapshot reflects STATE at a point in time (month-end). The
--       invoice reflects CASH that actually changed hands (per accounting
--       rules). Revenue recognition follows the invoice, not the snapshot.


-- -----------------------------------------------------------------------------
-- EXERCISE 4 — Median trial-to-paid (write the SQL)
-- -----------------------------------------------------------------------------
-- Using fact_subscription_lifecycle, write a query that returns the median
-- number of days from trial start to first paid, for subscriptions whose
-- first_paid_date_sk falls in 2025.
--
-- Hint: PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trial_to_paid_days).
--       Filter first_paid_date_sk IS NOT NULL. To restrict to 2025, filter
--       first_paid_date_sk BETWEEN 20250101 AND 20251231.


-- -----------------------------------------------------------------------------
-- EXERCISE 5 — Why separate usage from billing?
-- -----------------------------------------------------------------------------
-- Give TWO distinct reasons why fact_usage_event (collar pings) and
-- fact_invoice_line (billing) should be separate fact tables rather than one
-- combined table.
--
-- Hint: Think about GRAIN (what one row represents) and VOLUME (how many rows
--       per day). Also consider which dimensions each needs.


-- -----------------------------------------------------------------------------
-- EXERCISE 6 — Spot the MRR double-count bug
-- -----------------------------------------------------------------------------
-- A junior analyst proposes that, for an account that upgrades mid-month, the
-- monthly MRR snapshot row should store mrr = old_plan_mrr + new_plan_mrr (both
-- plans' MRR added together for that month). Explain why this is wrong and what
-- the snapshot should store instead.
--
-- Hint: MRR is a STATE, not a flow. At any point in time an account is on
--       exactly one plan. The snapshot should reflect the month-end plan only.


-- -----------------------------------------------------------------------------
-- EXERCISE 7 — Hierarchy rollup
-- -----------------------------------------------------------------------------
-- Using parent_account_id on dim_account, write a query that returns total
-- current MRR per organization, where any account whose parent_account_id is
-- not NULL rolls up to its parent.
--
-- Hint: COALESCE(parent_account_id, account_id) gives you the org key. Join
--       dim_account to itself (or use a CTE) to label orgs.


-- -----------------------------------------------------------------------------
-- EXERCISE 8 — Reactivation modeling
-- -----------------------------------------------------------------------------
-- A customer who churned in September wants to reactivate in November. Should
-- you (a) create a new account_id, or (b) reuse the existing account_id and
-- update the lifecycle fact? Defend your choice, and write the UPDATE that
-- records the reactivation on 2025-11-01 for Purrfect Co (subscription_id
-- 'SUB_PC_001').
--
-- Hint: Reactivation is NOT new business. Reusing the account_id keeps cohort
--       analytics honest. Update reactivated_date_sk, current_status, and
--       optionally zero out paid_to_churn_days.
