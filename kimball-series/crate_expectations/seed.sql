-- =============================================================================
-- Crate Expectations — Sample Data
-- =============================================================================
-- Small, hand-crafted so every query in queries.sql has a story:
--   * ORD_5001  single warehouse, clean delivery (the baseline)
--   * ORD_5002  split East/West, both delivered (couch was slow, lamp fast)
--   * ORD_5003  split, desk delivered but chair STILL IN TRANSIT
--   * ORD_5004  split, rug in transit + bookshelf BACKORDERED (never picked)
--   * ORD_5005  single, in transit
--   * ORD_5006  single, quick West-coast delivery (gives RoadRunner a 2nd leg)
-- The raw webhook log (fact_shipment_event) carries two deliberate anomalies:
-- a duplicate SHIPPED retry and a PICKED event that arrived AFTER the SHIPPED
-- event for the same shipment. Run AFTER schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date — Nov 1-20, 2025 (every date the rest of the seed references)
-- -----------------------------------------------------------------------------
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_number, month_number, month_name, quarter, year, is_weekend, holiday_name) VALUES
    (20251101, '2025-11-01', 'Saturday', 1, 11, 'November', 4, 2025, true,  NULL),
    (20251102, '2025-11-02', 'Sunday',   2, 11, 'November', 4, 2025, true,  NULL),
    (20251103, '2025-11-03', 'Monday',   3, 11, 'November', 4, 2025, false, NULL),
    (20251104, '2025-11-04', 'Tuesday',  4, 11, 'November', 4, 2025, false, NULL),
    (20251105, '2025-11-05', 'Wednesday',5, 11, 'November', 4, 2025, false, NULL),
    (20251106, '2025-11-06', 'Thursday', 6, 11, 'November', 4, 2025, false, NULL),
    (20251107, '2025-11-07', 'Friday',   7, 11, 'November', 4, 2025, false, NULL),
    (20251108, '2025-11-08', 'Saturday', 8, 11, 'November', 4, 2025, true,  NULL),
    (20251109, '2025-11-09', 'Sunday',   9, 11, 'November', 4, 2025, true,  NULL),
    (20251110, '2025-11-10', 'Monday',  10, 11, 'November', 4, 2025, false, NULL),
    (20251111, '2025-11-11', 'Tuesday', 11, 11, 'November', 4, 2025, false, 'Veterans Day'),
    (20251112, '2025-11-12', 'Wednesday',12,11, 'November', 4, 2025, false, NULL),
    (20251113, '2025-11-13', 'Thursday',13, 11, 'November', 4, 2025, false, NULL),
    (20251114, '2025-11-14', 'Friday',  14, 11, 'November', 4, 2025, false, NULL),
    (20251115, '2025-11-15', 'Saturday',15, 11, 'November', 4, 2025, true,  NULL),
    (20251116, '2025-11-16', 'Sunday',  16, 11, 'November', 4, 2025, true,  NULL),
    (20251117, '2025-11-17', 'Monday',  17, 11, 'November', 4, 2025, false, NULL),
    (20251118, '2025-11-18', 'Tuesday', 18, 11, 'November', 4, 2025, false, NULL),
    (20251119, '2025-11-19', 'Wednesday',19,11, 'November', 4, 2025, false, NULL),
    (20251120, '2025-11-20', 'Thursday',20, 11, 'November', 4, 2025, false, NULL);

-- -----------------------------------------------------------------------------
-- fulfillment_status_rank — the ordered pipeline
-- -----------------------------------------------------------------------------
INSERT INTO fulfillment_status_rank (status, rank) VALUES
    ('PLACED',            1),
    ('PAYMENT_CONFIRMED', 2),
    ('PICKED',            3),
    ('PACKED',            4),
    ('SHIPPED',           5),
    ('DELIVERED',         6);

