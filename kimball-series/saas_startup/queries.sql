-- =============================================================================
-- Tabby (SaaS) — Example Queries (referenced in the article)
-- =============================================================================
-- Run AFTER schema.sql + seed.sql. Each block is self-contained.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. MRR by month (the headline SaaS query, off the periodic snapshot)
-- -----------------------------------------------------------------------------
SELECT
    d.month_name,
    d.year,
    SUM(sm.mrr) AS mrr
FROM fact_subscription_month sm
JOIN dim_date d ON d.date_sk = sm.month_sk
WHERE sm.is_active = true
GROUP BY d.year, d.month_number, d.month_name
ORDER BY d.year, d.month_number;


-- -----------------------------------------------------------------------------
-- Q2. SCD2 "as-of" lookup: what plan was Whisker Labs on, on 2025-05-01?
-- -----------------------------------------------------------------------------
SELECT account_id, account_name, plan_id, plan_name, base_mrr, valid_from, valid_to, is_current
FROM dim_account
WHERE account_id = 'ACC_WL'
  AND DATE '2025-05-01' BETWEEN valid_from AND COALESCE(valid_to, DATE '9999-12-31');
-- Expected: Pro row (sk=101), base_mrr = 12.00.


-- -----------------------------------------------------------------------------
-- Q3. Current-only accounts (the everyday query)
-- -----------------------------------------------------------------------------
SELECT account_id, account_name, plan_name, base_mrr
FROM dim_account
WHERE is_current = true
ORDER BY base_mrr DESC;


-- -----------------------------------------------------------------------------
-- Q4. MRR movement / waterfall (new / expansion / contraction / churn)
-- -----------------------------------------------------------------------------
-- Matches the article: find "last month" by joining through dim_date, NEVER by
-- arithmetic on the encoded key. month_sk - 100 happens to work Feb-Dec but
-- breaks every January (20260101 - 100 = 20260001, which matches nothing), so
-- the prev-month join must resolve via the calendar:
SELECT
    this_mo.month_sk,
    SUM(this_mo.mrr) AS ending_mrr,
    SUM(CASE WHEN prev_mo.account_sk IS NULL THEN this_mo.mrr END) AS new_mrr,
    SUM(CASE WHEN this_mo.mrr > prev_mo.mrr
             THEN this_mo.mrr - prev_mo.mrr END) AS expansion_mrr,
    SUM(CASE WHEN this_mo.mrr < prev_mo.mrr
             THEN prev_mo.mrr - this_mo.mrr END) AS contraction_mrr,
    SUM(CASE WHEN this_mo.is_active = false THEN prev_mo.mrr END) AS churned_mrr
FROM fact_subscription_month this_mo
JOIN dim_date d_this        ON d_this.date_sk = this_mo.month_sk
JOIN dim_date d_prev        ON d_prev.full_date = (d_this.full_date - INTERVAL '1 month')::date
LEFT JOIN fact_subscription_month prev_mo
       ON prev_mo.subscription_id = this_mo.subscription_id
      AND prev_mo.month_sk = d_prev.date_sk
GROUP BY this_mo.month_sk
ORDER BY this_mo.month_sk;
-- Expected highlights:
--   20250101: ending 24,  new 24            (WL + THQ, first month)
--   20250201: ending 36,  new 12            (Purrfect Co joins)
--   20250401: ending 535, new 499           (Meow Corp joins on Enterprise)
--   20250701: ending 1022, expansion 487    (WL Pro -> Enterprise)
--   20250901: ending 1010, churned 12       (Purrfect Co churns)
--   20260101: ending 1010, no movement      <-- the year-boundary proof:
--             the Dec 2025 -> Jan 2026 lookup resolves correctly via dim_date
--             (subtracting 100 from 20260101 would have matched nothing).


-- -----------------------------------------------------------------------------
-- Q5. Net Revenue Retention (NRR) — cohort 12 months apart
-- -----------------------------------------------------------------------------
-- Jan 2025 cohort vs Jan 2026 MRR, matching the article — with ONE critical
-- fix: the cohort must be keyed on the NATURAL key (account_id), not the
-- surrogate (account_sk). dim_account is SCD2, so an account that changed
-- plans gets a NEW surrogate key: Whisker Labs is 101 (Pro) in Jan 2025 but
-- 102 (Enterprise) in Jan 2026. Join the snapshot on account_sk across those
-- two dates and the upgrader silently drops out of the "now" side — NRR
-- collapses to 0.5 instead of ~21.3. Resolve to account_id first.
WITH cohort AS (
    -- Accounts that were active and paying 12 months ago
    SELECT DISTINCT a.account_id
    FROM fact_subscription_month sm
    JOIN dim_account a ON a.account_sk = sm.account_sk
    WHERE sm.month_sk = 20250101 AND sm.mrr > 0
),
mrr_then AS (
    SELECT a.account_id, SUM(sm.mrr) AS mrr_12mo_ago
    FROM fact_subscription_month sm
    JOIN dim_account a ON a.account_sk = sm.account_sk
    WHERE sm.month_sk = 20250101
    GROUP BY a.account_id
),
mrr_now AS (
    SELECT a.account_id, SUM(sm.mrr) AS mrr_current
    FROM fact_subscription_month sm
    JOIN dim_account a ON a.account_sk = sm.account_sk
    WHERE sm.month_sk = 20260101 AND sm.is_active = true
    GROUP BY a.account_id
)
SELECT
    SUM(t.mrr_12mo_ago)                   AS starting_mrr,
    SUM(COALESCE(n.mrr_current, 0))       AS ending_mrr,
    SUM(COALESCE(n.mrr_current, 0)) / SUM(t.mrr_12mo_ago) AS nrr
