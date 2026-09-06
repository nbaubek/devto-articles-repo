-- =============================================================================
-- Tabby (SaaS) — Dimensional Model (PostgreSQL)
-- =============================================================================
-- Companion schema for "Kimball for SaaS: Subscriptions, MRR, and Churn".
-- Run this first, then seed.sql, then queries.sql.
--
-- Design notes:
--   * dim_account is SCD Type 2 — plan changes create new rows.
--   * Account hierarchy: parent_account_id on dim_account (org rollups).
--   * dim_workspace + dim_user are Type 1, hang off the account.
--   * Fact tables:
--       - fact_invoice_line          (TRANSACTION — one row per invoice line)
--       - fact_subscription_month    (PERIODIC SNAPSHOT — one row per sub/month, MRR)
--       - fact_subscription_lifecycle(ACCUMULATING SNAPSHOT — trial->paid->churn, updated in place)
--       - fact_usage_event           (TRANSACTION — high-volume device events)
--       - fact_entitlement           (FACTLESS — account has feature as of date)
-- =============================================================================

DROP TABLE IF EXISTS fact_entitlement           CASCADE;
DROP TABLE IF EXISTS fact_usage_event            CASCADE;
DROP TABLE IF EXISTS fact_subscription_lifecycle CASCADE;
DROP TABLE IF EXISTS fact_subscription_month     CASCADE;
DROP TABLE IF EXISTS fact_invoice_line           CASCADE;
DROP TABLE IF EXISTS dim_user                    CASCADE;
DROP TABLE IF EXISTS dim_workspace               CASCADE;
DROP TABLE IF EXISTS dim_account                 CASCADE;
DROP TABLE IF EXISTS dim_date                    CASCADE;

-- -----------------------------------------------------------------------------
-- dim_date — YYYYMMDD integer key
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
    is_month_start BOOLEAN NOT NULL DEFAULT false,
    holiday_name   TEXT
);

-- -----------------------------------------------------------------------------
-- dim_account — SCD Type 2 (plan_id / plan_name are the changing attributes)
-- -----------------------------------------------------------------------------
-- One row per (account, plan version). When an account upgrades/downgrades,
-- expire the old row (set valid_to + is_current=false) and insert a new one.
-- Fact tables reference the account_sk that was valid AT THE TIME of the event.
CREATE TABLE dim_account (
    account_sk        BIGSERIAL PRIMARY KEY,
    account_id        TEXT NOT NULL,                 -- natural key, e.g. 'ACC_WL'
    account_name      TEXT NOT NULL,
    parent_account_id TEXT,                          -- org hierarchy (NULL = top-level)
    plan_id           TEXT NOT NULL,                 -- 'FREE' / 'PRO' / 'ENT'
    plan_name         TEXT NOT NULL,
    base_mrr          NUMERIC(10,2) NOT NULL,        -- plan's standard monthly price
    signup_date       DATE NOT NULL,
    billing_country   TEXT,
    -- SCD Type 2 columns:
    valid_from        DATE NOT NULL,
    valid_to          DATE,
    is_current        BOOLEAN NOT NULL,
    UNIQUE (account_id, valid_from)
);
CREATE INDEX idx_account_natural ON dim_account (account_id, is_current);
CREATE INDEX idx_account_current ON dim_account (is_current);

-- -----------------------------------------------------------------------------
-- dim_workspace — Type 1 (one per account, for multi-room/household setups)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_workspace (
    workspace_sk   BIGSERIAL PRIMARY KEY,
    workspace_id   TEXT NOT NULL UNIQUE,
    account_id     TEXT NOT NULL,                    -- denormalized for one-hop joins
    workspace_name TEXT NOT NULL,
    created_date   DATE NOT NULL
);

-- -----------------------------------------------------------------------------
-- dim_user — Type 1 (people, belong to a workspace)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_user (
    user_sk      BIGSERIAL PRIMARY KEY,
    user_id      TEXT NOT NULL UNIQUE,
    workspace_id TEXT NOT NULL,
    email        TEXT NOT NULL,
    role         TEXT NOT NULL,                       -- OWNER / ADMIN / MEMBER
    created_date DATE NOT NULL
);

