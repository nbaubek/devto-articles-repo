-- =============================================================================
-- Bean & Stalk — Exercise Solutions
-- =============================================================================
-- Referenced by exercises.sql. Try the exercises first!
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SOLUTION 1 — Fact vs. dimension classification
-- -----------------------------------------------------------------------------
-- A shift is an EVENT ("Nicola worked 7am-3pm at Mission on Tuesday"), so it
-- belongs in its own FACT table, e.g. fact_shift with measures hours_worked,
-- orders_completed, and FKs to dim_date, dim_store, dim_barista.
--
-- It is NOT an attribute on dim_barista because a barista has MANY shifts
-- (one per workday), and dim_barista is a one-row-per-barista table.
--
-- You could ALSO add shift_type ('OPENING','MIDDAY','CLOSING') as a small
-- dimension or junk-dimension flag on the fact — that's the descriptor side.


-- -----------------------------------------------------------------------------
-- SOLUTION 2 — Role-playing dates
-- -----------------------------------------------------------------------------
SELECT
    f.receipt_number,
    od.full_date AS ordered_on,
    pd.full_date AS picked_up_on,
    p.product_name
FROM fact_order_line f
JOIN dim_date    od ON od.date_sk = f.order_date_sk
JOIN dim_date    pd ON pd.date_sk = f.pickup_date_sk
JOIN dim_product p  ON p.product_sk = f.product_sk
WHERE pd.full_date > od.full_date
ORDER BY f.receipt_number;
-- Expected from seed: receipt 1004 (ordered Aug 5, picked up Aug 6).


-- -----------------------------------------------------------------------------
-- SOLUTION 3 — SCD2 as-of lookup
-- -----------------------------------------------------------------------------
SELECT product_id, product_name, base_price, valid_from, valid_to, is_current
FROM dim_product
WHERE product_id = 'OAT_LATTE'
  AND DATE '2025-04-01' BETWEEN valid_from
                            AND COALESCE(valid_to, DATE '9999-12-31');
-- Expected: one row with base_price = 4.75, valid_to = '2025-06-14'.


-- -----------------------------------------------------------------------------
-- SOLUTION 4 — Factless fact table design
-- -----------------------------------------------------------------------------

-- (a) CREATE TABLE
CREATE TABLE fact_drink_of_week (
    drink_of_week_sk BIGSERIAL PRIMARY KEY,
    product_sk       BIGINT NOT NULL REFERENCES dim_product(product_sk),
    week_start_sk    INT    NOT NULL REFERENCES dim_date(date_sk),
    store_sk         BIGINT NOT NULL REFERENCES dim_store(store_sk),
    UNIQUE (product_sk, week_start_sk, store_sk)
);

-- (b) Promotions per store in August 2025 (using existing availability table)
SELECT
    s.store_name,
    COUNT(*) AS promo_days
FROM fact_drink_availability a
JOIN dim_store s ON s.store_sk = a.store_sk
JOIN dim_date  d ON d.date_sk  = a.date_sk
WHERE a.is_promoted = true
  AND d.year = 2025 AND d.month_number = 8
GROUP BY s.store_name
ORDER BY promo_days DESC;
-- Expected: Mission has 2 promo days (Aug 1, Aug 2).


-- -----------------------------------------------------------------------------
-- SOLUTION 5 — Spot the anti-pattern
-- -----------------------------------------------------------------------------
-- Storing aggregates (monthly totals) next to base rows is the classic
-- "aggregates beside base rows" anti-pattern. The aggregates go stale the
-- moment a new order arrives, are expensive to maintain, and create a second
-- source of truth that drifts from the underlying facts.
--
-- Correct alternative: use the existing fact_daily_sales (periodic snapshot)
-- for fast aggregates, or compute aggregates at query time from
-- fact_order_line. Never store rollups beside the atomic fact.


-- -----------------------------------------------------------------------------
-- SOLUTION 6 — Choose the grain
-- -----------------------------------------------------------------------------
-- Grain: "One row per gift card TRANSACTION (purchase or redemption)."
--
-- Dimensions: dim_date (transaction date), dim_store (where it happened),
-- dim_customer (purchaser / redeemer if a loyalty member), and possibly a
-- degenerate dimension for gift_card_number.
--
-- Measures: amount (positive for purchase/load, negative for redemption),
-- running_balance (could be computed or stored on a separate accumulating
-- snapshot keyed by gift_card_id).
--
-- Why not one row per card? Because a card has many transactions over its
-- lifetime, and you'd lose the ability to analyze redemption patterns.


-- -----------------------------------------------------------------------------
-- SOLUTION 7 — Snowflake vs. star
-- -----------------------------------------------------------------------------
-- Keep the star. Denormalizing store_id onto dim_barista means every
-- barista-level query is a single hop to the store information, with no
-- extra bridge table. Columnar warehouses compress the repeated store_id
-- efficiently, so the storage cost of denormalization is negligible. And
-- human analysts can read and trust a flat dimension in seconds, whereas a
-- snowflaked barista-store bridge adds cognitive overhead for no real
-- benefit at this scale.


-- -----------------------------------------------------------------------------
-- SOLUTION 8 — Accumulating snapshot update
-- -----------------------------------------------------------------------------
-- Sam (customer_sk = 2) hit 10th purchase on 2025-08-12 (date_sk 20250812).
-- We need the date_sk for 2025-08-12 — which is 20250812.
UPDATE fact_loyalty_journey
SET tenth_purchase_date_sk = 20250812,
    first_to_tenth_days    = DATE '2025-08-12'
                           - (SELECT full_date
                              FROM dim_date
                              WHERE date_sk = first_purchase_date_sk),
    current_status         = 'REWARD_EARNED'
WHERE customer_sk = 2;
-- Before: Sam had tenth_purchase_date_sk = NULL, status = 'ACTIVE'.
-- After:  tenth_purchase_date_sk = 20250812, status = 'REWARD_EARNED',
--         first_to_tenth_days = 2025-08-12 - 2025-02-20 = 173 days.
