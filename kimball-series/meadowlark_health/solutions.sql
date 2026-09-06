-- =============================================================================
-- Meadowlark Health — Exercise Solutions
-- =============================================================================
-- Referenced by exercises.sql. Try the exercises first!
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SOLUTION 1 — Single diagnosis: bridge or direct FK?
-- -----------------------------------------------------------------------------
-- Keep the bridge for every line, including single-diagnosis ones. Two
-- reasons. First, consistency: if some rows point at dim_diagnosis and
-- others at a group key, every downstream query needs TWO code paths (or a
-- UNION) forever — one of them silently forgotten the day someone writes a
-- new dashboard. Second, the modeling insight: "one diagnosis" is just a
-- group of size one (groups 10/40/60 in the seed, weighting_factor 1.000).
-- The seed's claim 1002 works through the exact same join as claim 1001,
-- and a fourth diagnosis on any future claim is a new bridge row, not a
-- schema change.
--
-- (Storage savings from a special case are trivial; query-consistency is
-- not. This is the article's Exercise 1 answer.)


-- -----------------------------------------------------------------------------
-- SOLUTION 2 — Predict the bug, then fix it
-- -----------------------------------------------------------------------------
-- (a) $4,680. The fan-out multiplies each line by its group's row count:
--     1001: 500×3 (group 20)  = 1500     1005: 320×1 (group 40) = 320
--     1002: 240×1 (group 10)  =  240     1006: 150×2 (group 30) = 300
--     1003: 180×2 (group 30)  =  360     1007: 260×1 (group 60) = 260
--     1004: 400×2 (group 50)  =  800     1008: 300×3 (group 20) = 900
--     $2,350 of real billing inflates to $4,680 — $2,330 invented, and the
--     query throws no error. Verify it yourself:
SELECT SUM(f.billed_amount) AS inflated_total
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk;
-- Expected: 4680.00

-- (b) The one-row version that returns exactly $2,350 — two options:
-- Weights (allocates each line's dollars across its codes, summing back):
SELECT SUM(f.billed_amount * b.weighting_factor) AS total_billed
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk;
-- Expected: 2350.00

-- Or don't touch the bridge at all when you just need the fact-table total:
SELECT SUM(billed_amount) AS total_billed FROM fact_claim_line;
-- Expected: 2350.00


-- -----------------------------------------------------------------------------
-- SOLUTION 3 — The impact report
-- -----------------------------------------------------------------------------
SELECT
    SUM(f.billed_amount) AS impact_billed_amount_do_not_reconcile_to_gl
FROM fact_claim_line f
JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk
JOIN dim_diagnosis d           ON d.diagnosis_sk = b.diagnosis_sk
WHERE d.diagnosis_category = 'CONTAGIOUS';
-- Expected: $660 — claim 1003 ($180) counted TWICE (J06.9 + B34.9) and
-- claim 1006 ($150) counted twice: 2×180 + 2×150. That's the intent: "this
-- much billing activity involved a contagious condition," not "this much
-- money was caused by one." The alarming column name is part of the
-- deliverable — an intentionally inflated total must be labeled as one.


-- -----------------------------------------------------------------------------
-- SOLUTION 4 — Both codes together
-- -----------------------------------------------------------------------------
-- (a) Groups carrying both codes, then the fact total once per claim line:
SELECT SUM(f.billed_amount) AS billed_with_both_codes
FROM fact_claim_line f
WHERE f.diagnosis_group_sk IN (
    SELECT diagnosis_group_sk
    FROM bridge_diagnosis_group
    WHERE diagnosis_sk IN (1, 2)              -- E11.9, I10
    GROUP BY diagnosis_group_sk
    HAVING COUNT(DISTINCT diagnosis_sk) = 2
);
-- Expected: $1,200 = 500 (1001, group 20) + 400 (1004, group 50)
--            + 300 (1008, group 20). Each claim counted ONCE.

-- Equivalent INTERSECT shape:
--   SELECT diagnosis_group_sk FROM bridge_diagnosis_group WHERE diagnosis_sk = 1
--   INTERSECT
--   SELECT diagnosis_group_sk FROM bridge_diagnosis_group WHERE diagnosis_sk = 2;

-- (b) The question is about CLAIMS, not codes: "how much was billed for
-- claims that carry both" wants the full billed_amount of each such claim,
-- once. The weighted sum ($1,040) slices each claim into per-code shares —
-- answering a question nobody asked ("the E11.9-ish and I10-ish portions of
-- those claims") — and the unweighted-through-the-bridge version ($2,400:
-- 500+500 for 1001, 400+400 for 1004, 300+300 for 1008) counts each claim
-- once per matching code row. Neither is "allocated truth" because no
-- allocation is involved at all: the claim's dollars belong to the claim,
-- and the correct measure is the plain, unweighted, un-fanned SUM over
-- claim lines.


-- -----------------------------------------------------------------------------
-- SOLUTION 5 — Weight-integrity check
-- -----------------------------------------------------------------------------
SELECT
    diagnosis_group_sk,
    SUM(weighting_factor) AS weight_sum,
    COUNT(*)              AS group_size
FROM bridge_diagnosis_group
GROUP BY diagnosis_group_sk
HAVING ABS(SUM(weighting_factor) - 1.0) > 0.001
ORDER BY diagnosis_group_sk;
-- Expected: group 70, weight_sum = 1.400. Any claim routed through that
-- group would over-allocate by 40% — which is exactly why the check belongs
-- in the ETL, not in a code review. The 0.001 tolerance (not = 1.0) avoids
-- false positives from floating-point representation; NUMERIC(4,3) is exact
-- here, but the tolerance is cheap insurance if the column type ever
-- changes to float/double in a port.

-- A stricter companion check — claims pointing at groups that don't exist.
-- This one is NOT optional: the composite bridge PK makes a declared FK from
-- the fact impossible (see schema.sql), so this check IS the referential
-- integrity for diagnosis_group_sk:
SELECT f.claim_line_sk, f.diagnosis_group_sk
FROM fact_claim_line f
LEFT JOIN bridge_diagnosis_group b ON b.diagnosis_group_sk = f.diagnosis_group_sk
WHERE b.diagnosis_group_sk IS NULL;
-- Expected: no rows.


-- -----------------------------------------------------------------------------
-- SOLUTION 6 — Membership bridge vs. weighted bridge
-- -----------------------------------------------------------------------------
-- (a)
SELECT m.member_name, m.member_id, bp.relationship
FROM bridge_policy_member bp
JOIN dim_member m ON m.member_sk = bp.member_sk
WHERE bp.policy_sk = 2
ORDER BY m.member_name;
-- Expected: Linh Nguyen (SUBSCRIBER), Mai Nguyen (SPOUSE).

-- (b) No weighting factor because no numeric measure from a fact table
-- passes through this bridge — "who is covered" is a membership list, and
-- summing anything across dependents would invent numbers the way the
-- unweighted diagnosis join invents dollars. You'd be forced to add weights
-- the moment a real question needs dollars SPLIT across members — e.g. if
-- Meadowlark had to allocate a per-policy premium fact across covered
-- dependents for per-member cost accounting. Absent that question, a
-- weighting_factor column here is an invitation for someone to multiply by
-- it out of habit (the article's mistake #2).


-- -----------------------------------------------------------------------------
-- SOLUTION 7 — Factless fact, as-of
-- -----------------------------------------------------------------------------
-- (a)
SELECT pr.plan_name, nc.effective_date_sk
FROM fact_network_coverage nc
JOIN dim_plan pr ON pr.plan_sk = nc.plan_sk
JOIN dim_provider p ON p.provider_sk = nc.provider_sk
WHERE p.provider_name = 'Dr. Sofia Reyes'
  AND nc.effective_date_sk <= 20260815;
-- Expected: ZERO rows. Run the same with <= 20260915 and you get PPO Gold
-- and HMO Silver, both effective 2026-09-01. They differ because network
-- membership is a STATE that changes over time — the factless rows record
-- when a relationship became true, and the as-of filter reconstructs the
-- network as it stood on any date (same "as-of" logic as SCD2 lookups,
-- expressed through row existence instead of valid_from/valid_to).

-- (b) Not meaningful. In-network provider count is a stock (semi-additive):
-- summing 12 monthly counts mostly re-counts providers who were in-network
-- all year — the annual "total" is neither headcount nor anything else
-- anyone asked for. The meaningful annual figures are averages (typical
-- network size) or a point-in-time count (year-end network), the same
-- distinction as Part 3's in-transit orders.


-- -----------------------------------------------------------------------------
-- SOLUTION 8 — Bridge on top of Type 2 dimensions
-- -----------------------------------------------------------------------------
-- If dim_diagnosis goes Type 2, the diagnosis_sk in the bridge stops being
-- "the code" and becomes "the code's version." Three consequences:
--   1. The bridge must carry the SURROGATE key of the version that was in
--      effect — which means bridge rows themselves need effective ranges
--      (or re-issue dates) whenever a group's member code gets re-versioned.
--   2. Historical allocation queries must resolve the bridge AS OF the
--      claim's service date: a 2024 claim should allocate through the 2024
--      description/category row, not today's — the same SCD2 "as-of" join
--      from Parts 1-2, one hop further away.
--   3. Do nothing and the quiet failure is the article's mistake #5:
--      yesterday's claims report against TODAY'S descriptions. If a code's
--      category was reclassified (say Z79.4 moves categories), every
--      historical category allocation silently changes the next time
--      someone runs it — reports stop being reproducible, which for
--      financial allocation is disqualifying.
-- Kimball's bank-account note in the article is the same warning: bridges
-- over Type 2 dimensions inherit the as-of discipline on BOTH sides.
