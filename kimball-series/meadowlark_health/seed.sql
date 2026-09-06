-- =============================================================================
-- Meadowlark Health — Sample Data
-- =============================================================================
-- Small, hand-crafted so every query in queries.sql has a story:
--   * Claim line 1001 is the article's worked example ($500 across
--     E11.9 / I10 / Z79.4 at 0.5 / 0.3 / 0.2).
--   * Groups 10/40/60 are size-one groups (weight 1.000) — a single
--     diagnosis is just a group of one.
--   * Group 70 is DELIBERATELY BROKEN (weights sum to 1.400) and is
--     referenced by no claim — it exists for the data-quality exercise.
--   * The Peterson family (POL_9001) shows a 4-member membership bridge.
-- Run AFTER schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date — the Q3 2026 dates referenced by claims and network coverage
-- -----------------------------------------------------------------------------
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_number, month_number, month_name, quarter, year, is_weekend, holiday_name) VALUES
    (20260701, '2026-07-01', 'Wednesday', 1, 7, 'July',     3, 2026, false, NULL),
    (20260710, '2026-07-10', 'Friday',   10, 7, 'July',     3, 2026, false, NULL),
    (20260722, '2026-07-22', 'Wednesday',22, 7, 'July',     3, 2026, false, NULL),
    (20260728, '2026-07-28', 'Tuesday',  28, 7, 'July',     3, 2026, false, NULL),
    (20260801, '2026-08-01', 'Saturday',  1, 8, 'August',   3, 2026, true,  NULL),
    (20260805, '2026-08-05', 'Wednesday', 5, 8, 'August',   3, 2026, false, NULL),
    (20260812, '2026-08-12', 'Wednesday',12, 8, 'August',   3, 2026, false, NULL),
    (20260820, '2026-08-20', 'Thursday', 20, 8, 'August',   3, 2026, false, NULL),
    (20260901, '2026-09-01', 'Tuesday',   1, 9, 'September',3, 2026, false, NULL),
    (20260903, '2026-09-03', 'Thursday',  3, 9, 'September',3, 2026, false, NULL),
    (20260915, '2026-09-15', 'Tuesday',  15, 9, 'September',3, 2026, false, NULL);

-- -----------------------------------------------------------------------------
-- dim_member
-- -----------------------------------------------------------------------------
INSERT INTO dim_member (member_sk, member_id, member_name, birth_date, home_city, home_state) VALUES
    (1, 'MEM_001', 'Bob Peterson',   '1968-03-12', 'Springfield', 'IL'),
    (2, 'MEM_002', 'Helen Peterson', '1970-07-30', 'Springfield', 'IL'),
    (3, 'MEM_003', 'Mia Peterson',   '2012-09-18', 'Springfield', 'IL'),
    (4, 'MEM_004', 'Leo Peterson',   '2015-05-04', 'Springfield', 'IL'),
    (5, 'MEM_005', 'Linh Nguyen',    '1985-11-02', 'Portland',    'OR'),
    (6, 'MEM_006', 'Mai Nguyen',     '1987-01-25', 'Portland',    'OR'),
    (7, 'MEM_007', 'Dana Cole',      '1992-06-08', 'Boise',       'ID');

-- -----------------------------------------------------------------------------
-- dim_provider
-- -----------------------------------------------------------------------------
INSERT INTO dim_provider (provider_sk, provider_id, provider_name, specialty, city, state) VALUES
    (1, 'PROV_001', 'Dr. Alma Alvarez', 'Family Medicine',  'Springfield', 'IL'),
    (2, 'PROV_002', 'Dr. Henry Chen',   'Endocrinology',    'Portland',    'OR'),
    (3, 'PROV_003', 'Dr. Grace Okafor', 'Internal Medicine','Boise',       'ID'),
    (4, 'PROV_004', 'Dr. Sofia Reyes',  'Pediatrics',       'Portland',    'OR');

-- -----------------------------------------------------------------------------
-- dim_diagnosis — ICD-10 codes with a category the queries can group by
-- -----------------------------------------------------------------------------
INSERT INTO dim_diagnosis (diagnosis_sk, diagnosis_code, diagnosis_desc, diagnosis_category) VALUES
    (1, 'E11.9', 'Type 2 diabetes mellitus without complications', 'ENDOCRINE'),
    (2, 'I10',   'Essential (primary) hypertension',               'CARDIOVASCULAR'),
    (3, 'Z79.4', 'Long term (current) use of insulin',             'ENDOCRINE'),
    (4, 'J06.9', 'Acute upper respiratory infection, unspecified', 'CONTAGIOUS'),
    (5, 'B34.9', 'Viral infection, unspecified',                   'CONTAGIOUS'),
    (6, 'M54.5', 'Low back pain',                                  'MUSCULOSKELETAL');

