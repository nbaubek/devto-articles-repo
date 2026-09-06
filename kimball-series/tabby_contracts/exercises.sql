-- =============================================================================
-- Tabby Contracts — Practice Exercises
-- =============================================================================
-- Try each one before peeking at solutions.sql. Hints are inline as comments.
-- This is the last set in the series — Exercises 1 and 2 are design questions
-- with no single right answer, on purpose.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXERCISE 1 — The services company (design; no answer key, on purpose)
-- -----------------------------------------------------------------------------
-- A professional services company bills clients by the hour but pays
-- consultants a fixed salary. Three stakeholders, three needs:
--   * The PM wants project profitability by PROJECT PHASE
--     (discovery / build / delivery).
--   * Finance wants it by INVOICE — what's actually billed and collectible.
--   * Resourcing wants it by CONSULTANT-WEEK — who's overbooked next month.
--
-- (a) Write each stakeholder's actual question as one plain sentence.
-- (b) Design the fact tables: one grain each, stated as "one row per ___."
-- (c) Which dimension conforms all three? Defend it against one alternative.
--
-- Hint: This is the PetCo case in different clothes. If you can't state the
--       question precisely, you can't design the grain for it. dim_project
--       (or dim_engagement) is the natural conformed dimension — but test
--       it: what breaks if you conform on dim_client instead?


-- -----------------------------------------------------------------------------
-- EXERCISE 2 — Back to Meadowlark (design)
-- -----------------------------------------------------------------------------
-- Revisit Part 4's healthcare model. Sales credits an insurance broker when
-- a new employer group signs. Finance recognizes premium revenue ratably
-- over the policy period. Care Management tracks which members of the group
-- have completed onboarding health screenings.
--
-- Sketch the three fact tables and the dimension that conforms them.
--
-- Hint: Structurally identical to PetCo — a group-level commitment, a
--       ratable recognition, a member-level activity tracker. dim_employer_
--       group does the job dim_contract did. Which of the three tables
--       already EXISTS in meadowlark_health's schema (in spirit)?


-- -----------------------------------------------------------------------------
-- EXERCISE 3 — The three numbers, from scratch (write the SQL)
-- -----------------------------------------------------------------------------
-- Without copying queries.sql, write and run the three "what's the number"
-- queries for PETCO_2026_01:
--   (a) bookings                      -> 648000.00
--   (b) recognized revenue to date    -> 18000.00
--   (c) locations active vs total     -> 8 / 12
--
-- Hint: All three join dim_contract on contract_id; each then touches
--       exactly ONE fact table. If your query joins two fact tables
--       together, stop — that's Exercise 6's anti-pattern.


-- -----------------------------------------------------------------------------
-- EXERCISE 4 — One column, two meanings
-- -----------------------------------------------------------------------------
-- In 2-3 sentences: why is SUM(mrr) over January and February ($18,000)
-- correct as "recognized revenue to date," while the identical sum would be
-- nonsense as "the account's MRR"? Name the Part 3 term for a measure like
-- this.
--
-- Hint: A run-rate is a STATE at an instant; recognized revenue is a FLOW
--       accumulated over a period. The column doesn't know which question
--       you're asking — you have to. (Semi-additive.)


-- -----------------------------------------------------------------------------
-- EXERCISE 5 — The executive summary, computed (write the SQL)
-- -----------------------------------------------------------------------------
-- queries.sql Q4 hardcodes '$648,000' as a string. Rewrite it so each value
-- is COMPUTED from its fact table (three scalar subqueries), keeping the
-- metric name and definition columns.
--
-- Hint: (SELECT SUM(booked_value) FROM fact_booking JOIN dim_contract ...)
--       as a scalar subquery per row. The numbers must come out identical:
--       648000 / 18000 / 8 of 12.


-- -----------------------------------------------------------------------------
-- EXERCISE 6 — Spot the design flaw
-- -----------------------------------------------------------------------------
-- A developer adds this to speed up a report:
--
--     ALTER TABLE fact_location_activation
--         ADD COLUMN booking_sk BIGINT REFERENCES fact_booking(booking_sk);
--
-- It works mechanically. Explain in 3-4 sentences why it's wrong, what it
-- couples that shouldn't be coupled, and what the correct link already is.
--
-- Hint: It's a fact-to-fact foreign key. What happens to every
--       fact_location_activation row when bookings needs its own second
--       grain (amendments as separate rows)? dim_contract already links
--       both tables — through a dimension, not through each other.


-- -----------------------------------------------------------------------------
-- EXERCISE 7 — Conformed dimensions in action (write the SQL)
-- -----------------------------------------------------------------------------
-- (a) List every dimension table referenced by MORE than one of the three
--     fact tables. (Read the schema's foreign keys — no query needed.)
-- (b) Build a month-by-month side-by-side of total booked_value vs total
--     recognized mrr across the whole portfolio, January-March 2026.
--     What does March show, and why is that gap exactly the article's point?
--
-- Hint for (b): Two aggregate subqueries (bookings by booked_date_sk month,
--       subscription months by month_sk) joined through dim_date — the
--       conformed dimension doing its job. Expected March: $5,400 booked,
--       $0 recognized.


-- -----------------------------------------------------------------------------
-- EXERCISE 8 — Activation rate and renewal risk (write the SQL + judgment)
-- -----------------------------------------------------------------------------
-- (a) Write a query returning activation rate per contract:
--     active locations / location_count, plus a count of DELAYED locations.
--     Expected: PetCo 66.7% (1 delayed), Groom & Board 100%, Tiny Paws 100%.
-- (b) In a sentence: which account is the renewal risk, and which of the
--     three fact tables says so?
--
-- Hint for (a): Aggregate fact_location_activation per contract_sk and join
--       dim_contract for the denominator. 8.0/12 = 0.667 — don't do integer
--       division.
