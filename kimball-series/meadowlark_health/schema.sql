-- =============================================================================
-- Meadowlark Health — Dimensional Model (PostgreSQL)
-- =============================================================================
-- Companion schema for "Kimball for Many-to-Many: Bridge Tables, Weighting
-- Factors, and the Diagnosis Code Problem" (Part 4 of the series). Run this
-- first, then seed.sql, then queries.sql.
--
-- Design notes:
--   * A claim line can carry SEVERAL diagnoses at once — a genuine
--     many-to-many. fact_claim_line therefore points at a diagnosis GROUP
--     key, and bridge_diagnosis_group resolves that group to however many
--     dim_diagnosis rows apply, each with a weighting_factor that sums to
--     1.000 per group.
--   * The weighting factor exists because billed_amount fans out through
--     the bridge: SUM(billed_amount * weighting_factor) allocates dollars
--     without inventing them. A plain SUM through the join triple-counts.
--   * bridge_policy_member has NO weighting factor, on purpose: nothing
--     numeric fans out through it. Membership, not allocation.
--   * fact_network_coverage is a FACTLESS FACT (provider in-network for
--     plan as of date) — it resolves a many-to-many on its own, without
--     being a bridge table.
--   * dim_diagnosis is Type 1 here for readability; see Exercise 8 for what
--     changes if coding-standard revisions force it to Type 2.
-- =============================================================================

-- Clean slate (idempotent re-runs during development)
DROP TABLE IF EXISTS fact_network_coverage    CASCADE;
DROP TABLE IF EXISTS fact_claim_line          CASCADE;
DROP TABLE IF EXISTS bridge_policy_member     CASCADE;
DROP TABLE IF EXISTS bridge_diagnosis_group   CASCADE;
DROP TABLE IF EXISTS dim_policy               CASCADE;
DROP TABLE IF EXISTS dim_plan                 CASCADE;
DROP TABLE IF EXISTS dim_diagnosis            CASCADE;
DROP TABLE IF EXISTS dim_provider             CASCADE;
DROP TABLE IF EXISTS dim_member               CASCADE;
DROP TABLE IF EXISTS dim_date                 CASCADE;

-- -----------------------------------------------------------------------------
-- dim_date  (integer YYYYMMDD key; claims live in Q3 2026)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_sk        INT PRIMARY KEY,
    full_date      DATE NOT NULL UNIQUE,
    day_of_week    TEXT NOT NULL,
    day_number     INT NOT NULL,
    month_number   INT NOT NULL,
    month_name     TEXT NOT NULL,
    quarter        INT NOT NULL,
    year           INT NOT NULL,
    is_weekend     BOOLEAN NOT NULL,
    holiday_name   TEXT
);

-- -----------------------------------------------------------------------------
-- dim_member  (patients; Type 1)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_member (
    member_sk      BIGSERIAL PRIMARY KEY,
    member_id      TEXT NOT NULL UNIQUE,      -- 'MEM_001'
    member_name    TEXT NOT NULL,
    birth_date     DATE NOT NULL,
    home_city      TEXT NOT NULL,
    home_state     TEXT NOT NULL
);

-- -----------------------------------------------------------------------------
-- dim_provider  (Type 1)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_provider (
    provider_sk    BIGSERIAL PRIMARY KEY,
    provider_id    TEXT NOT NULL UNIQUE,      -- 'PROV_001'
    provider_name  TEXT NOT NULL,
    specialty      TEXT NOT NULL,             -- 'Family Medicine'
    city           TEXT NOT NULL,
    state          TEXT NOT NULL
);

-- -----------------------------------------------------------------------------
-- dim_diagnosis  (ICD-10 codes; small hand-assigned INT keys, per the
-- article's bridge DDL — Type 1 in this case study)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_diagnosis (
    diagnosis_sk     INT PRIMARY KEY,
    diagnosis_code   TEXT NOT NULL UNIQUE,    -- 'E11.9'
    diagnosis_desc   TEXT NOT NULL,
    diagnosis_category TEXT NOT NULL          -- ENDOCRINE / CARDIOVASCULAR /
                                              -- CONTAGIOUS / MUSCULOSKELETAL
);

-- -----------------------------------------------------------------------------
-- dim_plan  (Meadowlark's product plans — the side of the network-coverage
-- factless fact that isn't a provider)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_plan (
    plan_sk        BIGSERIAL PRIMARY KEY,
    plan_id        TEXT NOT NULL UNIQUE,      -- 'PPO_GOLD'
    plan_name      TEXT NOT NULL,
    network_type   TEXT NOT NULL               -- PPO / HMO
);

