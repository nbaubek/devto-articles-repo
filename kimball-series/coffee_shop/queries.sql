-- =============================================================================
-- Bean & Stalk — Example Queries (referenced in the article)
-- =============================================================================
-- Run AFTER schema.sql + seed.sql. Each block is self-contained.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. Top drinks by month (the article's headline query)
-- -----------------------------------------------------------------------------
SELECT
    d.year,
    d.month_name,
    p.product_name,
    SUM(f.quantity)    AS total_sold,
    SUM(f.line_total)  AS revenue
FROM fact_order_line f
JOIN dim_date    d ON d.date_sk  = f.order_date_sk
JOIN dim_product p ON p.product_sk = f.product_sk
WHERE d.year = 2025
GROUP BY d.year, d.month_number, d.month_name, p.product_name
ORDER BY d.month_number, revenue DESC;


-- -----------------------------------------------------------------------------
-- Q2. Barista leaderboard for the top-selling drink of the year
-- -----------------------------------------------------------------------------
WITH top_drink AS (
    SELECT p.product_sk, p.product_name
    FROM fact_order_line f
    JOIN dim_product p ON p.product_sk = f.product_sk
    GROUP BY p.product_sk, p.product_name
    ORDER BY SUM(f.line_total) DESC
    LIMIT 1
)
SELECT
    b.barista_name,
    SUM(f.quantity)   AS drinks_made,
    SUM(f.line_total) AS revenue
FROM fact_order_line f
JOIN dim_barista  b ON b.barista_sk = f.barista_sk
JOIN top_drink    t ON t.product_sk = f.product_sk
GROUP BY b.barista_name
ORDER BY revenue DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q3. Role-playing date dimensions: mobile pre-orders for a future day
--     (pickup_date > order_date) — demonstrates joining dim_date twice.
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


-- -----------------------------------------------------------------------------
-- Q4. SCD2-aware revenue: oat-milk latte, using the price that was in effect
--     at the time of each transaction.
-- -----------------------------------------------------------------------------
-- The fact's product_sk already points at the correct historical dim_product
-- row, so no extra date filter on the dimension is required.
SELECT
    p.product_id,
    p.base_price AS price_at_time,
    SUM(f.quantity)   AS units,
    SUM(f.line_total) AS revenue
FROM fact_order_line f
JOIN dim_product p ON p.product_sk = f.product_sk
WHERE p.product_id = 'OAT_LATTE'
GROUP BY p.product_id, p.base_price, p.valid_from
ORDER BY p.valid_from;


-- -----------------------------------------------------------------------------
-- Q5. As-of lookup: "what plan/price was in effect for product X on date Y?"
--     Demonstrates the SCD2 temporal lookup pattern.
-- -----------------------------------------------------------------------------
-- "What was the base price of OAT_LATTE on 2025-03-01 (before the increase)?"
SELECT product_id, product_name, base_price, valid_from, valid_to, is_current
FROM dim_product
WHERE product_id = 'OAT_LATTE'
  AND DATE '2025-03-01' BETWEEN valid_from AND COALESCE(valid_to, DATE '9999-12-31');


-- -----------------------------------------------------------------------------
-- Q6. Using the PERIODIC SNAPSHOT for a fast trend chart
--     (instead of scanning fact_order_line for every render)
-- -----------------------------------------------------------------------------
SELECT
    d.full_date,
    s.store_name,
    SUM(ds.daily_revenue) AS store_revenue
FROM fact_daily_sales ds
JOIN dim_date  d ON d.date_sk = ds.snapshot_date_sk
JOIN dim_store s ON s.store_sk = ds.store_sk
WHERE d.year = 2025 AND d.month_number = 8
GROUP BY d.full_date, s.store_name
ORDER BY d.full_date, s.store_name;


-- -----------------------------------------------------------------------------
-- Q7. Accumulating snapshot: how long from loyalty signup to first purchase?
-- -----------------------------------------------------------------------------
SELECT
    c.name,
    j.current_status,
    j.signup_to_first_days,
    j.first_to_tenth_days
FROM fact_loyalty_journey j
JOIN dim_customer c ON c.customer_sk = j.customer_sk
ORDER BY j.signup_to_first_days DESC;


-- -----------------------------------------------------------------------------
-- Q8. Factless fact table: how many days was the PSL available at each store?
-- -----------------------------------------------------------------------------
SELECT
    s.store_name,
    COUNT(*) AS days_available
FROM fact_drink_availability a
JOIN dim_product p ON p.product_sk = a.product_sk
JOIN dim_store   s ON s.store_sk   = a.store_sk
WHERE p.product_id = 'PSL'
GROUP BY s.store_name;


-- -----------------------------------------------------------------------------
-- Q9. Junk dimension in action: revenue by milk type
-- -----------------------------------------------------------------------------
SELECT
    j.milk_type,
    SUM(f.quantity)   AS drinks_sold,
    SUM(f.line_total) AS revenue
FROM fact_order_line f
JOIN dim_junk j ON j.junk_sk = f.junk_sk
GROUP BY j.milk_type
ORDER BY revenue DESC;


-- -----------------------------------------------------------------------------
-- Q10. Year-over-year growth at the store level (uses periodic snapshot)
-- -----------------------------------------------------------------------------
-- (Requires data spanning multiple years in a fuller dataset; the seed only
--  has Aug 2025, so this query returns one year. The shape is what matters.)
SELECT
    d.year,
    s.store_name,
    SUM(ds.daily_revenue) AS revenue
FROM fact_daily_sales ds
JOIN dim_date  d ON d.date_sk = ds.snapshot_date_sk
JOIN dim_store s ON s.store_sk = ds.store_sk
GROUP BY d.year, s.store_name
ORDER BY d.year, s.store_name;
