# Kimball Dimensional Modeling — Articles, SQL, and a Quiz

A small content project for data and analytics engineers who want to *actually*
understand dimensional modeling. Three interlocking pieces:

1. **A five-part article series** (Dev.to-ready markdown) — a coffee shop
   (the friendly conceptual tour), a SaaS startup (subscription/MRR/churn),
   order fulfillment (split shipments and late-arriving facts), healthcare
   claims (bridge tables and weighting factors), and the no-right-grain
   case that ties the series together (conformed dimensions).
2. **Companion SQL** for all five case studies — PostgreSQL schemas, hand-crafted
   seed data, the queries used in the articles, plus exercises and solutions.
3. **A polished quiz app** (React + Vite + Tailwind) with 60 questions covering
   all five parts, per-topic scoring, and a "review missed questions" loop.

Everything is greenfield and self-contained. No external services, no API keys,
no auth. Clone and go.

---

## Read the articles

| # | Article | Words | Audience |
|---|---------|-------|----------|
| 1 | [`articles/part-1-coffee-shop.md`](articles/part-1-coffee-shop.md) | ~3,500 | Anyone new to dimensional modeling |
| 2 | [`articles/02-saas-startup-kimball.md`](articles/02-saas-startup-kimball.md) | ~3,250 | People who know the basics, want the SaaS-specific patterns |
| 3 | [`articles/part-3-fulfillment.md`](articles/part-3-fulfillment.md) | ~3,300 | Anyone whose "process" facts fork, stall, or arrive out of order |
| 4 | [`articles/part-4-bridge-tables.md`](articles/part-4-bridge-tables.md) | ~3,200 | Anyone with a genuinely many-to-many dimension |
| 5 | [`articles/part-5-ambiguous-grain.md`](articles/part-5-ambiguous-grain.md) | ~3,100 | Anyone who's been asked for "one number" that doesn't exist |

Article 1 carries the core conceptual load: fact/dimension tables (all their
types), choosing the grain, star vs. snowflake, and SCD basics. Article 2 opens
with a 60-second recap so it's readable standalone, then dives into subscription
grain, account hierarchies, accumulating snapshots for trial→paid→churn,
periodic snapshots for MRR, SCD2 for plan changes, and factless fact tables for
entitlements. Articles 3-5 follow the same recap pattern: accumulating
snapshots under stress (split shipments, out-of-order webhooks, semi-additive
measures), weighted and unweighted bridge tables, and finally three
stakeholders with three irreconcilable grains resolved through conformed
dimensions. They're designed to be non-redundant.

