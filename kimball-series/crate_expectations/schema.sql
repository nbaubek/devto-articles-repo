-- =============================================================================
-- Crate Expectations — Dimensional Model (PostgreSQL)
-- =============================================================================
-- Companion schema for "Kimball for Order Fulfillment: Milestones, Split
-- Shipments, and Facts That Arrive Late" (Part 3 of the series). Run this
-- first, then seed.sql, then queries.sql.
--
-- Design notes:
--   * TWO fact tables at two grains, on purpose:
--       - fact_order_lifecycle — ACCUMULATING SNAPSHOT, one row per order,
--         updated in place as milestones happen. Order-level questions only.
--       - fact_shipment        — ACCUMULATING SNAPSHOT, one row per shipment.
--         Carrier/warehouse questions live here, not on the order.
--   * The order-level fact stores first_shipped_date_sk / all_delivered_date_sk
--     (not "the" ship date) because a split order has one per shipment; only
--     the first and the last are honest at the order grain.
--   * fulfillment_status_rank turns current_status into "furthest point reached
--     in a known pipeline," so late-arriving or duplicate carrier webhooks can
--     never drag the visible status backward (see the article's UPDATE logic).
--   * fact_shipment_event is the RAW WEBHOOK ARRIVAL LOG (a staging table, not
--     part of the star). It exists so the late-arriving/out-of-order exercises
--     have real arrival data to reason about.
--   * tracking_number on fact_shipment is a DEGENERATE dimension beyond the
--     article's DDL (same idea as receipt_number in Part 1).
-- =============================================================================

-- Clean slate (idempotent re-runs during development)
DROP TABLE IF EXISTS fact_shipment_event     CASCADE;
DROP TABLE IF EXISTS fact_shipment           CASCADE;
DROP TABLE IF EXISTS fact_order_lifecycle    CASCADE;
DROP TABLE IF EXISTS fulfillment_status_rank CASCADE;
DROP TABLE IF EXISTS dim_carrier             CASCADE;
DROP TABLE IF EXISTS dim_warehouse           CASCADE;
DROP TABLE IF EXISTS dim_order               CASCADE;
DROP TABLE IF EXISTS dim_customer            CASCADE;
DROP TABLE IF EXISTS dim_date                CASCADE;

-- -----------------------------------------------------------------------------
-- dim_date  (role-playable by any date FK; integer YYYYMMDD key)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_sk        INT PRIMARY KEY,          -- YYYYMMDD, e.g. 20251103
    full_date      DATE NOT NULL UNIQUE,
    day_of_week    TEXT NOT NULL,             -- 'Monday'
    day_number     INT NOT NULL,              -- 1..31
    month_number   INT NOT NULL,              -- 1..12
    month_name     TEXT NOT NULL,             -- 'November'
    quarter        INT NOT NULL,              -- 1..4
    year           INT NOT NULL,
    is_weekend     BOOLEAN NOT NULL,
    holiday_name   TEXT                       -- NULL if not a holiday
);

-- -----------------------------------------------------------------------------
-- dim_customer  (Type 1 — shipping context doesn't need history here)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_sk    BIGSERIAL PRIMARY KEY,
    customer_id    TEXT NOT NULL UNIQUE,      -- 'CUST_101'
    customer_name  TEXT NOT NULL,
    city           TEXT NOT NULL,
    state          TEXT NOT NULL,
    is_trade       BOOLEAN NOT NULL DEFAULT false   -- interior-designer trade account?
);

-- -----------------------------------------------------------------------------
-- dim_order  (order context; the order's *milestones* live on the fact)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_order (
    order_sk       BIGSERIAL PRIMARY KEY,
    order_id       TEXT NOT NULL UNIQUE,      -- 'ORD_5001'
    channel        TEXT NOT NULL,             -- WEB / STORE / PHONE
    is_gift        BOOLEAN NOT NULL DEFAULT false
);

-- -----------------------------------------------------------------------------
-- dim_warehouse
-- -----------------------------------------------------------------------------
CREATE TABLE dim_warehouse (
    warehouse_sk   INT PRIMARY KEY,           -- small, stable, hand-assigned
    warehouse_id   TEXT NOT NULL UNIQUE,      -- 'EAST' / 'WEST'
    warehouse_name TEXT NOT NULL,
    city           TEXT NOT NULL,
    state          TEXT NOT NULL,
    opening_date   DATE NOT NULL
);

-- -----------------------------------------------------------------------------
-- dim_carrier
-- -----------------------------------------------------------------------------
CREATE TABLE dim_carrier (
    carrier_sk     INT PRIMARY KEY,
    carrier_id     TEXT NOT NULL UNIQUE,      -- 'FASTFREIGHT' / 'ROADRUNNER'
    carrier_name   TEXT NOT NULL,
    webhook_api    TEXT NOT NULL               -- which API the events come from
);