-- -----------------------------------------------------------------------------
-- dim_customer
-- -----------------------------------------------------------------------------
INSERT INTO dim_customer (customer_sk, customer_id, customer_name, city, state, is_trade) VALUES
    (1, 'CUST_101', 'Priya Nair',     'Austin',      'TX', false),
    (2, 'CUST_102', 'Marcus Webb',    'Denver',      'CO', false),
    (3, 'CUST_103', 'Elena Rossi',    'Portland',    'OR', true),
    (4, 'CUST_104', 'Tomás Ferreira', 'Chicago',     'IL', false),
    (5, 'CUST_105', 'Aisha Bello',    'Minneapolis', 'MN', false);

-- -----------------------------------------------------------------------------
-- dim_order
-- -----------------------------------------------------------------------------
INSERT INTO dim_order (order_sk, order_id, channel, is_gift) VALUES
    (1, 'ORD_5001', 'WEB',   false),
    (2, 'ORD_5002', 'WEB',   false),
    (3, 'ORD_5003', 'STORE', false),
    (4, 'ORD_5004', 'WEB',   true),    -- gift, hence the recipient address note
    (5, 'ORD_5005', 'PHONE', false),
    (6, 'ORD_5006', 'WEB',   false);

-- -----------------------------------------------------------------------------
-- dim_warehouse / dim_carrier
-- -----------------------------------------------------------------------------
INSERT INTO dim_warehouse (warehouse_sk, warehouse_id, warehouse_name, city, state, opening_date) VALUES
    (1, 'EAST', 'Newark Fulfillment East', 'Newark', 'NJ', '2021-04-01'),
    (2, 'WEST', 'Reno Fulfillment West',   'Reno',   'NV', '2023-02-15');

INSERT INTO dim_carrier (carrier_sk, carrier_id, carrier_name, webhook_api) VALUES
    (1, 'FASTFREIGHT', 'FastFreight',        'fastfreight.io/hooks/v2'),
    (2, 'ROADRUNNER',  'RoadRunner Parcel',  'roadrunner.example/webhooks/v1');

-- -----------------------------------------------------------------------------
-- fact_shipment — one row per shipment (write before the lifecycle so the
-- story reads bottom-up: shipments first, then the order-level rollups)
-- -----------------------------------------------------------------------------
INSERT INTO fact_shipment
    (shipment_sk, order_sk, warehouse_sk, carrier_sk, packed_date_sk, shipped_date_sk, delivered_date_sk, package_count, current_status, tracking_number) VALUES
    -- ORD_5001: single, clean
    (1, 1, 1, 1, 20251104, 20251105, 20251108, 1, 'DELIVERED', 'TRK-FF-101'),
    -- ORD_5002: SPLIT — couch (East/FastFreight, 2 boxes) + lamp (West/RoadRunner)
    (2, 2, 1, 1, 20251105, 20251107, 20251112, 2, 'DELIVERED', 'TRK-FF-102'),
    (3, 2, 2, 2, 20251105, 20251106, 20251109, 1, 'DELIVERED', 'TRK-RR-201'),
    -- ORD_5003: SPLIT — desk delivered, chair STILL IN TRANSIT
    (4, 3, 1, 1, 20251111, 20251112, 20251115, 1, 'DELIVERED', 'TRK-FF-103'),
    (5, 3, 2, 2, 20251111, 20251112, NULL,     1, 'SHIPPED',   'TRK-RR-202'),
    -- ORD_5004: SPLIT — rug in transit + bookshelf BACKORDERED at West
    (6, 4, 1, 1, 20251113, 20251114, NULL,     1, 'SHIPPED',   'TRK-FF-104'),
    (7, 4, 2, 2, NULL,     NULL,     NULL,     1, 'PLACED',    NULL),          -- no label yet
    -- ORD_5005: single, in transit
    (8, 5, 1, 1, 20251114, 20251115, NULL,     1, 'SHIPPED',   'TRK-FF-105'),
    -- ORD_5006: single, quick West-coast delivery
    (9, 6, 2, 2, 20251116, 20251117, 20251119, 1, 'DELIVERED', 'TRK-RR-203');

