-- =============================================================================
-- Crate Expectations — Exercise Solutions
-- =============================================================================
-- Referenced by exercises.sql. Try the exercises first!
-- Note: SOLUTION 5 creates and populates fact_fulfillment_daily — harmless to
-- re-run (it drops the table first).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SOLUTION 1 — The grain fight: order, shipment, or package?
-- -----------------------------------------------------------------------------
-- Don't build it. Package-level detail belongs to the OPERATIONAL systems
-- (carrier tracking, warehouse scanning) — no business question in this
-- article needs "which box was the lamp in" in the analytical layer. The
-- cost is a third fact table, another grain to keep conformed dimensions
-- aligned with, and ETL for detail nobody queries. If a real question shows
-- up (e.g., damage claims per box), add fact_package THEN — grains earn
-- their existence by having questions that need them (the article's test:
-- "overkill for almost every question Crate Expectations actually asks").


-- -----------------------------------------------------------------------------
-- SOLUTION 2 — DELIVERED with no SHIPPED on file
-- -----------------------------------------------------------------------------
-- Ordinary out-of-order arrival means the SHIPPED event EXISTS and will show
-- up later — so you fill nothing now, and the milestone fills itself when it
-- lands. Here the event is gone for good, so shipped_date_sk would stay NULL
-- forever while delivered_date_sk is populated — and every transit-time
-- query silently drops the shipment (AVG ignores the NULL).
--
-- The status side needs nothing new: DELIVERED has the highest rank, so the
-- rank guard advances the status correctly no matter what's missing. The
-- decision is only about the milestone. Options:
--   (a) Leave the gap, flag the row (e.g. a data-quality column or a
--       quarantine report) — honest, and transit-time metrics exclude a
--       shipment you can't honestly measure. Recommended default.
--   (b) Backfill an inferred shipped date (delivered minus typical transit)
--       — makes averages look complete but quietly mixes measured and
--       fabricated dates. If you do this, mark inferred dates so they can
--       be excluded later.
-- The article's point: a clean-looking dataset and an honest one are not
-- always the same dataset.


-- -----------------------------------------------------------------------------
-- SOLUTION 3 — The rank-guarded, idempotent UPDATE
-- -----------------------------------------------------------------------------
-- (a) Applying event 8 (order_sk=2, 'PICKED', event_date_sk=20251105):
UPDATE fact_order_lifecycle f
SET
    picked_date_sk = COALESCE(f.picked_date_sk, 20251105),
    current_status = CASE
        WHEN (SELECT rank FROM fulfillment_status_rank WHERE status = 'PICKED')
             > (SELECT rank FROM fulfillment_status_rank WHERE status = f.current_status)
        THEN 'PICKED'
        ELSE f.current_status
    END
WHERE f.order_sk = 2;
--
-- Why each piece is safe:
--   * COALESCE — the first value to arrive for the milestone wins; a
--     duplicate retry can't overwrite it with a different date.
--   * The rank comparison — PICKED (3) vs the row's current DELIVERED (6)
--     doesn't advance, so the status cannot regress.
--   * Re-running the UPDATE is a no-op — idempotent by construction.
--
-- (b) Naive "latest webhook wins" would have set current_status = 'PICKED'
--     on 11-07 — visibly regressing a DELIVERED order on the ops dashboard
--     (and every aggregate keyed on status). Arrival order is not pipeline
--     order; that's the entire reason the rank table exists.


-- -----------------------------------------------------------------------------
-- SOLUTION 4 — Orders in transit, as-of
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS orders_in_transit
FROM fact_order_lifecycle
WHERE first_shipped_date_sk <= 20251115
  AND (all_delivered_date_sk IS NULL OR all_delivered_date_sk > 20251115);
-- Expected: 3 — ORD_5003 (chair not delivered), ORD_5004 (rug in transit),
-- ORD_5005 (in transit). ORD_5001/5002 fully delivered on/before 11-15,
-- ORD_5006 not shipped until 11-17.


