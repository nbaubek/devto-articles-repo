-- =============================================================================
-- Meadowlark Health — Practice Exercises
-- =============================================================================
-- Try each one before peeking at solutions.sql. Hints are inline as comments.
-- The companion article explains every concept these questions test.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EXERCISE 1 — Single diagnosis: bridge or direct FK?
-- -----------------------------------------------------------------------------
-- Claim lines 1002, 1005, and 1007 each carry exactly ONE diagnosis. Does a
-- single-diagnosis claim line still need a diagnosis_group_sk pointing at
-- the bridge, or could it point straight at dim_diagnosis?
-- Defend your choice in 2-3 sentences.
--
-- Hint: Consider what happens to every downstream query if some rows use
--       one pattern and others use another. A single diagnosis is just a
--       group of size one — weighting_factor = 1.000. Consistency usually
--       beats the minor special case.


-- -----------------------------------------------------------------------------
-- EXERCISE 2 — Predict the bug, then fix it (write the SQL)
-- -----------------------------------------------------------------------------
-- (a) WITHOUT running it, predict the total of this query across ALL claim
--     lines (not just 1001):
--
--       SELECT SUM(f.billed_amount)
--       FROM fact_claim_line f
--       JOIN bridge_diagnosis_group b
--         ON b.diagnosis_group_sk = f.diagnosis_group_sk;
--
--     The seed's eight lines bill $2,350 in total. What number does the
--     query return, and why?
-- (b) Write the corrected one-row version that returns exactly $2,350.
--
-- Hint for (a): Count bridge rows per group first: groups of one, three,
--       two... the fan-out multiplies each line by its group's row count.
--       Expected: $4,680.


-- -----------------------------------------------------------------------------
-- EXERCISE 3 — The impact report (intentional double-count)
-- -----------------------------------------------------------------------------
-- Write the query for the article's "impact report": total billed amount
-- touched by any claim carrying a CONTAGIOUS-category diagnosis, INTENTIONALLY
-- counting a claim once per contagious code. Label the output column so
-- nobody can mistake it for the allocated total.
--
-- Hint: Join fact to bridge to dim_diagnosis, filter category = 'CONTAGIOUS',
--       sum billed_amount UNWEIGHTED — the same shape as the "wrong" query,
--       except here the fan-out is the point. Expected: $660.


-- -----------------------------------------------------------------------------
-- EXERCISE 4 — Both codes together, without the trap (write the SQL)
-- -----------------------------------------------------------------------------
-- "How much was billed for claims carrying BOTH E11.9 AND I10?"
--
-- (a) Write the query that answers it correctly. Expected: $1,200.
-- (b) The tempting weighted version — SUM(billed_amount * weighting_factor)
--     over just those two codes — returns $1,040. Explain in a sentence why
--     NEITHER $1,200-with-weights NOR $1,040 is "the allocated truth."
--
-- Hint for (a): Find the diagnosis_group_sk values that contain BOTH codes
--       (INTERSECT, or a HAVING COUNT(DISTINCT diagnosis_sk) = 2 group),
--       then sum the fact table's billed_amount once per claim line,
--       unweighted.


-- -----------------------------------------------------------------------------
-- EXERCISE 5 — Weight-integrity check (write the SQL)
-- -----------------------------------------------------------------------------
-- Write a query that finds diagnosis groups whose weighting factors do NOT
-- sum to 1.000. The seed contains exactly one — which group, and what do its
-- weights sum to?
--
-- Hint: GROUP BY diagnosis_group_sk HAVING ABS(SUM(weighting_factor) - 1.0)
--       > 0.001. Why a tolerance instead of = 1.0? NUMERIC arithmetic and
--       exact-decimal representations.


-- -----------------------------------------------------------------------------
-- EXERCISE 6 — Membership bridge vs. weighted bridge
-- -----------------------------------------------------------------------------
-- (a) Write a query listing everyone covered under POL_9002, with
--     relationship, ordered by name.
-- (b) In 2-3 sentences: why does bridge_policy_member have no
--     weighting_factor, and what question WOULD force you to add one?
--
-- Hint for (b): The rule from the article — a weighting factor is needed
--       only when a numeric measure from a fact table fans out through the
--       bridge. What would have to be true about dollar amounts and
--       dependents for weights to start making sense?


-- -----------------------------------------------------------------------------
-- EXERCISE 7 — Factless fact, as-of
-- -----------------------------------------------------------------------------
-- (a) Write a query returning Dr. Sofia Reyes's in-network plans AS OF
--     2026-08-15, and again AS OF 2026-09-15. Why do the two differ?
-- (b) A "provider network breadth" report sums in-network provider counts
--     across all 12 months of 2026. Is that sum meaningful? Why or why not?
--
-- Hint for (b): Is "number in network" a stock or a flow? Compare with
--       Part 3's in-transit count — same semi-additive shape.


-- -----------------------------------------------------------------------------
-- EXERCISE 8 — Bridge on top of Type 2 dimensions
-- -----------------------------------------------------------------------------
-- Suppose ICD coding-standard revisions force dim_diagnosis to become SCD
-- Type 2 (a code's description changes; a new row is issued). What changes
-- about bridge_diagnosis_group, and what happens to historical allocation
-- queries if you do nothing? Answer in 3-4 sentences.
--
-- Hint: Same lesson as Parts 1-2, one join further away: the bridge row
--       must point at the dimension row that was valid when the claim was
--       billed — otherwise yesterday's claims allocate through TODAY'S
--       descriptions. Think about which key (surrogate vs natural) belongs
--       in the bridge.