-- -----------------------------------------------------------------------------
-- dim_plan / dim_policy
-- -----------------------------------------------------------------------------
INSERT INTO dim_plan (plan_sk, plan_id, plan_name, network_type) VALUES
    (1, 'PPO_GOLD',   'PPO Gold',   'PPO'),
    (2, 'HMO_SILVER', 'HMO Silver', 'HMO'),
    (3, 'PPO_BRONZE', 'PPO Bronze', 'PPO');

INSERT INTO dim_policy (policy_sk, policy_id, group_name, plan_sk, effective_date) VALUES
    (1, 'POL_9001', 'Fairview Logistics (employer group)', 1, '2026-01-01'),
    (2, 'POL_9002', 'Cedar Ridge Schools (employer group)',2, '2026-01-01'),
    (3, 'POL_9003', 'Individual — Dana Cole',              3, '2026-04-01');

-- -----------------------------------------------------------------------------
-- bridge_policy_member — pure membership, NO weighting factor
-- -----------------------------------------------------------------------------
INSERT INTO bridge_policy_member (policy_sk, member_sk, relationship) VALUES
    (1, 1, 'SUBSCRIBER'),   -- Bob
    (1, 2, 'SPOUSE'),       -- Helen
    (1, 3, 'DEPENDENT'),    -- Mia
    (1, 4, 'DEPENDENT'),    -- Leo
    (2, 5, 'SUBSCRIBER'),   -- Linh
    (2, 6, 'SPOUSE'),       -- Mai
    (3, 7, 'SUBSCRIBER');   -- Dana

-- -----------------------------------------------------------------------------
-- bridge_diagnosis_group — groups 10..60 are honest (sum to 1.000);
-- group 70 is deliberately broken for the data-quality exercise
-- -----------------------------------------------------------------------------
INSERT INTO bridge_diagnosis_group (diagnosis_group_sk, diagnosis_sk, weighting_factor) VALUES
    -- 10: single diagnosis — a group of one
    (10, 1, 1.000),
    -- 20: the article's worked example (E11.9 / I10 / Z79.4)
    (20, 1, 0.500),
    (20, 2, 0.300),
    (20, 3, 0.200),
    -- 30: two contagious codes on one claim
    (30, 4, 0.600),
    (30, 5, 0.400),
    -- 40: single diagnosis
    (40, 6, 1.000),
    -- 50: E11.9 + I10, different weights than group 20
    (50, 1, 0.400),
    (50, 2, 0.600),
    -- 60: single diagnosis
    (60, 2, 1.000),
    -- 70: BROKEN — sums to 1.400, referenced by NO claim (on purpose)
    (70, 1, 0.700),
    (70, 2, 0.700);

-- -----------------------------------------------------------------------------
-- fact_claim_line — one row per billed service line (Q3 2026)
-- -----------------------------------------------------------------------------
-- Note claim_line_sk 1001 IS the article's CL_1001: billed 500.00 through
-- group 20, so the article's example outputs reproduce exactly.
INSERT INTO fact_claim_line
    (claim_line_sk, claim_id, member_sk, provider_sk, service_date_sk, diagnosis_group_sk, billed_amount) VALUES
    (1001, 'CLM_2001', 1, 1, 20260710, 20, 500.00),  -- Bob: diabetes+hypertension+insulin
    (1002, 'CLM_2002', 5, 2, 20260722, 10, 240.00),  -- Linh: diabetes only
    (1003, 'CLM_2003', 7, 1, 20260728, 30, 180.00),  -- Dana: URI + viral infection
    (1004, 'CLM_2004', 2, 3, 20260805, 50, 400.00),  -- Helen: diabetes+hypertension
    (1005, 'CLM_2005', 3, 4, 20260812, 40, 320.00),  -- Mia: low back pain
    (1006, 'CLM_2006', 4, 1, 20260820, 30, 150.00),  -- Leo: URI + viral infection
    (1007, 'CLM_2007', 6, 3, 20260903, 60, 260.00),  -- Mai: hypertension only
    (1008, 'CLM_2008', 1, 2, 20260915, 20, 300.00);  -- Bob again, same 3-code group

-- -----------------------------------------------------------------------------
-- fact_network_coverage — provider in-network for plan as of date
-- -----------------------------------------------------------------------------
INSERT INTO fact_network_coverage (provider_sk, plan_sk, effective_date_sk) VALUES
    (1, 1, 20260701),   -- Alvarez joins PPO Gold
    (1, 2, 20260701),   -- ...and HMO Silver
    (2, 1, 20260801),   -- Chen joins PPO Gold in August
    (2, 3, 20260801),   -- ...and PPO Bronze
    (3, 1, 20260701),   -- Okafor: PPO Gold from July
    (3, 3, 20260701),   -- ...and PPO Bronze
    (4, 1, 20260901),   -- Reyes joins PPO Gold in September
    (4, 2, 20260901);   -- ...and HMO Silver
