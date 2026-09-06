-- =============================================================================
-- Tabby Contracts — Sample Data
-- =============================================================================
-- The PetCo Org deal from the article, seeded so all three stakeholder
-- numbers reproduce exactly:
--   * Sales:      $648,000 booked at signature (2026-01-01)
--   * Finance:    $18,000 recognized to date ($6,000 Jan + $12,000 Feb)
--   * Cust. Success: 8 of 12 locations active (wave 3 slips; one DELAYED)
-- Plus two smaller contracts (Groom & Board, Tiny Paws renewal) so
-- portfolio-level queries aren't a single-row special case.
-- "Today" = early March 2026: month snapshots exist for Jan + Feb only.
-- Run AFTER schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date — month starts + signature dates the seed references
-- -----------------------------------------------------------------------------
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_number, month_number, month_name, quarter, year, is_weekend, holiday_name) VALUES
    (20260101, '2026-01-01', 'Thursday', 1, 1, 'January',  1, 2026, true,  'New Year''s Day'),
    (20260201, '2026-02-01', 'Sunday',   1, 2, 'February', 1, 2026, true,  NULL),
    (20260301, '2026-03-01', 'Sunday',   1, 3, 'March',    1, 2026, true,  NULL);

-- -----------------------------------------------------------------------------
-- dim_account / dim_employee
-- -----------------------------------------------------------------------------
INSERT INTO dim_account (account_sk, account_id, account_name, segment) VALUES
    (1, 'ACC_PETCO',  'PetCo Org',           'VET_CHAIN'),
    (2, 'ACC_GROOM',  'Groom & Board Co',    'GROOMING'),
    (3, 'ACC_TINY',   'Tiny Paws Vet Clinic','INDEPENDENT');

INSERT INTO dim_employee (employee_sk, employee_name, team) VALUES
    (1, 'Riley Okonkwo', 'SALES'),
    (2, 'Jordan Fields', 'SALES'),
    (3, 'Priya Raman',   'CUSTOMER_SUCCESS');

-- -----------------------------------------------------------------------------
-- dim_location — 12 PetCo clinics, 4 Groom & Board shops, 1 Tiny Paws clinic
-- -----------------------------------------------------------------------------
INSERT INTO dim_location (location_sk, location_id, location_name, city, state) VALUES
    -- PetCo Org (12): waves 1 (Jan), 2 (Feb), 3 (Mar, scheduled)
    (1,  'LOC_PC_01', 'PetCo Ballard',      'Seattle',     'WA'),
    (2,  'LOC_PC_02', 'PetCo Capitol Hill', 'Seattle',     'WA'),
    (3,  'LOC_PC_03', 'PetCo Pearl District','Portland',   'OR'),
    (4,  'LOC_PC_04', 'PetCo Boise',        'Boise',       'ID'),
    (5,  'LOC_PC_05', 'PetCo Denver West',  'Denver',      'CO'),
    (6,  'LOC_PC_06', 'PetCo RiNo',         'Denver',      'CO'),
    (7,  'LOC_PC_07', 'PetCo Austin South', 'Austin',      'TX'),
    (8,  'LOC_PC_08', 'PetCo Oak Cliff',    'Dallas',      'TX'),
    (9,  'LOC_PC_09', 'PetCo Wicker Park',  'Chicago',     'IL'),
    (10, 'LOC_PC_10', 'PetCo Logan Square', 'Chicago',     'IL'),
    (11, 'LOC_PC_11', 'PetCo Somerville',   'Somerville',  'MA'),
    (12, 'LOC_PC_12', 'PetCo Brooklyn',     'Brooklyn',    'NY'),  -- wave 3, has slipped
    -- Groom & Board Co (4): all live at signature
    (13, 'LOC_GB_01', 'Groom & Board Pearl','Portland',    'OR'),
    (14, 'LOC_GB_02', 'Groom & Board Alberta','Portland',  'OR'),
    (15, 'LOC_GB_03', 'Groom & Board Ventura','Portland',  'OR'),
    (16, 'LOC_GB_04', 'Groom & Board Division','Portland', 'OR'),
    -- Tiny Paws (1)
    (17, 'LOC_TP_01', 'Tiny Paws Clinic',   'Bend',        'OR');