-- -----------------------------------------------------------------------------
-- fact_order_lifecycle — one row per order (milestones = first/last across
-- its shipments: MIN(shipped), MAX(delivered), COUNT(*))
-- -----------------------------------------------------------------------------
INSERT INTO fact_order_lifecycle
    (lifecycle_sk, order_sk, customer_sk, placed_date_sk, payment_confirmed_date_sk, picked_date_sk, packed_date_sk, first_shipped_date_sk, all_delivered_date_sk, current_status, shipment_count, is_split_shipment) VALUES
    -- ORD_5001: clean single-shipment order
    (1, 1, 1, 20251103, 20251103, 20251104, 20251104, 20251105, 20251108, 'DELIVERED', 1, false),
    -- ORD_5002: split — lamp (West) shipped FIRST on 11-06, couch delivered LAST on 11-12
    (2, 2, 2, 20251104, 20251104, 20251105, 20251105, 20251106, 20251112, 'DELIVERED', 2, true),
    -- ORD_5003: split — desk back from FastFreight, chair not yet delivered
    (3, 3, 3, 20251110, 20251110, 20251111, 20251111, 20251112, NULL,     'SHIPPED',   2, true),
    -- ORD_5004: split — rug gone out, bookshelf backordered (never picked),
    --            so order-level picked/packed come from the rug's shipments
    (4, 4, 4, 20251112, 20251112, 20251113, 20251113, 20251114, NULL,     'SHIPPED',   2, true),
    -- ORD_5005: single, in transit
    (5, 5, 5, 20251113, 20251113, 20251113, 20251114, 20251115, NULL,     'SHIPPED',   1, false),
    -- ORD_5006: single, delivered
    (6, 6, 1, 20251116, 20251116, 20251116, 20251117, 20251117, 20251119, 'DELIVERED', 1, false);

-- -----------------------------------------------------------------------------
-- fact_shipment_event — raw webhook arrival log (received_at in UTC), with
-- two planted anomalies:
--   * event 4: duplicate SHIPPED retry for shipment 1 (endpoint was down,
--              FastFreight re-sent two days later)
--   * event 8: PICKED for shipment 3 happened on 11-05 but was queued behind
--              a rate limit and ARRIVED on 11-08 — two days AFTER that
--              shipment's SHIPPED event (event 7)
-- Everything else arrived on its own day. This is the table the
-- late-arriving exercises reason about.
-- -----------------------------------------------------------------------------
INSERT INTO fact_shipment_event
    (event_sk, shipment_sk, order_sk, carrier_sk, event_status, event_date_sk, received_at) VALUES
    (1, 1, 1, 1, 'PICKED',    20251104, '2025-11-04 15:05:00'),
    (2, 1, 1, 1, 'PACKED',    20251104, '2025-11-04 21:40:00'),
    (3, 1, 1, 1, 'SHIPPED',   20251105, '2025-11-05 14:12:00'),
    (4, 1, 1, 1, 'SHIPPED',   20251105, '2025-11-07 08:15:00'),  -- DUPLICATE retry
    (5, 1, 1, 1, 'DELIVERED', 20251108, '2025-11-08 19:22:00'),
    (6, 3, 2, 2, 'PACKED',    20251105, '2025-11-05 23:00:00'),
    (7, 3, 2, 2, 'SHIPPED',   20251106, '2025-11-06 16:30:00'),
    (8, 3, 2, 2, 'PICKED',    20251105, '2025-11-08 05:47:00'),  -- LATE: happened
                                                                       -- before SHIPPED,
                                                                       -- arrived after
    (9, 5, 3, 2, 'SHIPPED',   20251112, '2025-11-12 18:00:00'),
    (10, 6, 4, 1, 'SHIPPED',  20251114, '2025-11-14 16:30:00');
