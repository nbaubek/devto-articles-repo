-- =============================================================================
-- Tabby Contracts — Dimensional Model (PostgreSQL)
-- =============================================================================
-- Companion schema for "Kimball's Last Hard Problem: When There Is No Right
-- Grain" (Part 5, final, of the series). Run this first, then seed.sql,
-- then queries.sql.
--
-- Design notes — the whole article in one schema:
--   * One deal (PetCo Org), THREE stakeholders, THREE fact tables at three
--     grains that cannot be reconciled into each other:
--       - fact_booking              — transaction, one row per signing event
--                                     (Sales: $648,000 at signature)
--       - fact_subscription_month   — periodic snapshot, one row per
--                                     subscription-month (Finance: $18,000
--                                     recognized to date)
--       - fact_location_activation  — accumulating snapshot, one row per
--                                     contract location (Customer Success:
--                                     8 of 12 active)
--   * The three facts share dim_contract — a CONFORMED DIMENSION — and never
--     reference each other. No fact-to-fact foreign keys anywhere.
--   * fact_subscription_month is Part 2's table with one new column,
--     contract_sk (the article adds it via ALTER TABLE when the table
--     already exists; here it's built in from the start).
--   * "Today" in this case study is early March 2026: month-end snapshots
--     exist for January and February only, wave 3 of PetCo locations is
--     scheduled for March, and one of them has slipped to DELAYED.
-- =============================================================================

-- Clean slate (idempotent re-runs during development)
DROP TABLE IF EXISTS fact_location_activation CASCADE;
DROP TABLE IF EXISTS fact_subscription_month CASCADE;
DROP TABLE IF EXISTS fact_booking          CASCADE;
DROP TABLE IF EXISTS dim_contract          CASCADE;
DROP TABLE IF EXISTS dim_location          CASCADE;
DROP TABLE IF EXISTS dim_employee          CASCADE;
DROP TABLE IF EXISTS dim_account           CASCADE;
DROP TABLE IF EXISTS dim_date              CASCADE;

-- -----------------------------------------------------------------------------
-- dim_date  (integer YYYYMMDD key; month-start rows drive the snapshots)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_sk        INT PRIMARY KEY,
    full_date      DATE NOT NULL UNIQUE,
    day_of_week    TEXT NOT NULL,
    day_number     INT NOT NULL,
    month_number   INT NOT NULL,
    month_name     TEXT NOT NULL,
    quarter        INT NOT NULL,
    year           INT NOT NULL,
    is_weekend     BOOLEAN NOT NULL,
    holiday_name   TEXT
);

-- -----------------------------------------------------------------------------
-- dim_account  (Tabby's customers — conformed with every fact here)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_account (
    account_sk     BIGSERIAL PRIMARY KEY,
    account_id     TEXT NOT NULL UNIQUE,      -- 'ACC_PETCO'
    account_name   TEXT NOT NULL,
    segment        TEXT NOT NULL              -- VET_CHAIN / GROOMING / INDEPENDENT
);

-- -----------------------------------------------------------------------------
-- dim_employee  (sales reps own bookings; CS owns activations)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_employee (
    employee_sk    BIGSERIAL PRIMARY KEY,
    employee_name  TEXT NOT NULL,
    team           TEXT NOT NULL              -- SALES / CUSTOMER_SUCCESS
);

-- -----------------------------------------------------------------------------
-- dim_location  (the physical sites being onboarded — PetCo's 12 clinics,
--                Groom & Board's 4 shops, Tiny Paws' single clinic)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_location (
    location_sk    BIGSERIAL PRIMARY KEY,
    location_id    TEXT NOT NULL UNIQUE,      -- 'LOC_PC_01'
    location_name  TEXT NOT NULL,
    city           TEXT NOT NULL,
    state          TEXT NOT NULL
);

-- -----------------------------------------------------------------------------
-- dim_contract  — THE CONFORMED DIMENSION that links all three facts
-- -----------------------------------------------------------------------------
-- One row per signed contract. This is the table fact_booking,
-- fact_subscription_month, and fact_location_activation all reference —
-- and the only thing linking them.
CREATE TABLE dim_contract (
    contract_sk           BIGSERIAL PRIMARY KEY,
    contract_id           TEXT NOT NULL UNIQUE,   -- 'PETCO_2026_01'
    account_sk            BIGINT NOT NULL REFERENCES dim_account(account_sk),
    signed_date           DATE NOT NULL,
    term_months           INT NOT NULL,
    total_contract_value  NUMERIC(12,2) NOT NULL,
    location_count        INT NOT NULL,
    sales_rep_sk          INT REFERENCES dim_employee(employee_sk)
);

-- =============================================================================
-- FACT TABLES — three grains, no fact references another fact
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_booking — TRANSACTION FACT (one row per signing event) — SALES
-- -----------------------------------------------------------------------------
-- Full value credited at signature. Commission and pipeline live here,
-- and only here.
CREATE TABLE fact_booking (
    booking_sk     BIGSERIAL PRIMARY KEY,
    contract_sk    BIGINT NOT NULL REFERENCES dim_contract(contract_sk),
    account_sk     BIGINT NOT NULL REFERENCES dim_account(account_sk),
    booked_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    booking_type   TEXT NOT NULL,             -- NEW / RENEWAL / AMENDMENT / UPSELL
    booked_value   NUMERIC(12,2) NOT NULL
);

-- -----------------------------------------------------------------------------
-- fact_subscription_month — PERIODIC SNAPSHOT (one row per subscription per
-- month) — FINANCE. Part 2's table + contract_sk.
-- -----------------------------------------------------------------------------
-- mrr is recognized as revenue for delivered location-months. Summing mrr
-- across months reads as "revenue recognized to date" — NOT as a run-rate.
CREATE TABLE fact_subscription_month (
    subscription_month_sk BIGSERIAL PRIMARY KEY,
    contract_sk           BIGINT REFERENCES dim_contract(contract_sk),  -- NULL for
                                                -- pre-contract months in Part 2's data
    account_sk            BIGINT NOT NULL REFERENCES dim_account(account_sk),
    subscription_id       TEXT NOT NULL,
    month_sk              INT NOT NULL REFERENCES dim_date(date_sk), -- 1st of month
    plan_id               TEXT NOT NULL,
    mrr                   NUMERIC(10,2) NOT NULL,
    quantity              INT NOT NULL,       -- active locations (collars) that month
    is_active             BOOLEAN NOT NULL,
    UNIQUE (subscription_id, month_sk)
);
CREATE INDEX idx_fsm_contract ON fact_subscription_month (contract_sk);

-- -----------------------------------------------------------------------------
-- fact_location_activation — ACCUMULATING SNAPSHOT (one row per contract
-- location) — CUSTOMER SUCCESS
-- -----------------------------------------------------------------------------
-- Updated in place as go-lives happen; the milestone pair is
-- scheduled_activation_date_sk / actual_activation_date_sk.
CREATE TABLE fact_location_activation (
    activation_sk                BIGSERIAL PRIMARY KEY,
    contract_sk                  BIGINT NOT NULL REFERENCES dim_contract(contract_sk),
    location_sk                  BIGINT NOT NULL REFERENCES dim_location(location_sk),
    scheduled_activation_date_sk INT REFERENCES dim_date(date_sk),
    actual_activation_date_sk    INT REFERENCES dim_date(date_sk),
    current_status               TEXT NOT NULL   -- SCHEDULED / ACTIVE / DELAYED
    -- note: no booking_sk, no fact-to-fact references — dim_contract only
);
CREATE INDEX idx_fla_contract ON fact_location_activation (contract_sk);
