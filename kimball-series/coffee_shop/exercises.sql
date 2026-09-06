-- =============================================================================
-- Bean & Stalk — Practice Exercises
-- =============================================================================
-- Try each one before peeking at solutions.sql. Hints are inline as comments.
-- The companion article explains every concept these questions test.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXERCISE 1 — Fact vs. dimension classification
-- -----------------------------------------------------------------------------
-- Bean & Stalk wants to start tracking barista SHIFTS (who worked which store
-- on which day, start time, end time, total hours).
--
-- Question: Should "shift" be modeled as (a) its own FACT table,
--           (b) a DIMENSION, or (c) an attribute on dim_barista?
--           Defend your choice in a sentence.
--
-- Hint: Is a shift an EVENT (something that happens at a point in time) or a
--       DESCRIPTOR (a static property)? Events are verbs (facts). Descriptors
--       are nouns (dimensions). Could the same concept be both in different
--       contexts?


-- -----------------------------------------------------------------------------
-- EXERCISE 2 — Role-playing dates (write the SQL)
-- -----------------------------------------------------------------------------
-- Using fact_order_line with TWO role-playing date dimensions (order_date_sk
-- and pickup_date_sk), write a query that returns ONLY mobile pre-orders
-- where the pickup happened on a LATER DAY than the order.
--
-- Return: receipt_number, order date, pickup date, product_name.
--
-- Hint: Join dim_date twice with two different aliases. Compare the two
--       full_date values. The seed has one such row (receipt 1004).


-- -----------------------------------------------------------------------------
-- EXERCISE 3 — SCD2 as-of lookup
-- -----------------------------------------------------------------------------
-- Without touching fact_order_line, write a query against dim_product that
-- returns the base_price of 'OAT_LATTE' that was in effect on '2025-04-01'.
--
-- Your result should have exactly ONE row with base_price = 4.75 (the
-- pre-increase version).
--
-- Hint: Use BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31').
--       Why the COALESCE? Because the current row has valid_to = NULL.


-- -----------------------------------------------------------------------------
-- EXERCISE 4 — Factless fact table design
-- -----------------------------------------------------------------------------
-- Bean & Stalk runs a "Drink of the Week" promotion. Design a factless fact
-- table (call it fact_drink_of_week) that records which drink was promoted
-- at which store in which week.
--
-- (a) Write the CREATE TABLE.
-- (b) Write a query that counts promotions per store in August 2025 using
--     the existing fact_drink_availability table (which already has an
--     is_promoted flag).
--
-- Hint for (a): columns are product_sk, date_sk (use the first day of the
--               week), store_sk. No measures. The row IS the fact.
-- Hint for (b): SELECT FROM fact_drink_availability WHERE is_promoted.


-- -----------------------------------------------------------------------------
-- EXERCISE 5 — Spot the anti-pattern
-- -----------------------------------------------------------------------------
-- A junior analyst proposes adding these columns to fact_order_line:
--
--     monthly_total_revenue_for_product   NUMERIC(12,2)
--     monthly_total_revenue_for_store     NUMERIC(12,2)
--
-- Explain in 2-3 sentences why this is a bad idea, and name the correct
-- alternative (which table or which approach already exists in this schema).
--
-- Hint: This is the "storing aggregates next to base rows" anti-pattern.
--       Look at fact_daily_sales for the right pattern.


-- -----------------------------------------------------------------------------
-- EXERCISE 6 — Choose the grain
-- -----------------------------------------------------------------------------
-- Bean & Stalk wants to analyze GIFT CARD transactions: purchases of gift
-- cards, redemptions of gift cards, and remaining balances.
--
-- Propose a grain for a gift_card fact table. State it in one plain sentence.
-- Then list the dimensions you'd hang off it.
--
-- Hint: The grain should be "one row per ___". For gift cards, the most
--       flexible grain is usually one row per gift card TRANSACTION
--       (purchase or redemption), not one row per card.


-- -----------------------------------------------------------------------------
-- EXERCISE 7 — Snowflake vs. star
-- -----------------------------------------------------------------------------
-- dim_barista currently denormalizes store_id onto each barista row. A purist
-- argues this should be snowflaked into a dim_barista_store bridge.
--
-- Write 2-3 sentences arguing FOR keeping the star (denormalized), citing the
-- benefits mentioned in the article.
--
-- Hint: Query simplicity, one-hop joins, columnar compression favors wide
--       flat dimensions, humans can read a star in 30 seconds.


-- -----------------------------------------------------------------------------
-- EXERCISE 8 — Accumulating snapshot updates
-- -----------------------------------------------------------------------------
-- Customer Sam (customer_sk = 2) has just hit their 10th purchase on
-- '2025-08-12'. Write the UPDATE statement that records this milestone in
-- fact_loyalty_journey, including computing first_to_tenth_days.
--
-- Hint: UPDATE ... SET tenth_purchase_date_sk = ..., first_to_tenth_days =
--       (date '2025-08-12' - first purchase date). Look up first_purchase
--       from the same table or join dim_date.
