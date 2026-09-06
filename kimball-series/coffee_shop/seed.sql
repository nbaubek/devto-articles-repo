-- =============================================================================
-- Bean & Stalk — Sample Data
-- =============================================================================
-- Small, readable, hand-crafted so every query in queries.sql has a story.
-- Run AFTER schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date — Aug 2025 + key dates referenced elsewhere in the seed
-- -----------------------------------------------------------------------------
-- (In production you'd generate the full calendar. Here we keep it readable
--  and just include every date the rest of the seed references.)
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_number, month_number, month_name, quarter, year, is_weekend, holiday_name) VALUES
    (20250101, '2025-01-01', 'Wednesday', 1, 1, 'January', 1, 2025, false, 'New Year''s Day'),
    (20250115, '2025-01-15', 'Wednesday',15, 1, 'January', 1, 2025, false, NULL),  -- Alex signup / 1st purchase
    (20250220, '2025-02-20', 'Thursday', 20, 2, 'February',1, 2025, false, NULL),  -- Sam signup / 1st purchase
    (20250310, '2025-03-10', 'Monday',   10, 3, 'March',   1, 2025, false, NULL),  -- Jordan signup
    (20250401, '2025-04-01', 'Tuesday',   1, 4, 'April',   2, 2025, false, NULL),  -- Alex 5th purchase
    (20250405, '2025-04-05', 'Saturday',  5, 4, 'April',   2, 2025, true,  NULL),  -- Casey signup / 1st
    (20250522, '2025-05-22', 'Thursday', 22, 5, 'May',     2, 2025, false, NULL),  -- Morgan signup
    (20250614, '2025-06-14', 'Saturday', 14, 6, 'June',    2, 2025, true,  NULL),  -- SCD2 boundary (oat latte)
    (20250615, '2025-06-15', 'Sunday',   15, 6, 'June',    2, 2025, true,  NULL),  -- SCD2 boundary (oat latte)
    (20250704, '2025-07-04', 'Friday',    4, 7, 'July',    3, 2025, false, 'Independence Day'),
    (20250720, '2025-07-20', 'Sunday',   20, 7, 'July',    3, 2025, true,  NULL),  -- Alex 10th purchase
    (20250801, '2025-08-01', 'Friday',    1, 8, 'August',  3, 2025, false, NULL),
    (20250802, '2025-08-02', 'Saturday',  2, 8, 'August',  3, 2025, true,  NULL),
    (20250803, '2025-08-03', 'Sunday',    3, 8, 'August',  3, 2025, true,  NULL),
    (20250804, '2025-08-04', 'Monday',    4, 8, 'August',  3, 2025, false, NULL),
    (20250805, '2025-08-05', 'Tuesday',   5, 8, 'August',  3, 2025, false, NULL),
    (20250806, '2025-08-06', 'Wednesday', 6, 8, 'August',  3, 2025, false, NULL),
    (20250807, '2025-08-07', 'Thursday',  7, 8, 'August',  3, 2025, false, NULL),
    (20250808, '2025-08-08', 'Friday',    8, 8, 'August',  3, 2025, false, NULL),
    (20250809, '2025-08-09', 'Saturday',  9, 8, 'August',  3, 2025, true,  NULL),
    (20250810, '2025-08-10', 'Sunday',   10, 8, 'August',  3, 2025, true,  NULL),
    (20250811, '2025-08-11', 'Monday',   11, 8, 'August',  3, 2025, false, NULL),
    (20250812, '2025-08-12', 'Tuesday',  12, 8, 'August',  3, 2025, false, NULL),
    (20250813, '2025-08-13', 'Wednesday',13, 8, 'August',  3, 2025, false, NULL),
    (20250814, '2025-08-14', 'Thursday', 14, 8, 'August',  3, 2025, false, NULL),
    (20250815, '2025-08-15', 'Friday',   15, 8, 'August',  3, 2025, false, NULL),
    (20250816, '2025-08-16', 'Saturday', 16, 8, 'August',  3, 2025, true,  NULL),
    (20250817, '2025-08-17', 'Sunday',   17, 8, 'August',  3, 2025, true,  NULL);