-- -----------------------------------------------------------------------------
-- SOLUTION 5 — The periodic snapshot
-- -----------------------------------------------------------------------------
-- (a) One row per (snapshot date, warehouse, status). order_count is
-- SEMI-ADDITIVE: sum across warehouses at one date = meaningful; sum across
-- dates = meaningless (see Exercise 6).
CREATE TABLE fact_fulfillment_daily (
    daily_sk         BIGSERIAL PRIMARY KEY,
    snapshot_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    warehouse_sk     INT NOT NULL REFERENCES dim_warehouse(warehouse_sk),
    status           TEXT NOT NULL,            -- e.g. 'IN_TRANSIT'
    order_count      INT NOT NULL,
    UNIQUE (snapshot_date_sk, warehouse_sk, status)
);

-- (b) Populate 2025-11-15 from the two fact tables:
INSERT INTO fact_fulfillment_daily (snapshot_date_sk, warehouse_sk, status, order_count)
SELECT 20251115, s.warehouse_sk, 'IN_TRANSIT', COUNT(DISTINCT s.order_sk)
FROM fact_shipment s
JOIN fact_order_lifecycle f ON f.order_sk = s.order_sk
WHERE s.shipped_date_sk  <= 20251115
  AND (s.delivered_date_sk IS NULL OR s.delivered_date_sk > 20251115)
GROUP BY s.warehouse_sk;
-- Expected: East = 2 (ORD_5004's rug, ORD_5005), West = 1 (ORD_5003's
-- chair). The distinct-count matters: an order with two in-transit
-- shipments from two warehouses counts once PER warehouse — summing across
-- warehouses on one day is the additive direction, and it still lands on 3.


-- -----------------------------------------------------------------------------
-- SOLUTION 6 — Semi-additive trap
-- -----------------------------------------------------------------------------
-- Two things wrong: (1) "orders in transit" is a STATE — summing 20 daily
-- counts mostly re-counts the same orders day after day, so the number has
-- no interpretation (it is not "orders shipped this month"; that question
-- needs COUNT of orders with first_shipped_date_sk in the month). (2) The
-- chart title claims a FLOW meaning for a STATE measure — exactly the
-- "quiet, easy-to-miss error" the article warns about: nothing errors, the
-- number just means something different than the reader assumes.
--
-- Fully additive contrasts: daily_revenue in Part 1's fact_daily_sales
-- (30 days sum to the month) and billed_amount in Part 4's fact_claim_line.
-- Rule of thumb: check what the sum MEANS before summing across the date
-- dimension.


-- -----------------------------------------------------------------------------
-- SOLUTION 7 — shipment_count: store or compute?
-- -----------------------------------------------------------------------------
-- Stored because order-level queries that filter or group on it ("share of
-- split orders," "single-shipment vs split" — Q1 in queries.sql) would
-- otherwise pay a join + COUNT(*) against fact_shipment on every query, for
-- a number that changes rarely. That's the same store-vs-recompute tradeoff
-- that justifies periodic snapshots.
--
-- Risk: drift — if shipments and the count are updated by different
-- processes, the count goes stale. Guard: the ONE process that applies
-- shipment events updates both tables in the same transaction (the article:
-- order-level milestones are "derived ... from fact_shipment ... kept in
-- sync by whatever process applies shipment events"). A cheap reconciliation
-- query can verify it:
SELECT f.order_sk, f.shipment_count AS stored_count, COUNT(s.shipment_sk) AS actual_count
FROM fact_order_lifecycle f
LEFT JOIN fact_shipment s ON s.order_sk = f.order_sk
GROUP BY f.order_sk, f.shipment_count
HAVING f.shipment_count <> COUNT(s.shipment_sk);
-- Expected: no rows. If this ever returns rows, the sync process skipped one.


-- -----------------------------------------------------------------------------
-- SOLUTION 8 — Spot the anti-pattern
-- -----------------------------------------------------------------------------
-- It's a fixed-width guess at a variable-length list — the exact mistake the
-- article flags (same family as diagnosis_1/2/3_sk in Part 4): it silently
-- caps orders at three shipments, invites NULL-heavy sparse columns, and
-- forces every carrier question to fan across N numbered columns. The
-- correct home for carrier-per-shipment already exists: fact_shipment, one
-- row per shipment with its own carrier_sk, packed/shipped/delivered dates —
-- and fact_order_lifecycle keeps only what's honest at the order grain
-- (first_shipped, all_delivered, shipment_count).