-- -----------------------------------------------------------------------------
-- fulfillment_status_rank  (the ordered pipeline — powers forward-only status)
-- -----------------------------------------------------------------------------
-- current_status is "furthest point reached," compared by rank — never by
-- arrival time or event timestamp. See the article's late-arriving section.
CREATE TABLE fulfillment_status_rank (
    status         TEXT PRIMARY KEY,
    rank           INT NOT NULL
);

-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_order_lifecycle — ACCUMULATING SNAPSHOT (one row per order)
-- -----------------------------------------------------------------------------
-- Updated in place as milestones happen. Note first_shipped / all_delivered:
-- a split order has no single ship or delivery date, so the order grain can
-- only honestly carry the first and the last.
CREATE TABLE fact_order_lifecycle (
    lifecycle_sk                BIGSERIAL PRIMARY KEY,
    order_sk                    BIGINT NOT NULL REFERENCES dim_order(order_sk),
    customer_sk                 BIGINT NOT NULL REFERENCES dim_customer(customer_sk),
    placed_date_sk              INT NOT NULL REFERENCES dim_date(date_sk),
    payment_confirmed_date_sk   INT REFERENCES dim_date(date_sk),
    picked_date_sk              INT REFERENCES dim_date(date_sk),
    packed_date_sk              INT REFERENCES dim_date(date_sk),
    first_shipped_date_sk       INT REFERENCES dim_date(date_sk),
    all_delivered_date_sk       INT REFERENCES dim_date(date_sk),
    current_status              TEXT NOT NULL,   -- see fulfillment_status_rank
    shipment_count              INT NOT NULL DEFAULT 0,
    is_split_shipment           BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (order_sk)
);
CREATE INDEX idx_fol_status ON fact_order_lifecycle (current_status);
CREATE INDEX idx_fol_shipped ON fact_order_lifecycle (first_shipped_date_sk);

-- -----------------------------------------------------------------------------
-- fact_shipment — ACCUMULATING SNAPSHOT (one row per shipment)
-- -----------------------------------------------------------------------------
-- The finer grain the order-level fact can't give you: carrier transit time,
-- per-warehouse throughput. The order-level milestones on
-- fact_order_lifecycle are derived from this table (MIN shipped, MAX
-- delivered, COUNT(*) per order) and kept in sync by the event-apply process.
CREATE TABLE fact_shipment (
    shipment_sk       BIGSERIAL PRIMARY KEY,
    order_sk          BIGINT NOT NULL REFERENCES dim_order(order_sk),
    warehouse_sk      INT NOT NULL REFERENCES dim_warehouse(warehouse_sk),
    carrier_sk        INT NOT NULL REFERENCES dim_carrier(carrier_sk),
    packed_date_sk    INT REFERENCES dim_date(date_sk),
    shipped_date_sk   INT REFERENCES dim_date(date_sk),
    delivered_date_sk INT REFERENCES dim_date(date_sk),
    package_count     INT NOT NULL DEFAULT 1,
    current_status    TEXT NOT NULL,          -- same ranked ladder
    tracking_number   TEXT                    -- degenerate dimension; NULL until
                                              -- the carrier assigns a label
                                              -- (backordered shipments have none)
);
CREATE INDEX idx_fsh_order   ON fact_shipment (order_sk);
CREATE INDEX idx_fsh_carrier ON fact_shipment (carrier_sk);

-- -----------------------------------------------------------------------------
-- fact_shipment_event — RAW WEBHOOK ARRIVAL LOG (staging, not part of the star)
-- -----------------------------------------------------------------------------
-- One row per webhook delivery ATTEMPT as it arrived. event_date_sk is when
-- the event ACTUALLY happened (per the carrier payload); received_at is when
-- Crate Expectations' endpoint got it. When those two disagree — retries,
-- rate-limit queues — you have a late-arriving fact. The rank-based UPDATE
-- logic in the article consumes this table safely regardless of order.
CREATE TABLE fact_shipment_event (
    event_sk       BIGSERIAL PRIMARY KEY,
    shipment_sk    BIGINT REFERENCES fact_shipment(shipment_sk),
    order_sk       BIGINT REFERENCES dim_order(order_sk),
    carrier_sk     INT NOT NULL REFERENCES dim_carrier(carrier_sk),
    event_status   TEXT NOT NULL,             -- PICKED / PACKED / SHIPPED / DELIVERED
    event_date_sk  INT NOT NULL REFERENCES dim_date(date_sk),  -- true event time
    received_at    TIMESTAMP NOT NULL         -- arrival wall-clock (UTC), as logged
                                              -- by the endpoint; naive on purpose
                                              -- so date comparisons are stable
);
CREATE INDEX idx_fse_received ON fact_shipment_event (received_at);
