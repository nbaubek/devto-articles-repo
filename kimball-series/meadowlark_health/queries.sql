-- =============================================================================
-- Meadowlark Health — Example Queries (referenced in the article)
-- =============================================================================
-- Run AFTER schema.sql + seed.sql. Q1/Q2 are the article's wrong-then-right
-- pair for claim line 1001; Q3/Q4 are the article's "real queries."
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. The trap: join fact to bridge and SUM without weighting — DON'T DO THIS
-- -----------------------------------------------------------------------------
-- Expected from seed (claim line 1001, billed $500):
--     E11.9  $500.00
--     Z79.4  $500.00
--     I10    $500.00        <- $1,500 conjured out of a $500 claim
-- The join fans one fact row out into three, and billed_amount rides along
-- unchanged on each. The query runs clean; only the number is wrong.
SELECT d.diagnosis_code, SUM(f.billed_amount) AS total_billed
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk
JOIN dim_diagnosis d           ON d.diagnosis_sk = b.diagnosis_sk
WHERE f.claim_line_sk = 1001
GROUP BY d.diagnosis_code
ORDER BY total_billed DESC;


-- -----------------------------------------------------------------------------
-- Q2. The fix: multiply by the weighting factor before summing
-- -----------------------------------------------------------------------------
-- Expected from seed: E11.9 $250.00, I10 $150.00, Z79.4 $100.00 — the three
-- rows sum back to exactly the $500 billed.
SELECT d.diagnosis_code, SUM(f.billed_amount * b.weighting_factor) AS allocated_billed
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk
JOIN dim_diagnosis d           ON d.diagnosis_sk = b.diagnosis_sk
WHERE f.claim_line_sk = 1001
GROUP BY d.diagnosis_code
ORDER BY allocated_billed DESC;


-- -----------------------------------------------------------------------------
-- Q3. Total billed by diagnosis category, correctly allocated, Q3 2026
--     (the article's headline query — allocation holds in aggregate)
-- -----------------------------------------------------------------------------
-- Expected from seed: ENDOCRINE $960, CARDIOVASCULAR $740, CONTAGIOUS $330,
-- MUSCULOSKELETAL $320 — total $2,350 = SUM(billed_amount) of all 8 lines.
-- That reconciliation is the sanity check: allocated totals must add back
-- to what was actually billed.
SELECT
    d.diagnosis_category,
    SUM(f.billed_amount * b.weighting_factor) AS allocated_billed
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk
JOIN dim_diagnosis d           ON d.diagnosis_sk = b.diagnosis_sk
JOIN dim_date dt                ON dt.date_sk = f.service_date_sk
WHERE dt.quarter = 3 AND dt.year = 2026
GROUP BY d.diagnosis_category
ORDER BY allocated_billed DESC;


-- -----------------------------------------------------------------------------
-- Q4. Members covered under a policy — membership bridge, plain join
-- -----------------------------------------------------------------------------
-- Expected from seed: the four Petersons (SUBSCRIBER/SPOUSE/DEPENDENT/
-- DEPENDENT). No weighting factor anywhere: nothing numeric fans out.
SELECT m.member_name, bp.relationship
FROM bridge_policy_member bp
JOIN dim_member m ON m.member_sk = bp.member_sk
WHERE bp.policy_sk = 1
ORDER BY bp.relationship, m.member_name;


-- -----------------------------------------------------------------------------
-- Q5. In-network providers per plan, as of 2026-08-15 (factless fact)
-- -----------------------------------------------------------------------------
-- Expected from seed: PPO Gold 3 (Alvarez, Chen, Okafor), HMO Silver 1
-- (Alvarez), PPO Bronze 2 (Chen, Okafor). Reyes doesn't appear — his
-- coverage rows are effective 2026-09-01, after the as-of date. The row's
-- EXISTENCE is the fact; the as-of filter is the "as of" logic.
SELECT
    pr.plan_name,
    COUNT(*) AS in_network_providers
FROM fact_network_coverage nc
JOIN dim_plan     pr ON pr.plan_sk = nc.plan_sk
JOIN dim_provider p  ON p.provider_sk = nc.provider_sk
WHERE nc.effective_date_sk <= 20260815
GROUP BY pr.plan_name
ORDER BY in_network_providers DESC;
