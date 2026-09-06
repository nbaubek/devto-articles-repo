-- =============================================================================
-- Tabby (SaaS) — Exercise Solutions
-- =============================================================================
-- Referenced by exercises.sql. Try the exercises first!
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SOLUTION 1 — SCD type choice
-- -----------------------------------------------------------------------------
-- SCD Type 2. Discounts materially affect recognized revenue, and finance
-- needs to know "what discount was this account on when invoice #50040 was
-- issued?" If you overwrite (Type 1), every historical revenue reconstruction
-- would silently use today's discount. Type 2 preserves the negotiated rate
-- as-of any past date.
--
-- (Edge case: if discounts never change after signup and are only ever
--  forward-looking, Type 1 is defensible. But "never change" is a brave claim.)


-- -----------------------------------------------------------------------------
-- SOLUTION 2 — SCD2 as-of lookup
-- -----------------------------------------------------------------------------
SELECT account_id, account_name, plan_id, plan_name, base_mrr, valid_from, valid_to, is_current
FROM dim_account
WHERE account_id = 'ACC_WL'
  AND DATE '2025-05-01' BETWEEN valid_from AND COALESCE(valid_to, DATE '9999-12-31');
-- Expected: account_sk=101, plan_id='PRO', base_mrr=12.00, valid_to='2025-07-14'.


-- -----------------------------------------------------------------------------
-- SOLUTION 3 — Snapshot vs. invoice disagreement
-- -----------------------------------------------------------------------------
-- (a) They differ because the snapshot is a POINT-IN-TIME STATE (month-end:
--     Enterprise, $499) while the invoice is a CASH EVENT (a prorated credit
--     for unused Pro days + a prorated charge for partial Enterprise days).
--     Mid-month plan changes always produce this gap.
--
-- (b) Finance prefers the INVOICE for revenue recognition, because GAAP/IFRS
--     rules require recognizing revenue as it's earned (per the invoice and
--     service-period logic), not as a snapshot of end-state. The snapshot is
--     for operations/CRM/analytics; the invoice is for the audited books.


-- -----------------------------------------------------------------------------
-- SOLUTION 4 — Median trial-to-paid
-- -----------------------------------------------------------------------------
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trial_to_paid_days) AS median_days,
    AVG(trial_to_paid_days)                                          AS mean_days,
    COUNT(*)                                                         AS n
FROM fact_subscription_lifecycle
WHERE first_paid_date_sk IS NOT NULL
  AND first_paid_date_sk BETWEEN 20250101 AND 20251231;
-- Expected from seed: median = 13, mean ~ 6.75 (3 of 4 subscriptions
-- converted same-day or within 2 weeks; Purrfect took 13 days).


-- -----------------------------------------------------------------------------
-- SOLUTION 5 — Why separate usage from billing?
-- -----------------------------------------------------------------------------
-- Reason 1 — GRAIN MISMATCH. fact_invoice_line is one row per invoice line
-- (handfuls per day); fact_usage_event is one row per device ping (millions
-- per day). Combining them means either polluting billing with NULL event
-- columns or polluting events with NULL billing columns.
--
-- Reason 2 — DIMENSIONAL FIT. Usage needs collar_id, workspace_sk, event_type,
-- activity_score. Billing needs invoice_number, line_type, amount. A combined
-- table would have a wide, sparse schema that's painful to query and expensive
-- to store.
--
-- (Bonus reason: separate tables let you tune them differently — partition
--  usage by date, index billing by account.)


-- -----------------------------------------------------------------------------
-- SOLUTION 6 — Spot the MRR double-count bug
-- -----------------------------------------------------------------------------
-- Wrong because MRR is a STATE measure: at any instant, an account is on
-- exactly one plan, so its MRR is exactly one number. Adding both plans'
-- MRR for the transition month would overstate MRR and pollute every
-- downstream metric (NRR, expansion rate, churn rate).
--
-- Correct: the snapshot stores the MONTH-END plan's MRR. For the month of
-- an upgrade, that's the new plan. Expansion MRR (the delta) is captured by
-- comparing this month's snapshot to last month's — NOT by summing two plans.


-- -----------------------------------------------------------------------------
-- SOLUTION 7 — Hierarchy rollup
-- -----------------------------------------------------------------------------
WITH current_accounts AS (
    SELECT account_id, account_name, parent_account_id, base_mrr
    FROM dim_account
    WHERE is_current = true
),
rolled AS (
    SELECT
        COALESCE(parent_account_id, account_id) AS org_id,
        account_id,
        base_mrr
    FROM current_accounts
)
SELECT
    r.org_id,
    MAX(CASE WHEN ca.account_id = r.org_id THEN ca.account_name END) AS org_name,
    COUNT(*)                                     AS accounts_in_org,
    SUM(r.base_mrr)                              AS org_mrr
FROM rolled r
LEFT JOIN current_accounts ca ON ca.account_id = r.org_id
GROUP BY r.org_id
ORDER BY org_mrr DESC;
-- Expected: PetCo Org (parent of ACC_PC and ACC_MC) rolls up to ~$511,
--           Whisker Labs and Tabby HQ stand alone.


-- -----------------------------------------------------------------------------
-- SOLUTION 8 — Reactivation modeling
-- -----------------------------------------------------------------------------
-- (a) Reuse the existing account_id. Reactivation is NOT new business — the
--     account existed, churned, and returned. Creating a new account_id would
--     inflate "new business" metrics and break cohort retention curves. The
--     honest model is: same account, a new milestone on the lifecycle fact.
--
-- (b) The UPDATE (Purrfect Co reactivates on 2025-11-01, date_sk 20251101):
UPDATE fact_subscription_lifecycle
SET reactivated_date_sk = 20251101,
    current_status      = 'REACTIVATED',
    paid_to_churn_days  = NULL        -- they're no longer churned
WHERE subscription_id = 'SUB_PC_001';
--
-- You'd ALSO re-open a new dim_account SCD2 row (or reuse the existing current
-- row if no plan change) and add new fact_subscription_month rows from Nov
-- onward. The lifecycle UPDATE is the headline bookkeeping event.