-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_invoice_line — TRANSACTION FACT (one row per line on an invoice)
-- -----------------------------------------------------------------------------
-- The atomic billing event. Drives revenue recognition.
CREATE TABLE fact_invoice_line (
    invoice_line_sk BIGSERIAL PRIMARY KEY,
    invoice_number  BIGINT NOT NULL,                  -- degenerate dimension
    invoice_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    account_sk      BIGINT NOT NULL REFERENCES dim_account(account_sk),
    subscription_id TEXT NOT NULL,
    line_type       TEXT NOT NULL,                    -- SUBSCRIPTION / USAGE / PRORATION / DISCOUNT
    description     TEXT,
    quantity        INT NOT NULL DEFAULT 1,
    amount          NUMERIC(10,2) NOT NULL            -- can be negative (credits/discounts)
);
CREATE INDEX idx_fil_date    ON fact_invoice_line (invoice_date_sk);
CREATE INDEX idx_fil_account ON fact_invoice_line (account_sk);
CREATE INDEX idx_fil_invoice ON fact_invoice_line (invoice_number);

-- -----------------------------------------------------------------------------
-- fact_subscription_month — PERIODIC SNAPSHOT (one row per sub per month)
-- -----------------------------------------------------------------------------
-- The MRR history table. month_sk points at the first day of the month.
-- is_active = false on rows where the subscription had churned by month-end.
CREATE TABLE fact_subscription_month (
    subscription_month_sk BIGSERIAL PRIMARY KEY,
    account_sk            BIGINT NOT NULL REFERENCES dim_account(account_sk),
    subscription_id       TEXT NOT NULL,
    month_sk              INT NOT NULL REFERENCES dim_date(date_sk), -- 1st of month
    plan_id               TEXT NOT NULL,
    mrr                   NUMERIC(10,2) NOT NULL,
    quantity              INT NOT NULL,               -- active collars/devices
    is_active             BOOLEAN NOT NULL,
    UNIQUE (subscription_id, month_sk)
);
CREATE INDEX idx_fsm_month ON fact_subscription_month (month_sk);

-- -----------------------------------------------------------------------------
-- fact_subscription_lifecycle — ACCUMULATING SNAPSHOT (one row per subscription)
-- -----------------------------------------------------------------------------
-- Updated in place as milestones are hit. trial -> paid -> expand -> churn.
CREATE TABLE fact_subscription_lifecycle (
    lifecycle_sk          BIGSERIAL PRIMARY KEY,
    account_sk            BIGINT NOT NULL REFERENCES dim_account(account_sk),
    subscription_id       TEXT NOT NULL UNIQUE,
    trial_start_date_sk   INT NOT NULL REFERENCES dim_date(date_sk),
    trial_end_date_sk     INT REFERENCES dim_date(date_sk),
    first_paid_date_sk    INT REFERENCES dim_date(date_sk),
    expanded_date_sk      INT REFERENCES dim_date(date_sk),     -- first plan upgrade
    churned_date_sk       INT REFERENCES dim_date(date_sk),
    reactivated_date_sk   INT REFERENCES dim_date(date_sk),
    current_status        TEXT NOT NULL,   -- TRIAL / ACTIVE / CHURNED / REACTIVATED
    trial_to_paid_days    INT,
    paid_to_churn_days    INT,
    lifetime_mrr          NUMERIC(12,2)
);

-- -----------------------------------------------------------------------------
-- fact_usage_event — TRANSACTION FACT (high-volume device telemetry)
-- -----------------------------------------------------------------------------
-- Separate from billing! Partition by event_date_sk in production.
CREATE TABLE fact_usage_event (
    usage_event_sk BIGSERIAL PRIMARY KEY,
    event_ts       TIMESTAMP NOT NULL,
    event_date_sk  INT NOT NULL REFERENCES dim_date(date_sk),
    account_sk     BIGINT NOT NULL REFERENCES dim_account(account_sk),
    workspace_sk   BIGINT NOT NULL REFERENCES dim_workspace(workspace_sk),
    collar_id      TEXT NOT NULL,                     -- the IoT device
    event_type     TEXT NOT NULL,                     -- LOCATION / ACTIVITY / NAP
    activity_score INT,
    nap_minutes    INT
);
CREATE INDEX idx_fue_date    ON fact_usage_event (event_date_sk);
CREATE INDEX idx_fue_account ON fact_usage_event (account_sk);

-- -----------------------------------------------------------------------------
-- fact_entitlement — FACTLESS FACT TABLE
-- -----------------------------------------------------------------------------
-- Row presence = "account had feature_id as of effective_date_sk."
-- Robust to plan & feature changes over time (vs. reading dim_plan attributes).
CREATE TABLE fact_entitlement (
    entitlement_sk    BIGSERIAL PRIMARY KEY,
    account_sk        BIGINT NOT NULL REFERENCES dim_account(account_sk),
    feature_id        TEXT NOT NULL,                  -- 'API_ACCESS' / 'NAP_HISTORY' / etc.
    effective_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    UNIQUE (account_sk, feature_id, effective_date_sk)
);
CREATE INDEX idx_fe_date ON fact_entitlement (effective_date_sk);
