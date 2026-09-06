-- =============================================================================
-- Tabby (SaaS) — Sample Data
-- =============================================================================
-- Hand-crafted so every query in queries.sql has a story. Run AFTER schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date — 2025 monthly anchors + key event dates
-- -----------------------------------------------------------------------------
-- 20241201 exists so the MRR waterfall's previous-month join (via dim_date)
-- finds a predecessor for Jan 2025 — and so the Jan 2026 -> Dec 2025 lookup
-- proves the year-boundary case the article warns about.
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_number, month_number, month_name, quarter, year, is_weekend, is_month_start, holiday_name) VALUES
    (20241201, '2024-12-01', 'Sunday',    1, 12,'December', 4, 2024, true,  true, NULL),
    (20250101, '2025-01-01', 'Wednesday', 1, 1, 'January', 1, 2025, false, true, 'New Year''s Day'),
    (20250110, '2025-01-10', 'Friday',   10, 1, 'January', 1, 2025, false, false, NULL),  -- Whisker Labs trial start
    (20250115, '2025-01-15', 'Wednesday',15, 1, 'January', 1, 2025, false, false, NULL),  -- Tabby HQ signup
    (20250124, '2025-01-24', 'Friday',   24, 1, 'January', 1, 2025, false, false, NULL),  -- WL converts to paid
    (20250201, '2025-02-01', 'Saturday', 1, 2, 'February',1, 2025, true,  true, NULL),
    (20250220, '2025-02-20', 'Thursday', 20, 2, 'February',1, 2025, false, false, NULL),  -- Purrfect Co signup
    (20250301, '2025-03-01', 'Saturday', 1, 3, 'March',   1, 2025, true,  true, NULL),
    (20250305, '2025-03-05', 'Wednesday',5, 3, 'March',   1, 2025, false, false, NULL), -- Purrfect Co converts
    (20250401, '2025-04-01', 'Tuesday',  1, 4, 'April',   2, 2025, false, true, NULL),
    (20250415, '2025-04-15', 'Tuesday', 15, 4, 'April',   2, 2025, false, false, NULL),  -- Meow Corp signup
    (20250501, '2025-05-01', 'Thursday', 1, 5, 'May',     2, 2025, false, true, NULL),
    (20250601, '2025-06-01', 'Sunday',   1, 6, 'June',    2, 2025, true,  true, NULL),
    (20250701, '2025-07-01', 'Tuesday',  1, 7, 'July',    3, 2025, false, true, NULL),
    (20250715, '2025-07-15', 'Tuesday', 15, 7, 'July',    3, 2025, false, false, NULL),  -- WL upgrades to Enterprise
    (20250801, '2025-08-01', 'Friday',   1, 8, 'August',  3, 2025, false, true, NULL),
    (20250901, '2025-09-01', 'Monday',   1, 9, 'September',3, 2025, false, true, NULL),
    (20250910, '2025-09-10', 'Wednesday',10, 9, 'September',3, 2025, false, false, NULL), -- Purrfect churns
    (20251001, '2025-10-01', 'Wednesday', 1,10, 'October', 4, 2025, false, true, NULL),
    (20251101, '2025-11-01', 'Saturday', 1,11, 'November',4, 2025, true,  true, NULL),
    (20251201, '2025-12-01', 'Monday',   1,12, 'December',4, 2025, false, true, NULL),
    (20260101, '2026-01-01', 'Thursday', 1, 1, 'January', 1, 2026, false, true, NULL),
    -- Days for usage events & invoices
    (20250131, '2025-01-31', 'Friday',  31, 1, 'January', 1, 2025, false, false, NULL),
    (20250228, '2025-02-28', 'Friday',  28, 2, 'February',1, 2025, false, false, NULL),
    (20250331, '2025-03-31', 'Monday',  31, 3, 'March',   1, 2025, false, false, NULL),
    (20250430, '2025-04-30', 'Wednesday',30, 4, 'April',   2, 2025, false, false, NULL),
    (20250531, '2025-05-31', 'Saturday', 31, 5, 'May',     2, 2025, true,  false, NULL),
    (20250630, '2025-06-30', 'Monday',   30, 6, 'June',    2, 2025, false, false, NULL),
    (20250731, '2025-07-31', 'Thursday', 31, 7, 'July',    3, 2025, false, false, NULL),
    (20250831, '2025-08-31', 'Sunday',   31, 8, 'August',  3, 2025, true,  false, NULL);