-- -----------------------------------------------------------------------------
-- dim_policy  (employer-group contracts; each policy sits on one plan)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_policy (
    policy_sk      BIGSERIAL PRIMARY KEY,
    policy_id      TEXT NOT NULL UNIQUE,      -- 'POL_9001'
    group_name     TEXT NOT NULL,             -- sponsoring employer / individual
    plan_sk        BIGINT NOT NULL REFERENCES dim_plan(plan_sk),
    effective_date DATE NOT NULL
);

-- =============================================================================
-- BRIDGE TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- bridge_diagnosis_group — WEIGHTED bridge (a numeric measure fans out)
-- -----------------------------------------------------------------------------
-- One group can resolve to 1..n diagnoses. weighting_factor = the share of
-- the claim line attributable to that code; MUST sum to 1.000 per group for
-- SUM(billed_amount * weighting_factor) to allocate honestly.
CREATE TABLE bridge_diagnosis_group (
    diagnosis_group_sk  INT NOT NULL,
    diagnosis_sk        INT NOT NULL REFERENCES dim_diagnosis(diagnosis_sk),
    weighting_factor    NUMERIC(4,3) NOT NULL,
    PRIMARY KEY (diagnosis_group_sk, diagnosis_sk)
);
CREATE INDEX idx_bdg_group ON bridge_diagnosis_group (diagnosis_group_sk);

-- -----------------------------------------------------------------------------
-- bridge_policy_member — UNWEIGHTED membership bridge (nothing to allocate)
-- -----------------------------------------------------------------------------
-- One policy covers several members; a member can (on changing jobs) appear
-- under more than one policy over time. No weighting_factor: no fact-table
-- measure ever fans out through this bridge.
CREATE TABLE bridge_policy_member (
    policy_sk      BIGINT NOT NULL REFERENCES dim_policy(policy_sk),
    member_sk      BIGINT NOT NULL REFERENCES dim_member(member_sk),
    relationship   TEXT NOT NULL,             -- SUBSCRIBER / SPOUSE / DEPENDENT
    PRIMARY KEY (policy_sk, member_sk)
);

-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_claim_line — TRANSACTION FACT (one row per billed service line)
-- -----------------------------------------------------------------------------
-- diagnosis_group_sk (NOT a diagnosis_1/2/3_sk column) is the whole design:
-- any number of diagnoses per line, no schema change ever needed.
-- NOTE: no declared FK to bridge_diagnosis_group — it's structurally
-- impossible: the bridge's PK is composite (group, diagnosis), so the group
-- key alone is not unique. A group resolves to MANY rows; that's the point.
-- Referential integrity is enforced by the ETL plus the orphan/weight checks
-- in solutions.sql.
CREATE TABLE fact_claim_line (
    claim_line_sk    BIGSERIAL PRIMARY KEY,
    claim_id         TEXT NOT NULL,           -- 'CLM_2001' (degenerate dim)
    member_sk        BIGINT NOT NULL REFERENCES dim_member(member_sk),
    provider_sk      BIGINT NOT NULL REFERENCES dim_provider(provider_sk),
    service_date_sk  INT NOT NULL REFERENCES dim_date(date_sk),
    diagnosis_group_sk INT NOT NULL,          -- FK unenforceable; see note above
    billed_amount    NUMERIC(10,2) NOT NULL
);
CREATE INDEX idx_fcl_service ON fact_claim_line (service_date_sk);
CREATE INDEX idx_fcl_group   ON fact_claim_line (diagnosis_group_sk);

-- -----------------------------------------------------------------------------
-- fact_network_coverage — FACTLESS FACT (row existence IS the fact)
-- -----------------------------------------------------------------------------
-- "Provider P is in-network for plan A as of date D." Resolves the
-- provider↔plan many-to-many by itself — neither side needs to be the
-- other's dimension.
CREATE TABLE fact_network_coverage (
    coverage_sk       BIGSERIAL PRIMARY KEY,
    provider_sk       BIGINT NOT NULL REFERENCES dim_provider(provider_sk),
    plan_sk           BIGINT NOT NULL REFERENCES dim_plan(plan_sk),
    effective_date_sk INT NOT NULL REFERENCES dim_date(date_sk),
    UNIQUE (provider_sk, plan_sk, effective_date_sk)
);
