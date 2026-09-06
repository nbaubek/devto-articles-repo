-- =============================================================================
-- Crate Expectations — Practice Exercises
-- =============================================================================
-- Try each one before peeking at solutions.sql. Hints are inline as comments.
-- The companion article explains every concept these questions test.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXERCISE 1 — The grain fight: order, shipment, or package?
-- -----------------------------------------------------------------------------
-- Crate Expectations wants to add PACKAGE-level tracking (a shipment can be
-- two boxes). Argue in 2-3 sentences whether the warehouse should add a
-- fact_package table to the ANALYTICAL layer, citing what the article said
-- about the package grain.
--
-- Hint: Who asks package-level questions — the operational system or the
--       business analysts? The test isn't "can we model it," it's "does
--       anyone's real question need it in the warehouse."


-- -----------------------------------------------------------------------------
-- EXERCISE 2 — DELIVERED with no SHIPPED on file (write the logic)
-- -----------------------------------------------------------------------------
-- A DELIVERED webhook arrives for a shipment that has no prior SHIPPED event
-- on file — the shipped notification was lost entirely, not just delayed.
-- What should the update logic do, and why is this a DIFFERENT case from
-- ordinary out-of-order arrival?
--
-- Hint: The rank-based status update still works (DELIVERED outranks
--       everything). But shipped_date_sk would stay NULL forever unless you
--       do something. Backfill-and-flag vs leave-the-gap is a real tradeoff
--       between a clean-looking dataset and an honest one.


-- -----------------------------------------------------------------------------
-- EXERCISE 3 — Write the rank-guarded, idempotent UPDATE
-- -----------------------------------------------------------------------------
-- Event 8 in fact_shipment_event is the late PICKED for ORD_5002 (order_sk=2):
-- it happened on 2025-11-05 but arrived on 2025-11-07, after SHIPPED.
--
-- (a) Write the UPDATE against fact_order_lifecycle that applies it — fill
--     the milestone, guard the status by rank, and survive a duplicate.
-- (b) ORD_5002's row is currently DELIVERED. What would naive "latest
--     webhook wins" logic have done to the visible status on 11-07?
--
-- Hint for (a): Model it on the article's template: COALESCE for the
--       milestone (first value in wins, retries can't overwrite), and
--       compare fulfillment_status_rank ranks before touching current_status.
--       You can hardcode the event's values.


-- -----------------------------------------------------------------------------
-- EXERCISE 4 — Orders in transit, as-of (write the SQL)
-- -----------------------------------------------------------------------------
-- Using only fact_order_lifecycle, write a query that returns how many orders
-- were in transit (shipped but not yet fully delivered) as of the END of
-- 2025-11-15. Your result should be exactly 3.
--
-- Hint: first_shipped_date_sk <= :as_of AND (all_delivered_date_sk IS NULL
--       OR all_delivered_date_sk > :as_of). Same "as-of" shape as the SCD2
--       lookups in Parts 1-2, applied to a milestone range.


-- -----------------------------------------------------------------------------
-- EXERCISE 5 — Build the periodic snapshot
-- -----------------------------------------------------------------------------
-- (a) Write the CREATE TABLE for fact_fulfillment_daily — one row per
--     (snapshot date, warehouse, status) with an order count.
-- (b) Write the query that populates the 2025-11-15 rows from
--     fact_order_lifecycle + fact_shipment.
--
-- Hint for (b): An order is "in transit" at a warehouse when it has a
--       shipment from that warehouse with shipped_date_sk <= :as_of and
--       (delivered_date_sk IS NULL OR delivered_date_sk > :as_of). Expected:
--       East 2 (ORD_5004, ORD_5005), West 1 (ORD_5003).


-- -----------------------------------------------------------------------------
-- EXERCISE 6 — Semi-additive trap
-- -----------------------------------------------------------------------------
-- A dashboard engineer sums your fact_fulfillment_daily order_count across
-- all 20 days of November and titles the chart "Total orders shipped this
-- month." Explain in 2-3 sentences the two things wrong with that, and name
-- a measure from Parts 1-4 of the series that IS fully additive across time.
--
-- Hint: In-transit count is a STATE, not a FLOW — mostly the same orders
--       counted on every day. And even under its correct reading, the sum
--       answers nothing. Contrast with daily_revenue (Part 1) or
--       billed_amount (Part 4).


-- -----------------------------------------------------------------------------
-- EXERCISE 7 — shipment_count: store or compute?
-- -----------------------------------------------------------------------------
-- shipment_count sits denormalized on fact_order_lifecycle even though it
-- equals COUNT(*) FROM fact_shipment WHERE order_sk = .... Why is it stored?
-- What's the risk, and what keeps the two from drifting apart?
--
-- Hint: Same performance-vs-recompute tradeoff that motivates periodic
--       snapshots. The risk is drift; the guard is that the SAME process
--       that applies shipment events updates both tables.


-- -----------------------------------------------------------------------------
-- EXERCISE 8 — Spot the anti-pattern
-- -----------------------------------------------------------------------------
-- A junior engineer, tired of joining fact_shipment, proposes adding these
-- columns to fact_order_lifecycle:
--
--     shipment_2_carrier_sk     INT,
--     shipment_2_shipped_date_sk INT,
--     shipment_3_carrier_sk     INT,
--     shipment_3_shipped_date_sk INT
--
-- Explain in 2-3 sentences why this is wrong, and name what already exists
-- in the schema that answers "carrier per shipment" correctly.
--
-- Hint: Fixed-width guesses at variable-length lists — the same mistake as
--       diagnosis_1/2/3 in Part 4. It breaks the day an order has four
--       shipments. The shipment grain already has a home.