-- -----------------------------------------------------------------------------
-- dim_product — SCD Type 2 (oat-milk latte has two versions)
-- -----------------------------------------------------------------------------
INSERT INTO dim_product (product_id, product_name, category, base_price, recipe_notes, valid_from, valid_to, is_current) VALUES
    ('OAT_LATTE',  'Oat-Milk Latte', 'ESPRESSO_DRINK', 4.75, 'Original oat milk vendor', '2025-01-01', '2025-06-14', false),
    ('OAT_LATTE',  'Oat-Milk Latte', 'ESPRESSO_DRINK', 5.25, 'Switched to Oatly Barista', '2025-06-15', NULL,         true),
    ('DRIP_LARGE', 'Large Drip',     'DRIP',           3.50, 'House blend',               '2025-01-01', NULL,         true),
    ('CAPPUCCINO', 'Cappuccino',     'ESPRESSO_DRINK', 4.25, 'Classic 6oz',               '2025-01-01', NULL,         true),
    ('PSL',        'Pumpkin Spice Latte', 'ESPRESSO_DRINK', 5.75, 'Seasonal — fall 2025',  '2025-08-01', NULL,        true),
    ('MUFFIN_BB',  'Blueberry Muffin','PASTRY',         3.25, 'Baked in-house',            '2025-01-01', NULL,        true),
    ('CROISSANT',  'Butter Croissant','PASTRY',         3.75, 'All-butter, daily delivery','2025-01-01', NULL,        true),
    ('BAG_BEANS',  'Bag of Beans',   'BEANS',          18.00, '12oz single-origin',        '2025-01-01', NULL,        true);

-- -----------------------------------------------------------------------------
-- dim_customer — loyalty members
-- -----------------------------------------------------------------------------
INSERT INTO dim_customer (customer_id, name, email, loyalty_number, signup_date, loyalty_tier) VALUES
    ('CUST_001', 'Alex Park',     'alex@example.com',    'LY-1001', '2025-01-15', 'GOLD'),
    ('CUST_002', 'Sam Rivera',    'sam@example.com',     'LY-1002', '2025-02-20', 'SILVER'),
    ('CUST_003', 'Jordan Lee',    'jordan@example.com',  'LY-1003', '2025-03-10', 'BRONZE'),
    ('CUST_004', 'Casey Wu',      'casey@example.com',   'LY-1004', '2025-04-05', 'SILVER'),
    ('CUST_005', 'Morgan Chen',   'morgan@example.com',  'LY-1005', '2025-05-22', 'BRONZE');

-- -----------------------------------------------------------------------------
-- dim_store
-- -----------------------------------------------------------------------------
INSERT INTO dim_store (store_id, store_name, city, state, opening_date, sq_ft) VALUES
    ('MISSION', 'Bean & Stalk Mission',  'San Francisco', 'CA', '2022-03-01', 850),
    ('HAYES',   'Bean & Stalk Hayes Valley','San Francisco','CA','2024-09-15', 1100);

-- -----------------------------------------------------------------------------
-- dim_barista
-- -----------------------------------------------------------------------------
INSERT INTO dim_barista (barista_id, barista_name, store_id, hire_date, specialty) VALUES
    ('BAR_001', 'Nicola Ortiz', 'MISSION', '2022-05-01', 'LATTE_ART'),
    ('BAR_002', 'Dev Patel',    'MISSION', '2023-01-15', 'POUR_OVER'),
    ('BAR_003', 'Rae Kim',      'HAYES',   '2024-10-01', 'VIBES'),
    ('BAR_004', 'Tomas Silva',  'HAYES',   '2025-02-01', 'LATTE_ART');

