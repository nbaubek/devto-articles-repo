-- =============================================================================
-- Tabby Contracts — Exercise Solutions
-- =============================================================================
-- Referenced by exercises.sql. Try the exercises first!
-- Solutions 1 and 2 are DESIGN questions: what's below is one defensible
-- answer, defended — not the only answer. That's the lesson of Part 5.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SOLUTION 1 — The services company (one defensible answer)
-- -----------------------------------------------------------------------------
-- (a) The questions, stated precisely:
--     PM:          "How many hours and dollars did each PHASE of this
--                   project consume against its budget?"
--     Finance:     "What did we bill on each INVOICE, and what's still
--                   collectible?"
--     Resourcing:  "How many hours is each CONSULTANT committed to, each
--                   week, going forward?"
--
-- (b) Three fact tables, three grains:
--     fact_phase_progress — ACCUMULATING SNAPSHOT, one row per project
--       phase: budget_hours, actual_hours, budget_cost, actual_cost,
--       milestone dates (phase start / client signoff). Phase profitability
--       is derived in place as the phase matures — Part 3's pattern.
--     fact_invoice_line — TRANSACTION, one row per invoice line item:
--       hours, rate, amount, plus payment-milestone dates if you want
--       collectibility. Finance's collectible truth.
--     fact_consultant_week — PERIODIC SNAPSHOT, one row per consultant per
--       week: assigned_hours, billable_hours, capacity_hours. Utilization
--       and overbooking live here, per week, re-photographed every week.
--
-- (c) dim_project conforms all three: every invoice line, phase, and staffed
--     week belongs to exactly one project, so all three facts carry
--       project_sk and can be sliced by the same project attributes.
--     Tested alternative — dim_client: too coarse. Two projects for one
--       client would blur phase margins together, and resourcing questions
--       are per-engagement, not per-client. dim_client still exists — as an
--       attribute (or snowflaked parent) INSIDE dim_project, where it
--       enriches slicing without defining the grain. (Same shape as Part 2's
--       account hierarchies: the parent is context, not the fact's grain.)
--
-- The PetCo mapping: phase≈activation (progress), invoice≈subscription-month
-- (money truth), consultant-week≈location (operational health), dim_project
-- ≈ dim_contract.


-- -----------------------------------------------------------------------------
-- SOLUTION 2 — Back to Meadowlark (sketch)
-- -----------------------------------------------------------------------------
--   * fact_group_booking — TRANSACTION, one row per employer-group signing:
--     broker_sk, group_sk, signed_date, commissionable_premium. (Sales.)
--   * fact_premium_month — PERIODIC SNAPSHOT, one row per policy per month:
--     earned premium for coverage-months delivered. Ratable, month-end
--     photos. (Finance.)
--   * fact_screening_completion — TRANSACTION (or factless, if you only
--     need "did it happen" without measures), one row per member screening:
--     member_sk, screening_type, completed_date. (Care Management.)
-- Conformed by dim_employer_group (a.k.a. the policyholder group —
-- meadowlark's dim_policy already plays this role, and bridge_policy_member
-- already resolves group→member for the third fact's population). The
-- dollars-vs-members distinction is Part 4's lesson layered on Part 5's:
-- the booking and premium facts carry money at group grain; the screening
-- fact carries activity at member grain; nobody sums one into the other.


-- -----------------------------------------------------------------------------
-- SOLUTION 3 — The three numbers, from scratch
-- -----------------------------------------------------------------------------
-- (a) Sales — full value at signature:
SELECT SUM(f.booked_value) AS bookings
FROM fact_booking f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01';
-- Expected: 648000.00

-- (b) Finance — earned location-months only:
SELECT SUM(f.mrr) AS recognized_revenue_to_date
FROM fact_subscription_month f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01'
  AND f.month_sk BETWEEN 20260101 AND 20260228;
-- Expected: 18000.00

-- (c) Customer Success — live locations over total:
SELECT
    COUNT(*) FILTER (WHERE current_status = 'ACTIVE') AS locations_active,
    COUNT(*)                                          AS locations_total
FROM fact_location_activation f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01';
-- Expected: 8 / 12


-- -----------------------------------------------------------------------------
-- SOLUTION 4 — One column, two meanings
-- -----------------------------------------------------------------------------
-- Because the two sums answer different QUESTIONS about the same column.
-- "Revenue recognized to date" is a FLOW — money earned across a period —
-- so accumulating January's $6,000 and February's $12,000 is exactly what
-- the question asks for. "The account's MRR" is a STATE — a run-rate at an
-- instant — and adding two run-rates together produces a number with no
-- interpretation. The column is semi-additive (Part 3's term): additive
-- under one reading, meaningless under another. Nothing in the SQL flags
-- the wrong reading — knowing the question is the analyst's job, which is
-- why the article treats "check what the sum MEANS" as a rule.


-- -----------------------------------------------------------------------------
-- SOLUTION 5 — The executive summary, computed
-- -----------------------------------------------------------------------------
SELECT 'Bookings (Sales)' AS metric,
       (SELECT SUM(booked_value)
        FROM fact_booking f
        JOIN dim_contract c ON c.contract_sk = f.contract_sk
        WHERE c.contract_id = 'PETCO_2026_01')::text AS value,
       'Full 3-year contract value, credited at signature' AS definition
UNION ALL
SELECT 'Recognized Revenue to Date (Finance)',
       (SELECT SUM(f.mrr)
        FROM fact_subscription_month f
        JOIN dim_contract c ON c.contract_sk = f.contract_sk
        WHERE c.contract_id = 'PETCO_2026_01'
          AND f.month_sk BETWEEN 20260101 AND 20260228)::text,
       'Ratable revenue for location-months of service actually delivered'
UNION ALL
SELECT 'Location Activation (Customer Success)',
       (SELECT COUNT(*) FILTER (WHERE current_status = 'ACTIVE')
               || ' of ' || COUNT(*)
        FROM fact_location_activation f
        JOIN dim_contract c ON c.contract_sk = f.contract_sk
        WHERE c.contract_id = 'PETCO_2026_01'),
       'Locations live and actively using the product as of today';
-- Same three values as the hardcoded version — 648000 / 18000 / 8 of 12 —
-- but now the dashboard can't drift from the facts. Hardcoded numbers in
-- governance views rot; computed ones can't.


-- -----------------------------------------------------------------------------
-- SOLUTION 6 — Spot the design flaw
-- -----------------------------------------------------------------------------
-- It's a fact-to-fact foreign key — the article's mistake #3. Problems:
--   1. Grain coupling: fact_booking is one row per SIGNING EVENT. The day
--      bookings adds amendments as their own rows (the DDL already
--      anticipates it — booking_type includes AMENDMENT/UPSELL), a location
--      activation row can no longer point at "the" booking: which one?
--      Every fact_location_activation row's FK must be found and re-pointed.
--   2. Semantic drift: activation rows would silently inherit whatever the
--      booking grain becomes, and queries joining through booking_sk would
--      fan activations out across amendment rows — inventing location
--      counts the way Part 4's unweighted join invented dollars.
--   3. It solves a non-problem: the correct link already exists — both
--      tables reference contract_sk. dim_contract is the conformed
--      dimension; route through it, always. If a report needs
--      activation-and-booking data, aggregate each fact by contract_sk and
--      join the two results — the same shape as Q5 in queries.sql.


-- -----------------------------------------------------------------------------
-- SOLUTION 7 — Conformed dimensions in action
-- -----------------------------------------------------------------------------
-- (a) Referenced by more than one fact:
--       dim_date     — fact_booking, fact_subscription_month,
--                      fact_location_activation (three roles: booked date,
--                      month start, scheduled/actual activation)
--       dim_contract — all three facts (the article's hub)
--       dim_account  — fact_booking, fact_subscription_month
--     Single-use (still fine, just not conformed ACROSS these facts):
--       dim_location (activation only), dim_employee (dim_contract only).
--
-- (b) Month-by-month, whole portfolio, through the shared dim_date:
WITH months AS (
    SELECT date_sk FROM dim_date
),
bookings AS (
    SELECT booked_date_sk AS month_sk, SUM(booked_value) AS booked
    FROM fact_booking GROUP BY booked_date_sk
),
recognized AS (
    SELECT month_sk, SUM(mrr) AS recognized
    FROM fact_subscription_month GROUP BY month_sk
)
SELECT
    dt.date_sk                                   AS month,
    COALESCE(b.booked, 0)                        AS booked_value,
    COALESCE(r.recognized, 0)                    AS recognized_revenue
FROM months dt
LEFT JOIN bookings   b ON b.month_sk = dt.date_sk
LEFT JOIN recognized r ON r.month_sk = dt.date_sk
ORDER BY dt.date_sk;
-- Expected:
--   20260101:   648,000 booked /   6,000 recognized
--   20260201:    96,000 booked /  16,000 recognized  (12k PetCo + 4k G&B)
--   20260301:     5,400 booked /       0 recognized
-- March is the article's whole argument in one row: Tiny Paws booked
-- $5,400 on the 1st and Finance's view shows nothing — not a bug, but the
-- structural difference between "money promised" and "money earned." Sales
-- comp runs off column 1; the income statement runs off column 2.


-- -----------------------------------------------------------------------------
-- SOLUTION 8 — Activation rate and renewal risk
-- -----------------------------------------------------------------------------
-- (a)
SELECT
    c.contract_id,
    COUNT(*) FILTER (WHERE a.current_status = 'ACTIVE') AS locations_active,
    c.location_count,
    ROUND(COUNT(*) FILTER (WHERE a.current_status = 'ACTIVE')::numeric
          / c.location_count, 3)                        AS activation_rate,
    COUNT(*) FILTER (WHERE a.current_status = 'DELAYED') AS locations_delayed
FROM dim_contract c
JOIN fact_location_activation a ON a.contract_sk = c.contract_sk
GROUP BY c.contract_id, c.location_count
ORDER BY activation_rate;
-- Expected: PETCO_2026_01  8/12 = 0.667 with 1 delayed;
--           GROOM_2026_02  4/4  = 1.000;  TINY_2026_03 1/1 = 1.000.
-- The ::numeric cast matters — 8/12 in integer arithmetic is 0.

-- (b) PetCo Org is the renewal risk, and fact_location_activation is the
--     table that says so: a third of the locations aren't live, wave 3 has
--     already slipped (Brooklyn is DELAYED), and activation health — not
--     bookings ($648k, rosy) and not recognized revenue ($18k, early) — is
--     what predicts whether the contract renews in three years. Exactly the
--     Customer Success column of the article's stakeholder table.