-- -----------------------------------------------------------------------------
-- dim_account — SCD Type 2
-- -----------------------------------------------------------------------------
-- Whisker Labs has TWO rows (Pro -> Enterprise). Others are single-row.
-- Surrogate keys are explicit (101-105) so they match the article's SCD2
-- example table and the plan-change diagram: WL Pro = 101, WL Enterprise = 102.
INSERT INTO dim_account (account_sk, account_id, account_name, parent_account_id, plan_id, plan_name, base_mrr, signup_date, billing_country, valid_from, valid_to, is_current) VALUES
    (101, 'ACC_WL',  'Whisker Labs',  NULL,         'PRO', 'Pro',         12.00,  '2025-01-10', 'US', '2025-01-10', '2025-07-14', false),
    (102, 'ACC_WL',  'Whisker Labs',  NULL,         'ENT', 'Enterprise', 499.00,  '2025-01-10', 'US', '2025-07-15', NULL,         true),
    (103, 'ACC_THQ', 'Tabby HQ',      NULL,         'PRO', 'Pro',         12.00,  '2025-01-15', 'US', '2025-01-15', NULL,         true),
    (104, 'ACC_PC',  'Purrfect Co',   'ACC_PETCO',  'PRO', 'Pro',         12.00,  '2025-02-20', 'US', '2025-02-20', NULL,         true),
    (105, 'ACC_MC',  'Meow Corp',     'ACC_PETCO',  'ENT', 'Enterprise', 499.00,  '2025-04-15', 'CA', '2025-04-15', NULL,         true);

-- -----------------------------------------------------------------------------
-- dim_workspace — Type 1
-- -----------------------------------------------------------------------------
INSERT INTO dim_workspace (workspace_id, account_id, workspace_name, created_date) VALUES
    ('WS_WL_1',  'ACC_WL',  'Home',     '2025-01-10'),
    ('WS_THQ_1', 'ACC_THQ', 'Office',   '2025-01-15'),
    ('WS_PC_1',  'ACC_PC',  'Apartment','2025-02-20'),
    ('WS_MC_1',  'ACC_MC',  'HQ',       '2025-04-15'),
    ('WS_MC_2',  'ACC_MC',  'Branch',   '2025-04-20');

-- -----------------------------------------------------------------------------
-- dim_user — Type 1
-- -----------------------------------------------------------------------------
INSERT INTO dim_user (user_id, workspace_id, email, role, created_date) VALUES
    ('U_WL_A',  'WS_WL_1',  'alex@whisker.example',    'OWNER',  '2025-01-10'),
    ('U_THQ_A', 'WS_THQ_1', 'priya@tabby.example',     'OWNER',  '2025-01-15'),
    ('U_PC_A',  'WS_PC_1',  'sam@purrfect.example',    'OWNER',  '2025-02-20'),
    ('U_MC_A',  'WS_MC_1',  'admin@meow.example',      'OWNER',  '2025-04-15'),
    ('U_MC_B',  'WS_MC_1',  'dev@meow.example',        'ADMIN',  '2025-04-16'),
    ('U_MC_C',  'WS_MC_2',  'branch@meow.example',     'ADMIN',  '2025-04-20');