-- -----------------------------------------------------------------------------
-- dim_junk — common drink-config combos
-- -----------------------------------------------------------------------------
INSERT INTO dim_junk (size, milk_type, syrup_flavor, extra_shot) VALUES
    ('SMALL',  'NONE',  'NONE',     false),   -- 1: straight espresso
    ('MEDIUM', 'OAT',   'NONE',     false),   -- 2: standard oat latte
    ('MEDIUM', 'OAT',   'VANILLA',  false),   -- 3: vanilla oat latte
    ('LARGE',  'WHOLE', 'NONE',     false),   -- 4: big latte
    ('LARGE',  'OAT',   'CARAMEL',  true),    -- 5: max treat
    ('LARGE',  'ALMOND','NONE',     false),   -- 6
    ('MEDIUM', 'SOY',   'HAZELNUT', false),   -- 7
    ('MEDIUM', 'NONE',  'NONE',     false),   -- 8: black drip / americano config
    ('SMALL',  'WHOLE', 'NONE',     false),   -- 9: cappuccino
    ('MEDIUM', 'OAT',   'NONE',     true);    -- 10: extra-shot oat latte

-- -----------------------------------------------------------------------------
-- fact_order_line — TRANSACTION FACT (the real workhorse)
-- -----------------------------------------------------------------------------
-- Each row is a line on a receipt. Note product_sk points at the SCD2 row
-- that was valid AT THE TIME of the order (so pre-2025-06-15 rows use sk=1,
-- the $4.75 row; post- rows use sk=2, the $5.25 row).
INSERT INTO fact_order_line
    (receipt_number, order_date_sk, pickup_date_sk, product_sk, customer_sk, store_sk, barista_sk, junk_sk, quantity, unit_price, discount_amount, line_total) VALUES
    -- Aug 1: Alex gets an oat latte (pre-price-increase? No — Aug is post-6/15)
    (1001, 20250801, 20250801, 2, 1, 1, 1, 2,  1, 5.25, 0.00, 5.25),  -- oat latte
    (1001, 20250801, 20250801, 6, 1, 1, 1, 5,  1, 3.25, 0.00, 3.25),  -- blueberry muffin
    -- Aug 2 (Sat): Sam, two drinks
    (1002, 20250802, 20250802, 2, 2, 1, 2, 3,  1, 5.25, 0.00, 5.25),  -- vanilla oat latte
    (1002, 20250802, 20250802, 3, 2, 1, 2, 8,  2, 3.50, 0.00, 7.00),  -- 2 large drips (sk=3)
    -- Aug 4: Jordan, walk-in (no customer), cappuccino
    (1003, 20250804, 20250804, 4, NULL, 1, 1, 9, 1, 4.25, 0.00, 4.25),
    -- Aug 5: Casey mobile pre-orders for Aug 6 pickup
    (1004, 20250805, 20250806, 2, 4, 2, 3, 2,  1, 5.25, 0.00, 5.25),
    (1004, 20250805, 20250806, 7, 4, 2, 3, 5,  1, 3.75, 0.00, 3.75),  -- croissant
    -- Aug 6: Morgan — PSL (seasonal, available from Aug 1)
    (1005, 20250806, 20250806, 5, 5, 2, 4, 5,  2, 5.75, 1.00, 10.50), -- 2 PSLs, $1 loyalty discount
    -- Aug 9 (Sat): big Saturday at Hayes
    (1006, 20250809, 20250809, 2, NULL, 2, 3, 2,  1, 5.25, 0.00, 5.25),
    (1006, 20250809, 20250809, 4, NULL, 2, 3, 9,  1, 4.25, 0.00, 4.25),
    (1006, 20250809, 20250809, 6, NULL, 2, 4, 5,  1, 3.25, 0.00, 3.25),
    -- Aug 11: Alex again, two oat lattes (one extra shot)
    (1007, 20250811, 20250811, 2, 1, 1, 1, 2,  1, 5.25, 0.00, 5.25),
    (1007, 20250811, 20250811, 2, 1, 1, 1, 10, 1, 5.75, 0.00, 5.75), -- extra-shot oat latte
    -- Aug 12: Sam, drip + muffin
    (1008, 20250812, 20250812, 3, 2, 1, 2, 8,  1, 3.50, 0.00, 3.50),
    (1008, 20250812, 20250812, 6, 2, 1, 2, 5,  1, 3.25, 0.00, 3.25),
    -- Aug 13: walk-in, beans to take home
    (1009, 20250813, 20250813, 8, NULL, 1, 1, 8,  1, 18.00, 0.00, 18.00),
    -- Aug 14: Jordan, oat latte (SILVER? still BRONZE per dim)
    (1010, 20250814, 20250814, 2, 3, 1, 1, 2,  1, 5.25, 0.00, 5.25);