-- -----------------------------------------------------------------------------
-- dim_contract — three deals
-- -----------------------------------------------------------------------------
INSERT INTO dim_contract
    (contract_sk, contract_id, account_sk, signed_date, term_months, total_contract_value, location_count, sales_rep_sk) VALUES
    (1, 'PETCO_2026_01', 1, '2026-01-01', 36, 648000.00, 12, 1),  -- $18k/mo fully live; $1,500/location/mo
    (2, 'GROOM_2026_02', 2, '2026-02-01', 24,  96000.00,  4, 2),  -- $4k/mo;  $1,000/location/mo
    (3, 'TINY_2026_03',  3, '2026-03-01', 12,   5400.00,  1, 1);  -- renewal;  $450/mo

-- -----------------------------------------------------------------------------
-- fact_booking — Sales' view, full value at signature
-- -----------------------------------------------------------------------------
INSERT INTO fact_booking (booking_sk, contract_sk, account_sk, booked_date_sk, booking_type, booked_value) VALUES
    (1, 1, 1, 20260101, 'NEW',      648000.00),
    (2, 2, 2, 20260201, 'NEW',      96000.00),
    (3, 3, 3, 20260301, 'RENEWAL',   5400.00);

-- -----------------------------------------------------------------------------
-- fact_subscription_month — Finance's view, month-end snapshots
-- -----------------------------------------------------------------------------
-- PetCo: 4 locations live in Jan ($6k), 8 in Feb ($12k). Wave 3 hasn't
-- happened, so March has no row yet — and Tiny Paws signed 2026-03-01, so
-- its first month-end snapshot doesn't exist either. Both gaps are the
-- article's point: a snapshot view shows NOTHING for money that hasn't
-- been earned yet, which is exactly backwards from Sales' needs.
INSERT INTO fact_subscription_month
    (subscription_month_sk, contract_sk, account_sk, subscription_id, month_sk, plan_id, mrr, quantity, is_active) VALUES
    (1, 1, 1, 'SUB_PETCO_001', 20260101, 'ENTERPRISE',  6000.00,  4, true),
    (2, 1, 1, 'SUB_PETCO_001', 20260201, 'ENTERPRISE', 12000.00,  8, true),
    (3, 2, 2, 'SUB_GROOM_001', 20260201, 'PRO',         4000.00,  4, true);

-- -----------------------------------------------------------------------------
-- fact_location_activation — Customer Success's view
-- -----------------------------------------------------------------------------
INSERT INTO fact_location_activation
    (activation_sk, contract_sk, location_sk, scheduled_activation_date_sk, actual_activation_date_sk, current_status) VALUES
    -- PetCo wave 1: live January
    (1,  1, 1,  20260101, 20260101, 'ACTIVE'),
    (2,  1, 2,  20260101, 20260101, 'ACTIVE'),
    (3,  1, 3,  20260101, 20260101, 'ACTIVE'),
    (4,  1, 4,  20260101, 20260101, 'ACTIVE'),
    -- PetCo wave 2: live February
    (5,  1, 5,  20260201, 20260201, 'ACTIVE'),
    (6,  1, 6,  20260201, 20260201, 'ACTIVE'),
    (7,  1, 7,  20260201, 20260201, 'ACTIVE'),
    (8,  1, 8,  20260201, 20260201, 'ACTIVE'),
    -- PetCo wave 3: scheduled March — Brooklyn has slipped
    (9,  1, 9,  20260301, NULL,     'SCHEDULED'),
    (10, 1, 10, 20260301, NULL,     'SCHEDULED'),
    (11, 1, 11, 20260301, NULL,     'SCHEDULED'),
    (12, 1, 12, 20260301, NULL,     'DELAYED'),
    -- Groom & Board: all four live at signature
    (13, 2, 13, 20260201, 20260201, 'ACTIVE'),
    (14, 2, 14, 20260201, 20260201, 'ACTIVE'),
    (15, 2, 15, 20260201, 20260201, 'ACTIVE'),
    (16, 2, 16, 20260201, 20260201, 'ACTIVE'),
    -- Tiny Paws: live at renewal signature
    (17, 3, 17, 20260301, 20260301, 'ACTIVE');