FROM cohort c
JOIN mrr_then t ON t.account_id = c.account_id
LEFT JOIN mrr_now n ON n.account_id = c.account_id;
-- Expected: starting 24 (WL Pro 12 + THQ Pro 12), ending 511 (WL Enterprise 499
--           + THQ Pro 12), NRR ~21.3x. Wildly outsized because the cohort is
--           two accounts and one upgraded to a 40x plan — the shape of the
--           query is the point, not the number.


-- -----------------------------------------------------------------------------
-- Q6. Accumulating snapshot: trial-to-paid conversion time
-- -----------------------------------------------------------------------------
SELECT
    current_status,
    COUNT(*)                                          AS n,
    AVG(trial_to_paid_days)                           AS avg_trial_to_paid,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trial_to_paid_days) AS median_trial_to_paid
FROM fact_subscription_lifecycle
WHERE first_paid_date_sk IS NOT NULL
GROUP BY current_status;


-- -----------------------------------------------------------------------------
-- Q7. Account hierarchy rollup: MRR by parent organization
-- -----------------------------------------------------------------------------
-- Accounts with parent_account_id roll up to their parent. Top-level accounts
-- count their own MRR directly.
WITH account_current AS (
    SELECT account_id, account_name, parent_account_id, plan_name, base_mrr
    FROM dim_account WHERE is_current = true
),
rolled AS (
    SELECT
        COALESCE(a.parent_account_id, a.account_id) AS org_id,
        a.account_id,
        a.base_mrr
    FROM account_current a
)
SELECT
    org_id,
        CASE WHEN org_id LIKE 'ACC_PETCO%' THEN 'PetCo Org (parent)'
             ELSE (SELECT account_name FROM account_current WHERE account_id = org_id)
        END AS org_name,
    COUNT(*)           AS accounts_in_org,
    SUM(base_mrr)      AS org_mrr
FROM rolled
GROUP BY org_id
ORDER BY org_mrr DESC;


-- -----------------------------------------------------------------------------
-- Q8. Entitlement lookup: which accounts had API access as of Aug 2025?
-- -----------------------------------------------------------------------------
SELECT
    a.account_name,
    a.plan_name,
    e.feature_id,
    d.full_date AS effective
FROM fact_entitlement e
JOIN dim_account a ON a.account_sk = e.account_sk
JOIN dim_date    d ON d.date_sk    = e.effective_date_sk
WHERE e.feature_id = 'API_ACCESS'
  AND e.effective_date_sk <= 20250831
ORDER BY d.full_date;


-- -----------------------------------------------------------------------------
-- Q9. Usage fact: average activity score by account (high-volume table)
-- -----------------------------------------------------------------------------
SELECT
    a.account_name,
    COUNT(*)                                    AS events,
    AVG(u.activity_score)                       AS avg_activity,
    SUM(u.nap_minutes)                          AS total_nap_min
FROM fact_usage_event u
JOIN dim_account a ON a.account_sk = u.account_sk
GROUP BY a.account_name
ORDER BY events DESC;


-- -----------------------------------------------------------------------------
-- Q10. Revenue from invoices vs. MRR snapshot — sanity check
-- -----------------------------------------------------------------------------
-- Compare what was billed (invoices) against the snapshot for a given month.
-- Differences are expected (prorations, usage add-ons) but should be explainable.
SELECT
    'invoice billed' AS source,
    d.month_name,
    SUM(il.amount)   AS amount
FROM fact_invoice_line il
JOIN dim_date d ON d.date_sk = il.invoice_date_sk
WHERE d.month_number = 7 AND d.year = 2025
GROUP BY d.month_name
UNION ALL
SELECT
    'snapshot mrr' AS source,
    d.month_name,
    SUM(sm.mrr)    AS amount
FROM fact_subscription_month sm
JOIN dim_date d ON d.date_sk = sm.month_sk
WHERE d.month_number = 7 AND d.year = 2025 AND sm.is_active = true
GROUP BY d.month_name;