The markdown files include Dev.to frontmatter (`published: false` — flip to
`true` when you're ready to publish). Cover images use Unsplash source URLs.

---

## Run the SQL

The SQL is **PostgreSQL** (tested on Postgres 17). It's portable to Snowflake,
BigQuery, and DuckDB with minor tweaks — the main substitutions:

- `BIGSERIAL` → `BIGINT AUTOINCREMENT` (Snowflake) / `INT64` + `GENERATED` (BigQuery)
- `NUMERIC(p,s)` → `DECIMAL` / `NUMERIC` (same on all three)
- `DATE '9999-12-31'` in SCD2 `COALESCE` patterns works everywhere

### Setup

```bash
# 1. Create a fresh database (one per case study)
createdb kimball_coffee
createdb kimball_saas
createdb kimball_crate
createdb kimball_meadowlark
createdb kimball_tabby

# 2. Coffee shop case study (Part 1)
psql -d kimball_coffee -f coffee_shop/schema.sql
psql -d kimball_coffee -f coffee_shop/seed.sql
psql -d kimball_coffee -f coffee_shop/queries.sql     # the article's example queries

# 3. SaaS startup case study (Part 2)
psql -d kimball_saas -f saas_startup/schema.sql
psql -d kimball_saas -f saas_startup/seed.sql
psql -d kimball_saas -f saas_startup/queries.sql

# 4. Order fulfillment case study (Part 3)
psql -d kimball_crate -f crate_expectations/schema.sql
psql -d kimball_crate -f crate_expectations/seed.sql
psql -d kimball_crate -f crate_expectations/queries.sql

# 5. Healthcare claims case study (Part 4)
psql -d kimball_meadowlark -f meadowlark_health/schema.sql
psql -d kimball_meadowlark -f meadowlark_health/seed.sql
psql -d kimball_meadowlark -f meadowlark_health/queries.sql

# 6. Contract grains case study (Part 5)
psql -d kimball_tabby -f tabby_contracts/schema.sql
psql -d kimball_tabby -f tabby_contracts/seed.sql
psql -d kimball_tabby -f tabby_contracts/queries.sql
```

### File layout per case study

Each case study has the same five-file shape:

| File | What it is |
|------|------------|
| `schema.sql` | `CREATE TABLE`s for every dimension and fact table |
| `seed.sql`   | Small, readable sample data so every query has a story |
| `queries.sql`| The example queries from the article |
| `exercises.sql` | Practice questions (hints inline as comments) |
| `solutions.sql` | Worked solutions for every exercise |

> **Note on `solutions.sql`:** a few solutions (the SCD2 updates and the
> accumulating-snapshot milestone updates) modify database state via `UPDATE`,
> and `crate_expectations/solutions.sql` creates and populates the
> `fact_fulfillment_daily` snapshot. Run them on a throwaway copy of the
> database if you want to keep the seed state pristine for re-running
> `queries.sql`. Also note: `fact_claim_line.diagnosis_group_sk` carries no
> declared foreign key — a bridge table's composite primary key makes one
> structurally impossible; `meadowlark_health/solutions.sql` includes the
> orphan-check query that does that job instead.

### DuckDB alternative

If you'd rather not run a Postgres server, DuckDB works for ~95% of the SQL.
The only thing that needs adjusting is `BIGSERIAL` (DuckDB uses `INTEGER
GENERATED ALWAYS AS IDENTITY` or a `SEQUENCE`). The SCD2 patterns, role-playing
date joins, periodic snapshots, and all the queries run unmodified.

```bash
duckdb kimball.db
.read coffee_shop/schema.sql
.read coffee_shop/seed.sql
.read coffee_shop/queries.sql
```

---

## Run the quiz app

The quiz lives in [`quiz_app/`](quiz_app/). React 18 + Vite 5 + Tailwind 3.

```bash
cd quiz_app
npm install
npm run dev        # opens http://localhost:5173
```

Production build:

```bash
npm run build      # outputs to quiz_app/dist/
npm run preview    # serve the production build locally
```

The `dist/` folder is static — deploy it free to Vercel, Netlify, GitHub Pages,
or any static host.

### What's in the quiz

- **Six modes**: Coffee Shop (15 Q), SaaS Startup (15 Q), Fulfillment (10 Q),
  Bridge Tables (10 Q), Grain & Conformed Dims (10 Q), Mixed (60 Q, shuffled)
- **One question at a time** with smooth animated transitions
- **Instant explanations** after answering — the actual learning moment
- **Progress bar** and a live score badge
- **Results screen** with total score, a per-topic bar chart, and a "review
  missed questions" loop that re-queues only the questions you got wrong
- **Question types**: multiple choice, true/false, and "what's wrong with this
  schema?" (renders a SQL code block and asks you to spot the bug)

The question bank is in [`quiz_app/src/data/questions.json`](quiz_app/src/data/questions.json),
tagged by `article` (`coffee` | `saas` | `fulfillment` | `bridges` | `grain`)
and `topic`. Adding questions is a
one-file edit. See [`quiz_app/README.md`](quiz_app/README.md) for the full
question schema and how to extend it.

---

## Repository layout

```
kimball-concepts/
├── README.md                          ← you are here
├── articles/
│   ├── part-1-coffee-shop.md          ← article 1 (Dev.to-ready)
│   ├── 02-saas-startup-kimball.md     ← article 2 (Dev.to-ready)
│   ├── part-3-fulfillment.md          ← article 3
│   ├── part-4-bridge-tables.md        ← article 4
│   ├── part-5-ambiguous-grain.md      ← article 5
│   └── diagram-*.mmd / diagram-*.png  ← article diagrams (source + rendered)
├── coffee_shop/                       ← Part 1 case study
│   ├── schema.sql                     ← fact + dim DDL
│   ├── seed.sql                       ← sample data
│   ├── queries.sql                    ← article's example queries
│   ├── exercises.sql                  ← practice questions + hints
│   └── solutions.sql                  ← worked solutions
├── saas_startup/                      ← Part 2 case study (same five files)
├── crate_expectations/                ← Part 3 case study (same five files)
├── meadowlark_health/                 ← Part 4 case study (same five files)
├── tabby_contracts/                   ← Part 5 case study (same five files)
└── quiz_app/
    ├── README.md                      ← how to run/dev/deploy the quiz
    ├── index.html                     ← Vite entry
    ├── package.json                   ← React + Vite + Tailwind deps
    ├── vite.config.js
    ├── tailwind.config.js
    ├── postcss.config.js
    ├── public/coffee.svg              ← favicon
    └── src/
        ├── main.jsx
        ├── App.jsx                    ← top-level quiz state machine
        ├── index.css                  ← Tailwind directives + base styles
        ├── components/
        │   ├── StartScreen.jsx        ← mode picker (coffee / saas / mixed)
        │   ├── QuestionCard.jsx       ← one question, animated
        │   ├── ProgressBar.jsx
        │   ├── ScoreBadge.jsx
        │   ├── ExplanationPanel.jsx   ← the learning moment
        │   └── ResultsScreen.jsx      ← score + per-topic chart + review loop
        ├── data/
        │   └── questions.json         ← question bank (30 Q, tagged)
        └── lib/
            └── useQuiz.js             ← custom hook: state, scoring, navigation
```

---

## Verification status

Everything in this repo has been validated end-to-end:

- **Articles** — markdown renders cleanly; frontmatter is valid Dev.to format;
  all code blocks are language-tagged.
- **SQL** — `schema.sql` + `seed.sql` + `queries.sql` for all five case studies
  run cleanly in Postgres 17 with `ON_ERROR_STOP=1`. Foreign keys, SCD2 patterns,
  role-playing date joins, MRR waterfalls, NRR queries, rank-guarded
  late-arriving-fact updates, weighted-bridge allocations, and the
  three-grain conformed-dimension queries all return sensible results.
  Exercise solutions in `solutions.sql` also execute cleanly, and every
  "expected from seed" number in the comments was verified against the
  actual query output.
- **Quiz app** — `npm install`, `npm run build`, and `npm run dev` (HTTP 200
  on `localhost:5173`) all pass. All 60 questions render across the six
  modes; scoring and the per-topic chart work.

---

## Tech choices and why

- **PostgreSQL** for the SQL — broadest familiarity, and the window functions,
  SCD2 patterns, and `PERCENTILE_CONT` queries are portable to Snowflake,
  BigQuery, and DuckDB with cosmetic tweaks.
- **React + Vite + Tailwind** for the quiz — fast dev loop, tiny prod build,
  Tailwind keeps styling in JSX where it belongs. **framer-motion** for the
  question transitions and result-screen micro-animations; **recharts** for the
  per-topic bar chart.
- **Inter** (sans) + **JetBrains Mono** (code) — clean, modern, free via Google
  Fonts.

## License

MIT — see headers in each file. The articles are yours to adapt; the SQL and
quiz are yours to fork.