-- -----------------------------------------------------------------------------
-- fact_daily_sales — PERIODIC SNAPSHOT (pre-aggregated for a few days)
-- -----------------------------------------------------------------------------
-- In production this would be built nightly from fact_order_line. Here we
-- insert a handful of representative rows to demonstrate the shape.
INSERT INTO fact_daily_sales (snapshot_date_sk, store_sk, product_sk, daily_quantity, daily_revenue, transaction_count) VALUES
    (20250801, 1, 2, 1, 5.25, 1),
    (20250801, 1, 6, 1, 3.25, 1),
    (20250802, 1, 2, 1, 5.25, 1),
    (20250802, 1, 3, 2, 7.00, 1),
    (20250804, 1, 4, 1, 4.25, 1),
    (20250805, 2, 2, 1, 5.25, 1),
    (20250805, 2, 7, 1, 3.75, 1),
    (20250806, 2, 5, 2, 10.50, 1),
    (20250809, 2, 2, 1, 5.25, 1),
    (20250809, 2, 4, 1, 4.25, 1),
    (20250809, 2, 6, 1, 3.25, 1),
    (20250811, 1, 2, 2, 11.00, 2),
    (20250812, 1, 3, 1, 3.50, 1),
    (20250812, 1, 6, 1, 3.25, 1),
    (20250813, 1, 8, 1, 18.00, 1),
    (20250814, 1, 2, 1, 5.25, 1);

-- -----------------------------------------------------------------------------
-- fact_loyalty_journey — ACCUMULATING SNAPSHOT
-- -----------------------------------------------------------------------------
-- One row per loyalty member. Milestones filled in as they happen.
INSERT INTO fact_loyalty_journey
    (customer_sk, signup_date_sk, first_purchase_date_sk, fifth_purchase_date_sk, tenth_purchase_date_sk, current_status, signup_to_first_days, first_to_tenth_days) VALUES
    (1, 20250115, 20250115, 20250401, 20250720, 'REWARD_EARNED', 0, 186),
    (2, 20250220, 20250220, 20250615, NULL,     'ACTIVE',        0, NULL),
    (3, 20250310, 20250804, NULL,     NULL,     'ACTIVE',        147, NULL),
    (4, 20250405, 20250405, 20250805, NULL,     'ACTIVE',        0,   NULL),
    (5, 20250522, 20250806, NULL,     NULL,     'ACTIVE',        76,  NULL);

-- -----------------------------------------------------------------------------
-- fact_drink_availability — FACTLESS FACT TABLE
-- -----------------------------------------------------------------------------
-- PSL available at both stores from Aug 1, 2025. Blueberry muffin promoted
-- (drink-of-the-week style) at Mission on Aug 1.
INSERT INTO fact_drink_availability (product_sk, date_sk, store_sk, is_promoted) VALUES
    (5, 20250801, 1, false),
    (5, 20250801, 2, false),
    (5, 20250802, 1, false),
    (5, 20250802, 2, false),
    (5, 20250803, 1, false),
    (5, 20250803, 2, false),
    (6, 20250801, 1, true),    -- muffin promo at Mission
    (6, 20250802, 1, true);
