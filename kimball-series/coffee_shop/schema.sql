-- =============================================================================
-- Bean & Stalk Coffee Shop — Dimensional Model (PostgreSQL)
-- =============================================================================
-- Companion schema for "Kimball Dimensional Modeling, Explained Through a
-- Coffee Shop". Run this first, then seed.sql, then queries.sql.
--
-- Design notes:
--   * Surrogate keys use BIGSERIAL for dimensions, BIGSERIAL for facts.
--   * dim_product is SCD Type 2 (valid_from / valid_to / is_current).
--   * dim_date uses an integer key in YYYYMMDD form for fast joins.
--   * Date role-playing is modeled as two FKs in fact_order_line
--     (order_date_sk, pickup_date_sk), both pointing at dim_date.
--   * A junk dimension combines low-cardinality flags (size, milk, syrup).
--   * receipt_number is a degenerate dimension (no dim table).
-- =============================================================================

-- Clean slate (idempotent re-runs during development)
DROP TABLE IF EXISTS fact_drink_availability CASCADE;
DROP TABLE IF EXISTS fact_loyalty_journey   CASCADE;
DROP TABLE IF EXISTS fact_daily_sales        CASCADE;
DROP TABLE IF EXISTS fact_order_line         CASCADE;
DROP TABLE IF EXISTS dim_junk                CASCADE;
DROP TABLE IF EXISTS dim_barista             CASCADE;
DROP TABLE IF EXISTS dim_store               CASCADE;
DROP TABLE IF EXISTS dim_customer            CASCADE;
DROP TABLE IF EXISTS dim_product             CASCADE;
DROP TABLE IF EXISTS dim_date                CASCADE;

-- -----------------------------------------------------------------------------
-- dim_date  (role-playable by any date FK)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_sk        INT PRIMARY KEY,          -- YYYYMMDD, e.g. 20260813
    full_date      DATE NOT NULL UNIQUE,
    day_of_week    TEXT NOT NULL,             -- 'Monday'
    day_number     INT NOT NULL,              -- 1..31
    month_number   INT NOT NULL,              -- 1..12
    month_name     TEXT NOT NULL,             -- 'August'
    quarter        INT NOT NULL,              -- 1..4
    year           INT NOT NULL,
    is_weekend     BOOLEAN NOT NULL,
    holiday_name   TEXT                       -- NULL if not a holiday
);

-- -----------------------------------------------------------------------------
-- dim_product  (SCD Type 2)
-- -----------------------------------------------------------------------------
-- Multiple rows per product_id are allowed; is_current identifies the live row.
-- The fact table's product_sk always points at the row that was valid when the
-- event occurred, so historical reports use historical prices/recipes.
CREATE TABLE dim_product (
    product_sk      BIGSERIAL PRIMARY KEY,
    product_id      TEXT NOT NULL,            -- natural key, e.g. 'OAT_LATTE'
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,            -- 'ESPRESSO_DRINK','DRIP','PASTRY','BEANS'
    base_price      NUMERIC(8,2) NOT NULL,
    recipe_notes    TEXT,
    valid_from      DATE NOT NULL,
    valid_to        DATE,                     -- NULL means currently valid
    is_current      BOOLEAN NOT NULL,
    UNIQUE (product_id, valid_from)
);
CREATE INDEX idx_product_natural ON dim_product (product_id, is_current);

-- -----------------------------------------------------------------------------
-- dim_customer  (loyalty members; Type 1 for simplicity)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_sk     BIGSERIAL PRIMARY KEY,
    customer_id     TEXT NOT NULL UNIQUE,     -- natural key
    name            TEXT NOT NULL,
    email           TEXT,
    loyalty_number  TEXT UNIQUE,
    signup_date     DATE NOT NULL,
    loyalty_tier    TEXT NOT NULL DEFAULT 'BRONZE'  -- BRONZE / SILVER / GOLD
);

-- -----------------------------------------------------------------------------
-- dim_store
-- -----------------------------------------------------------------------------
CREATE TABLE dim_store (
    store_sk        BIGSERIAL PRIMARY KEY,
    store_id        TEXT NOT NULL UNIQUE,     -- 'MISSION', 'HAYES'
    store_name      TEXT NOT NULL,
    city            TEXT NOT NULL,
    state           TEXT NOT NULL,
    opening_date    DATE NOT NULL,
    sq_ft           INT
);

-- -----------------------------------------------------------------------------
-- dim_barista
-- -----------------------------------------------------------------------------
CREATE TABLE dim_barista (
    barista_sk      BIGSERIAL PRIMARY KEY,
    barista_id      TEXT NOT NULL UNIQUE,
    barista_name    TEXT NOT NULL,
    store_id        TEXT NOT NULL,            -- denormalized for convenience
    hire_date       DATE NOT NULL,
    specialty       TEXT                      -- 'LATTE_ART','POUR_OVER','VIBES'
);

