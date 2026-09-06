-- =============================================================================
-- Tabby Contracts — Example Queries (referenced in the article)
-- =============================================================================
-- Run AFTER schema.sql + seed.sql. Q1-Q3 are the article's three
-- "what's the number" queries; Q4-Q5 are the governance and portfolio views.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. Sales: bookings for the PetCo deal
-- -----------------------------------------------------------------------------
-- Expected: $648,000.00 — full three-year value, credited at signature.
SELECT SUM(f.booked_value) AS bookings
FROM fact_booking f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01';


-- -----------------------------------------------------------------------------
-- Q2. Finance: recognized revenue to date (Jan + Feb 2026)
-- -----------------------------------------------------------------------------
-- Expected: $18,000.00 = $6,000 (Jan, 4 locations) + $12,000 (Feb, 8).
-- Read carefully: summing mrr across months is ONLY meaningful as
-- "revenue recognized," never as a run-rate (see the article's pause).
SELECT SUM(f.mrr) AS recognized_revenue_to_date
FROM fact_subscription_month f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01'
  AND f.month_sk BETWEEN 20260101 AND 20260228;


-- -----------------------------------------------------------------------------
-- Q3. Customer Success: location activation
-- -----------------------------------------------------------------------------
-- Expected: 8 of 12 (67%). Not a dollar figure — a different measurement
-- of the same deal, and the one that predicts renewal.
SELECT
    COUNT(*) FILTER (WHERE current_status = 'ACTIVE') AS locations_active,
    COUNT(*)                                          AS locations_total
FROM fact_location_activation f
JOIN dim_contract c ON c.contract_sk = f.contract_sk
WHERE c.contract_id = 'PETCO_2026_01';


-- -----------------------------------------------------------------------------
-- Q4. The governance move: three named, defined metrics — never blended
-- -----------------------------------------------------------------------------
-- This isn't a workaround for not having one number; it IS the answer.
-- Note the definitions travel with the values.
SELECT 'Bookings (Sales)' AS metric,
       '$648,000' AS value,
       'Full 3-year contract value, credited at signature' AS definition
UNION ALL
SELECT 'Recognized Revenue to Date (Finance)',
       '$18,000',
       'Ratable revenue for location-months of service actually delivered'
UNION ALL
SELECT 'Location Activation (Customer Success)',
       '8 of 12 (67%)',
       'Locations live and actively using the product as of today';


-- -----------------------------------------------------------------------------
-- Q5. Portfolio view: the same three numbers per contract, side by side
-- -----------------------------------------------------------------------------
-- Every column comes from a different fact table; the only thing they share
-- is dim_contract. Expected: PetCo 648000 / 18000 / 8-of-12;
-- Groom & Board 96000 / 4000 / 4-of-4; Tiny Paws 5400 / (none yet) / 1-of-1.
SELECT
    c.contract_id,
    c.total_contract_value,
    COALESCE(b.booked_value, 0)                    AS booked_value,
    COALESCE(m.recognized_to_date, 0)              AS recognized_to_date,
    COALESCE(a.locations_active, 0)                AS locations_active,
    c.location_count
FROM dim_contract c
LEFT JOIN (SELECT contract_sk, SUM(booked_value) AS booked_value
           FROM fact_booking GROUP BY contract_sk) b ON b.contract_sk = c.contract_sk
LEFT JOIN (SELECT contract_sk, SUM(mrr) AS recognized_to_date
           FROM fact_subscription_month GROUP BY contract_sk) m ON m.contract_sk = c.contract_sk
LEFT JOIN (SELECT contract_sk,
                  COUNT(*) FILTER (WHERE current_status = 'ACTIVE') AS locations_active
           FROM fact_location_activation GROUP BY contract_sk) a ON a.contract_sk = c.contract_sk
ORDER BY c.total_contract_value DESC;