-- -----------------------------------------------------------------------------
-- fact_invoice_line — TRANSACTION FACT
-- -----------------------------------------------------------------------------
INSERT INTO fact_invoice_line (invoice_number, invoice_date_sk, account_sk, subscription_id, line_type, description, quantity, amount) VALUES
    -- Whisker Labs: Jan trial -> Jan 24 converts. Invoice for partial month + Feb.
    (50001, 20250131, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - prorated Jan',  1,  4.00),
    (50002, 20250228, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - Feb',           1, 12.00),
    (50003, 20250331, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - Mar',           1, 12.00),
    (50004, 20250430, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - Apr',           1, 12.00),
    (50005, 20250531, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - May',           1, 12.00),
    (50006, 20250630, 101, 'SUB_WL_001', 'SUBSCRIPTION', 'Pro plan - Jun',           1, 12.00),
    -- Jul: upgrade to Enterprise mid-month. Proration credit + new charge.
    (50007, 20250731, 102, 'SUB_WL_001', 'PRORATION',    'Pro credit - partial Jul', 1, -6.00),
    (50007, 20250731, 102, 'SUB_WL_001', 'SUBSCRIPTION', 'Enterprise - partial Jul', 1, 252.00),
    (50008, 20250831, 102, 'SUB_WL_001', 'SUBSCRIPTION', 'Enterprise - Aug',         1, 499.00),
    -- Tabby HQ: steady Pro
    (50020, 20250131, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - prorated Jan', 1,  6.00),
    (50021, 20250228, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Feb',          1, 12.00),
    (50022, 20250331, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Mar',          1, 12.00),
    (50023, 20250430, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Apr',          1, 12.00),
    (50024, 20250531, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - May',          1, 12.00),
    (50025, 20250630, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Jun',          1, 12.00),
    (50026, 20250731, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Jul',          1, 12.00),
    (50027, 20250831, 103, 'SUB_THQ_001', 'SUBSCRIPTION', 'Pro plan - Aug',          1, 12.00),
    -- Purrfect Co: churns Sep 10 (no Sep invoice)
    (50040, 20250228, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - prorated Feb', 1,  4.00),
    (50041, 20250331, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - Mar',          1, 12.00),
    (50042, 20250430, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - Apr',          1, 12.00),
    (50043, 20250531, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - May',          1, 12.00),
    (50044, 20250630, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - Jun',          1, 12.00),
    (50045, 20250731, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - Jul',          1, 12.00),
    (50046, 20250831, 104, 'SUB_PC_001',  'SUBSCRIPTION', 'Pro plan - Aug',          1, 12.00),
    -- Meow Corp: Enterprise from signup
    (50060, 20250430, 105, 'SUB_MC_001',  'SUBSCRIPTION', 'Enterprise - prorated Apr',1, 250.00),
    (50061, 20250531, 105, 'SUB_MC_001',  'SUBSCRIPTION', 'Enterprise - May',         1, 499.00),
    (50062, 20250630, 105, 'SUB_MC_001',  'SUBSCRIPTION', 'Enterprise - Jun',         1, 499.00),
    (50063, 20250731, 105, 'SUB_MC_001',  'SUBSCRIPTION', 'Enterprise - Jul',         1, 499.00),
    (50064, 20250831, 105, 'SUB_MC_001',  'USAGE',        'Extra collars (5x)',       5, 20.00);

-- -----------------------------------------------------------------------------
-- fact_subscription_month — PERIODIC SNAPSHOT (month-end MRR)
-- -----------------------------------------------------------------------------
-- account_sk points at the dim_account row that was CURRENT at month-end.
-- Snapshots run through Jan 2026 (past the Dec->Jan year boundary) so the
-- article's MRR waterfall and NRR query (Jan 2025 cohort vs Jan 2026) both
-- have data to chew on. Invoice lines above stop at Aug 2025 — that's fine;
-- the snapshot-vs-invoice gap is exactly what Exercise 3 discusses.
INSERT INTO fact_subscription_month (account_sk, subscription_id, month_sk, plan_id, mrr, quantity, is_active) VALUES
    -- Whisker Labs: Pro Jan-Jun, Enterprise Jul onward
    (101, 'SUB_WL_001', 20250101, 'PRO',  12.00, 1, true),
    (101, 'SUB_WL_001', 20250201, 'PRO',  12.00, 1, true),
    (101, 'SUB_WL_001', 20250301, 'PRO',  12.00, 1, true),
    (101, 'SUB_WL_001', 20250401, 'PRO',  12.00, 1, true),
    (101, 'SUB_WL_001', 20250501, 'PRO',  12.00, 1, true),
    (101, 'SUB_WL_001', 20250601, 'PRO',  12.00, 1, true),
    (102, 'SUB_WL_001', 20250701, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20250801, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20250901, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20251001, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20251101, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20251201, 'ENT', 499.00, 1, true),
    (102, 'SUB_WL_001', 20260101, 'ENT', 499.00, 1, true),
    -- Tabby HQ: steady Pro throughout
    (103, 'SUB_THQ_001', 20250101, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250201, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250301, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250401, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250501, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250601, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250701, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250801, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20250901, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20251001, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20251101, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20251201, 'PRO', 12.00, 1, true),
    (103, 'SUB_THQ_001', 20260101, 'PRO', 12.00, 1, true),
    -- Purrfect Co: churns in Sep (zero-MRR inactive row marks the churn)
    (104, 'SUB_PC_001', 20250201, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250301, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250401, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250501, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250601, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250701, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250801, 'PRO', 12.00, 1, true),
    (104, 'SUB_PC_001', 20250901, 'PRO',  0.00, 0, false), -- Sep: churned
    -- Meow Corp: Enterprise from Apr
    (105, 'SUB_MC_001', 20250401, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20250501, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20250601, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20250701, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20250801, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20250901, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20251001, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20251101, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20251201, 'ENT', 499.00, 6, true),
    (105, 'SUB_MC_001', 20260101, 'ENT', 499.00, 6, true);

-- -----------------------------------------------------------------------------
-- fact_subscription_lifecycle — ACCUMULATING SNAPSHOT
-- -----------------------------------------------------------------------------
INSERT INTO fact_subscription_lifecycle
    (account_sk, subscription_id, trial_start_date_sk, trial_end_date_sk, first_paid_date_sk, expanded_date_sk, churned_date_sk, reactivated_date_sk, current_status, trial_to_paid_days, paid_to_churn_days, lifetime_mrr) VALUES
    (101, 'SUB_WL_001', 20250110, 20250124, 20250124, 20250715, NULL, NULL, 'ACTIVE', 14, NULL, 499.00),
    (103, 'SUB_THQ_001',20250115, 20250115, 20250115, NULL,     NULL, NULL, 'ACTIVE',  0, NULL,  12.00),
    (104, 'SUB_PC_001', 20250220, 20250305, 20250305, NULL,     20250910, NULL,'CHURNED',13, 189,  12.00),
    (105, 'SUB_MC_001', 20250415, NULL,     20250415, NULL,     NULL, NULL, 'ACTIVE',  0, NULL, 499.00);

-- -----------------------------------------------------------------------------
-- fact_usage_event — TRANSACTION FACT (sample device telemetry)
-- -----------------------------------------------------------------------------
INSERT INTO fact_usage_event (event_ts, event_date_sk, account_sk, workspace_sk, collar_id, event_type, activity_score, nap_minutes) VALUES
    ('2025-08-15 08:00:00', 20250831, 102, 1, 'COLLAR_001', 'LOCATION', NULL, NULL),
    ('2025-08-15 08:15:00', 20250831, 102, 1, 'COLLAR_001', 'ACTIVITY', 85, NULL),
    ('2025-08-15 08:30:00', 20250831, 102, 1, 'COLLAR_001', 'NAP',      NULL, 45),
    ('2025-08-15 09:00:00', 20250831, 102, 1, 'COLLAR_001', 'LOCATION', NULL, NULL),
    ('2025-08-15 08:00:00', 20250831, 105, 4, 'COLLAR_010', 'LOCATION', NULL, NULL),
    ('2025-08-15 08:15:00', 20250831, 105, 4, 'COLLAR_010', 'ACTIVITY', 92, NULL),
    ('2025-08-15 08:00:00', 20250831, 105, 5, 'COLLAR_011', 'LOCATION', NULL, NULL),
    ('2025-08-15 08:15:00', 20250831, 105, 5, 'COLLAR_011', 'ACTIVITY', 30, NULL),
    ('2025-08-15 08:30:00', 20250831, 105, 5, 'COLLAR_011', 'NAP',      NULL, 60);

-- -----------------------------------------------------------------------------
-- fact_entitlement — FACTLESS FACT TABLE
-- -----------------------------------------------------------------------------
INSERT INTO fact_entitlement (account_sk, feature_id, effective_date_sk) VALUES
    -- Enterprise gets API_ACCESS & NAP_HISTORY; Pro gets NAP_HISTORY only.
    (102, 'API_ACCESS',  20250801),   -- WL (Enterprise) as of Aug
    (102, 'NAP_HISTORY', 20250801),
    (102, 'NAP_HISTORY', 20250201),   -- WL back when Pro
    (103, 'NAP_HISTORY', 20250201),   -- Tabby HQ Pro
    (105, 'API_ACCESS',  20250501),   -- Meow Corp Enterprise
    (105, 'NAP_HISTORY', 20250501),
    (104, 'NAP_HISTORY', 20250301);   -- Purrfect Pro (pre-churn)