-- -----------------------------------------------------------------------------
-- dim_junk  (size / milk / syrup / extra shot — low-cardinality combos)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_junk (
    junk_sk         BIGSERIAL PRIMARY KEY,
    size            TEXT NOT NULL,            -- SMALL / MEDIUM / LARGE
    milk_type       TEXT NOT NULL,            -- WHOLE / OAT / ALMOND / SOY / NONE
    syrup_flavor    TEXT NOT NULL,            -- NONE / VANILLA / CARAMEL / HAZELNUT
    extra_shot      BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (size, milk_type, syrup_flavor, extra_shot)
);

-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_order_line  — TRANSACTION FACT (one row per order line item)
-- -----------------------------------------------------------------------------
CREATE TABLE fact_order_line (
    order_line_sk   BIGSERIAL PRIMARY KEY,
    receipt_number  BIGINT NOT NULL,          -- degenerate dimension
    order_date_sk   INT NOT NULL REFERENCES dim_date(date_sk),
    pickup_date_sk  INT NOT NULL REFERENCES dim_date(date_sk),
    product_sk      BIGINT NOT NULL REFERENCES dim_product(product_sk),
    customer_sk     BIGINT REFERENCES dim_customer(customer_sk),  -- nullable: walk-ins
    store_sk        BIGINT NOT NULL REFERENCES dim_store(store_sk),
    barista_sk      BIGINT NOT NULL REFERENCES dim_barista(barista_sk),
    junk_sk         BIGINT NOT NULL REFERENCES dim_junk(junk_sk),
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(8,2) NOT NULL,    -- price actually charged
    discount_amount NUMERIC(8,2) NOT NULL DEFAULT 0,
    line_total      NUMERIC(8,2) NOT NULL     -- quantity * unit_price - discount
);
CREATE INDEX idx_fol_date    ON fact_order_line (order_date_sk);
CREATE INDEX idx_fol_product ON fact_order_line (product_sk);
CREATE INDEX idx_fol_receipt ON fact_order_line (receipt_number);

-- -----------------------------------------------------------------------------
-- fact_daily_sales — PERIODIC SNAPSHOT FACT (one row per day/store/product)
-- -----------------------------------------------------------------------------
-- Pre-aggregated photo of the day. Easier & faster for YoY/trend dashboards.
CREATE TABLE fact_daily_sales (
    daily_sales_sk   BIGSERIAL PRIMARY KEY,
    snapshot_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    store_sk         BIGINT NOT NULL REFERENCES dim_store(store_sk),
    product_sk       BIGINT NOT NULL REFERENCES dim_product(product_sk),
    daily_quantity   INT NOT NULL,
    daily_revenue    NUMERIC(10,2) NOT NULL,
    transaction_count INT NOT NULL,
    UNIQUE (snapshot_date_sk, store_sk, product_sk)
);

-- -----------------------------------------------------------------------------
-- fact_loyalty_journey — ACCUMULATING SNAPSHOT (one row per loyalty member)
-- -----------------------------------------------------------------------------
-- Updated in place as milestones are hit. Contrast with fact_order_line,
-- which is append-only.
CREATE TABLE fact_loyalty_journey (
    journey_sk               BIGSERIAL PRIMARY KEY,
    customer_sk              BIGINT NOT NULL REFERENCES dim_customer(customer_sk),
    signup_date_sk           INT NOT NULL REFERENCES dim_date(date_sk),
    first_purchase_date_sk   INT REFERENCES dim_date(date_sk),
    fifth_purchase_date_sk   INT REFERENCES dim_date(date_sk),
    tenth_purchase_date_sk   INT REFERENCES dim_date(date_sk),
    current_status           TEXT NOT NULL DEFAULT 'SIGNED_UP',
        -- SIGNED_UP / ACTIVE / REWARD_EARNED / CHURNED
    signup_to_first_days     INT,
    first_to_tenth_days      INT,
    UNIQUE (customer_sk)
);

-- -----------------------------------------------------------------------------
-- fact_drink_availability — FACTLESS FACT TABLE
-- -----------------------------------------------------------------------------
-- Row presence means "product P was available at store S on date D."
-- Used for seasonal items (PSL), out-of-stock days, promotion coverage, etc.
CREATE TABLE fact_drink_availability (
    drink_availability_sk BIGSERIAL PRIMARY KEY,
    product_sk            BIGINT NOT NULL REFERENCES dim_product(product_sk),
    date_sk               INT NOT NULL REFERENCES dim_date(date_sk),
    store_sk              BIGINT NOT NULL REFERENCES dim_store(store_sk),
    is_promoted           BOOLEAN NOT NULL DEFAULT false,  -- beyond the article's DDL; powers Exercise 4(b)
    UNIQUE (product_sk, date_sk, store_sk)
);
