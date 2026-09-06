-- =============================================================================
-- Crate Expectations — Example Queries (referenced in the article)
-- =============================================================================
-- Run AFTER schema.sql + seed.sql. Each block is self-contained.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. Average days from placed to fully delivered, single-warehouse vs. split
--     (the article's headline query)
-- -----------------------------------------------------------------------------
-- Expected from seed: single = 4.0 days over 2 orders (ORD_5001: 5d,
-- ORD_5006: 3d); split = 8.0 days over 1 order (ORD_5002). Split orders are
-- held to their SLOWEST shipment — that's what all_delivered_date_sk means.
SELECT
    f.is_split_shipment,
    COUNT(*)                                        AS order_count,
    AVG(d_delivered.full_date - d_placed.full_date) AS avg_days_to_deliver
FROM fact_order_lifecycle f
JOIN dim_date d_placed    ON d_placed.date_sk   = f.placed_date_sk
JOIN dim_date d_delivered ON d_delivered.date_sk = f.all_delivered_date_sk
WHERE f.all_delivered_date_sk IS NOT NULL
GROUP BY f.is_split_shipment;


-- -----------------------------------------------------------------------------
-- Q2. Slowest carrier by average transit time — at the SHIPMENT grain, where
--     that question actually lives (the article's second real query)
-- -----------------------------------------------------------------------------
-- Expected from seed: FastFreight 3.67d over 3 delivered shipments;
-- RoadRunner 2.5d over 2. Undelivered shipments are excluded — their
-- delivered_date_sk is NULL and AVG would silently drop them anyway.
SELECT
    c.carrier_name,
    AVG(d_delivered.full_date - d_shipped.full_date) AS avg_transit_days,
    COUNT(*)                                          AS delivered_count
FROM fact_shipment s
JOIN dim_carrier c        ON c.carrier_sk        = s.carrier_sk
JOIN dim_date d_shipped    ON d_shipped.date_sk   = s.shipped_date_sk
JOIN dim_date d_delivered  ON d_delivered.date_sk = s.delivered_date_sk
WHERE s.delivered_date_sk IS NOT NULL
GROUP BY c.carrier_name
ORDER BY avg_transit_days DESC;


-- -----------------------------------------------------------------------------
-- Q3. Orders in transit as of end of 2025-11-15 — the semi-additive measure,
--     reconstructed from the accumulating snapshot (no snapshot table needed)
-- -----------------------------------------------------------------------------
-- Expected from seed: 3 (ORD_5003 chair, ORD_5004 rug, ORD_5005).
-- Shipped-but-not-fully-delivered as of the as-of date. Fine for one date;
-- see the article for when to materialize fact_fulfillment_daily instead.
SELECT COUNT(*) AS orders_in_transit
FROM fact_order_lifecycle
WHERE first_shipped_date_sk <= 20251115
  AND (all_delivered_date_sk IS NULL OR all_delivered_date_sk > 20251115);


-- -----------------------------------------------------------------------------
-- Q4. Pipeline status distribution — what the ops dashboard shows
-- -----------------------------------------------------------------------------
-- Expected from seed: 3 DELIVERED (ORD_5001/5002/5006), 3 SHIPPED
-- (ORD_5003/5004/5005). current_status is "furthest point reached," not
-- "latest webhook received" — that distinction is the whole point of
-- fulfillment_status_rank.
SELECT
    f.current_status,
    r.rank,
    COUNT(*)          AS orders
FROM fact_order_lifecycle f
JOIN fulfillment_status_rank r ON r.status = f.current_status
GROUP BY f.current_status, r.rank
ORDER BY r.rank;


-- -----------------------------------------------------------------------------
-- Q5. The two webhook anomalies in the raw arrival log, by lag
-- -----------------------------------------------------------------------------
-- Expected from seed: exactly two rows — event 8 (PICKED for shipment 3,
-- arrived two days late, AFTER that shipment's SHIPPED event) and event 4
-- (the duplicate SHIPPED retry for shipment 1). Naive "latest webhook wins"
-- logic would have flipped ORD_5002's status backward when event 8 landed —
-- the rank guard is what keeps that from happening.
SELECT
    e.event_sk,
    e.event_status,
    e.event_date_sk,
    e.received_at,
    e.received_at::DATE - e.event_date_sk::TEXT::DATE AS arrival_lag_days
FROM fact_shipment_event e
WHERE e.received_at::DATE > e.event_date_sk::TEXT::DATE
ORDER BY arrival_lag_days DESC, e.event_sk;
