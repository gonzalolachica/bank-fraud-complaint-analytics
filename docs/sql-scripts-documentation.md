# SQL Scripts — Bank Fraud & Scam Complaint Analytics

Documentation of every SQL script in this project's `sql/` folder, in build order. Each entry covers what the script does, the business question or engineering problem it solves, the SQL technique it demonstrates, and — where relevant — the confirmed result.

This project analyzes fraud- and scam-related complaints in the CFPB Consumer Complaint Database, benchmarking Truist, JPMorgan Chase, and American Express on a Microsoft Fabric Data Warehouse (T-SQL). Full project background, architecture, and the ingestion troubleshooting story are in the main project README.

---

## Part 1 — Staging & Schema Build (scripts 01–10)

These scripts take the raw CFPB data from a Fabric Lakehouse through cleaning, typing, and star-schema modeling. This is the data engineering foundation the Part 2 analysis queries run against.

### `01_load_stg_complaints_raw.sql`
**Purpose:** Reloads `stg_complaints_raw` in the warehouse from the correctly-parsed `complaints_2026_landed` table in the lakehouse.
**Why it exists:** Keeps a clean separation between "data as it arrived" and "data as it's been transformed" — if a later transformation step turns out wrong, this script means you never have to re-pull from the CFPB API to start over.
**Technique:** Straight T-SQL table copy across a lakehouse/warehouse boundary.

### `02_data_quality_checks.sql`
**Purpose:** Read-only diagnostic queries run against `stg_complaints_raw` before any cleaning — checking for the `"nan"`/`"None"` text artifacts, unparseable dates, and duplicate complaint IDs later confirmed and fixed in script 03.
**Why it exists:** Investigate before you fix. Every cleaning decision downstream in this project was driven by an explicit finding in this script, not a guess.
**Technique:** Diagnostic `SELECT`/`COUNT` queries — no writes.

### `03_build_stg_complaints_clean.sql`
**Purpose:** Builds `stg_complaints_clean` — typed columns (`BIGINT` complaint_id, `DATE` for date fields, right-sized `VARCHAR`s) and standardized values (the `"nan"` text artifact and CFPB's own `"None"` convention both normalized to real `NULL`).
**Why it exists:** This is the single "typed and standardized" layer every later script builds from — the star schema in scripts 05–10 never touches raw/untyped data directly.
**Technique:** `CAST`/`CONVERT` type coercion, `CASE`-based value standardization.

### `04_validate_stg_complaints_clean.sql`
**Purpose:** Post-build validation confirming the cleaning in script 03 actually worked: all 176,927 rows converted cleanly to `DATE`, zero duplicate `complaint_id` values, and the `"nan"`/`"None"` counts came back as expected (0 literal `"None"` after pandas' automatic handling, confirmed via diagnostics).
**Why it exists:** Validate every transformation, not just build it. This is the difference between "I think it's clean" and "I confirmed it's clean."
**Technique:** Row-count and null-count validation queries.

### `05_build_dim_company.sql`
**Purpose:** Builds the 3-row `dim_company` dimension (`company_key`, `company_name`, `is_zelle_owner`).
**Why it exists:** Hand-typed rather than derived, since the peer set (Truist, JPMorgan Chase, American Express) and the Zelle-ownership flag are fixed business facts for this project, not something to infer from the data.
**Technique:** Static `INSERT` — star-schema dimension table design.

### `06_build_dim_date.sql`
**Purpose:** Generates a full calendar dimension, 2020-01-01 through 2026-12-31 (`date_key` = `YYYYMMDD` integer), with `year`, `quarter`, `month`, `month_name`, `day`, `day_of_week`, `day_name`, and `is_weekend`.
**Why it exists:** Lets every later query group by year, quarter, or weekday without repeating date-math logic — standard data-warehouse date-dimension pattern.
**Technique:** Generated calendar table, integer surrogate keys.

### `07_build_dim_product.sql`
**Purpose:** Builds `dim_product` from the distinct CFPB product values, bucketed into a smaller set of `product_group` categories (handling CFPB's renamed taxonomy pairs — the same product sometimes has two slightly different labels across years).
**Why it exists:** Raw CFPB product text is too granular and inconsistent to analyze directly; this collapses it into a clean, stable set of categories used in the Second finding (category breakdown).
**Technique:** `CASE`-based categorization/bucketing.

### `08_build_dim_issue.sql`
**Purpose:** Builds `dim_issue` — all 275 distinct (issue, sub_issue) pairs, with an `is_fraud_related` flag.
**Why it exists / key decision:** An initial `LIKE '%fraud%'/'%scam%'/'%unauthorized%'/'%identity theft%'` keyword match was tested first and found to produce false positives — e.g. every sub-issue under "Credit monitoring or identity theft protection services" (billing/marketing complaints about that *subscription service*, not actual identity theft) got caught by the `%identity theft%` match on the category label alone. Replaced with an explicit, manually-reviewed allow-list (11 of 275 pairs flagged true) instead of broad `LIKE` matching. This is the single most important data-quality decision in the whole fraud-filter design, and it's worth explaining in an interview: broad keyword matching looked reasonable at first but silently miscategorized real data.
**Technique:** Explicit allow-list flagging, reviewed manually against all 275 distinct pairs (not sampled).

### `09_build_dim_geography.sql`
**Purpose:** Builds `dim_geography` — distinct states plus an explicit "Unknown" row, with columns `geography_key`, `state_code` (`VARCHAR(50)`), `state_name`, `region` (Census-style region).
**Why it exists / key decision:** `state_code` uses `VARCHAR(50)`, not a tight 2-character assumption, because CFPB's `state` field can contain values longer than a US state code (confirmed: `"UNITED STATES MINOR OUTLYING ISLANDS"`, 36 characters, and it showed up again as real data in the Third finding below).
**Technique:** Dimension table with a deliberately generous column size, chosen from evidence rather than assumption.

### `10_build_fact_complaints.sql`
**Purpose:** Builds `fact_complaints`, joining all four dimensions (company, date, product, issue) plus geography, and computing `is_fraud_complaint` at load time as `dim_issue.is_fraud_related OR product_group = 'Money Transfer / Virtual Currency'`.
**Why it exists:** This is the central fact table every analysis script (11–17) queries against.
**Validated:** Row count matches `stg_complaints_clean` exactly — 176,927 rows, no rows dropped by any of the four dimension joins.
**Technique:** Multi-table `JOIN` into a fact table; a business rule (the fraud/scam definition) computed once at load time rather than repeated in every downstream query.

---

## Part 2 — Analysis Queries (scripts 11–17)

Each of these answers one specific business question against the completed star schema. Full SQL included since these were written and validated together, with confirmed output.

### `11_analysis_fraud_by_company.sql`
**Business question:** What share of each company's total complaints are fraud/scam-related?

```sql
SELECT
    c.company_name,
    c.is_zelle_owner,
    COUNT(*)                                        AS total_complaints,
    SUM(CAST(f.is_fraud_complaint AS INT))          AS fraud_complaints,
    CAST(
        SUM(CAST(f.is_fraud_complaint AS INT)) AS DECIMAL(10,4)
    ) / COUNT(*) * 100                               AS fraud_share_pct
FROM fact_complaints f
JOIN dim_company c
    ON f.company_key = c.company_key
GROUP BY
    c.company_name,
    c.is_zelle_owner
ORDER BY
    fraud_share_pct DESC;
```

**Technique:** Aggregation (`COUNT`, `SUM`) with an explicit `CAST` to work around Fabric's T-SQL rejecting `SUM()` on a `BIT` column, plus a second `CAST` to force decimal (not integer) division.
**Confirmed result:** JPMorgan Chase & Co. 14.8% (16,102 / 108,722), Truist Financial Corporation 9.4% (2,283 / 24,412), American Express Company 4.5% (1,979 / 43,793).
**Why it matters for the portfolio:** This is the project's strongest, most defensible headline metric — it's normalized against each company's own total complaint volume, not a raw count that can be inflated by unrelated factors like product adoption growth. Both Zelle/Early Warning Services co-owners (Chase, Truist) sit well above non-Zelle Amex, supporting the project's core thesis. Truist — the smallest of the three by volume — has the second-highest share, which is a finding in its own right ("smaller bank ≠ lower fraud rate").

### `12_analysis_category_breakdown.sql`
**Business question:** Which product categories do fraud/scam complaints actually get filed under?

```sql
SELECT
    p.product_group,
    COUNT(*) AS fraud_complaints,
    CAST(COUNT(*) AS DECIMAL(10,4))
        / SUM(COUNT(*)) OVER () * 100 AS pct_of_all_fraud
FROM fact_complaints f
JOIN dim_product p
    ON f.product_key = p.product_key
WHERE f.is_fraud_complaint = 1
GROUP BY p.product_group
ORDER BY fraud_complaints DESC;
```

**Technique:** Window function (`SUM(...) OVER ()`) to get a grand total alongside grouped rows without a second query or self-join.
**Confirmed result:** Money Transfer/Virtual Currency 46.5% (9,467), Checking or Savings Account 29.2% (5,955), Credit Card/Prepaid Card 15.0% (3,052), Debt Collection 7.6% (1,541), remaining categories under 2% combined.
**Why it matters for the portfolio:** Validates the project's core filter design — nearly 3 in 10 fraud complaints get filed under "Checking or Savings Account" rather than the direct money-transfer category, which is exactly why the fraud filter (script 08) had to reach into other product categories instead of relying on a single product filter.

### `13_analysis_geographic_distribution.sql`
**Business question:** How are fraud complaints distributed geographically?

```sql
SELECT
    g.state_code,
    g.state_name,
    g.region,
    COUNT(*) AS fraud_complaints,
    CAST(COUNT(*) AS DECIMAL(10,4))
        / SUM(COUNT(*)) OVER () * 100 AS pct_of_all_fraud
FROM fact_complaints f
JOIN dim_geography g
    ON f.geography_key = g.geography_key
WHERE f.is_fraud_complaint = 1
GROUP BY g.state_code, g.state_name, g.region
ORDER BY fraud_complaints DESC;
```

**Technique:** Same window-function pattern as script 12, applied to a different dimension.
**Confirmed result:** California (3,047, 15.0%), New York (2,310, 11.3%), Florida (2,251, 11.1%), Texas (1,957, 9.6%), Illinois (1,181, 5.8%) lead; "Unknown/Not Specified" accounts for 647 (3.2%).
**Data-quality callback:** One row's `state_code` is the literal text `"UNITED STATES MINOR OUTLYING ISLANDS"` rather than a 2-letter code — confirming the `VARCHAR(50)` sizing decision made back in script 09 was correct, not overcautious.

### `14_analysis_fraud_trend_over_time.sql`
**Business question:** How has fraud complaint volume trended year over year, by company?

```sql
SELECT
    d.year,
    c.company_name,
    COUNT(*) AS fraud_complaints
FROM fact_complaints f
JOIN dim_date d
    ON f.date_key = d.date_key
JOIN dim_company c
    ON f.company_key = c.company_key
WHERE f.is_fraud_complaint = 1
GROUP BY
    d.year,
    c.company_name
ORDER BY
    d.year,
    c.company_name;
```

**Technique:** Two-dimension join (date + company) with a two-level `GROUP BY`, producing a proper time series rather than a single snapshot.
**Confirmed result:** All three companies show steady growth 2020→2025 (e.g. Chase: 802 → 3,739). 2026 shows lower raw counts for all three — **this is a partial-year artifact, not a real decline** (see script 15's coverage check: 2026 data only runs through 2026-08-26).
**Design decision:** Kept as raw yearly counts on purpose — no annualization logic added here — so the "as the data literally shows it" view and the corrected view (script 15) both stay auditable side by side.

### `15_analysis_fraud_trend_yoy_pct_change.sql`
**Business question:** What is the actual year-over-year percentage change in fraud complaint volume per company, correcting for 2026 being a partial year?

```sql
WITH yearly_counts AS (
    SELECT
        d.year,
        c.company_name,
        COUNT(*) AS fraud_complaints
    FROM fact_complaints f
    JOIN dim_date d
        ON f.date_key = d.date_key
    JOIN dim_company c
        ON f.company_key = c.company_key
    WHERE f.is_fraud_complaint = 1
    GROUP BY d.year, c.company_name
),
annualized AS (
    SELECT
        year,
        company_name,
        fraud_complaints AS raw_count,
        CASE
            WHEN year = 2026 THEN CAST(fraud_complaints AS DECIMAL(10,2)) / 238 * 365
            ELSE CAST(fraud_complaints AS DECIMAL(10,2))
        END AS adjusted_count
    FROM yearly_counts
)
SELECT
    year,
    company_name,
    raw_count,
    ROUND(adjusted_count, 0) AS annualized_count,
    ROUND(
        (adjusted_count - LAG(adjusted_count) OVER (PARTITION BY company_name ORDER BY year))
        / LAG(adjusted_count) OVER (PARTITION BY company_name ORDER BY year)
        * 100
    , 1) AS yoy_pct_change
FROM annualized
ORDER BY
    company_name,
    year;
```

**Technique:** CTEs (`WITH`) to stage the calculation in readable steps, a `CASE`-based inline annualization adjustment, and `LAG() OVER (PARTITION BY ... ORDER BY ...)` — a window function that looks back one row within each company's own sequence to compute period-over-period percent change.

**How the 2026 correction was reached:** Raw 2026 vs. 2025 comparisons looked like a sharp drop for all three companies. A coverage check (`MIN`/`MAX(full_date)` filtered to 2026 rows) confirmed 2026 data runs 2026-01-01 through 2026-08-26 — 238 of 365 days, about 65% of a full year — so the drop was a partial-year artifact, not a real decline. The `238`/`365` constants in the `CASE` statement are hardcoded to that specific check date; if the pipeline is re-run later in the year with fresh data, this factor needs to be recalculated.

**Confirmed result:** American Express 2026 +0.6% annualized (essentially flat), JPMorgan Chase −6.8% (a real but modest dip), Truist +19.7% (a real increase) — each matching hand-calculated figures exactly. Looking at the full series rather than just 2026, Amex and Truist's percentages swing much more sharply year to year than Chase's (a small-numbers effect: the same absolute change is a bigger percentage on a smaller base).

**Framing note — read this before quoting these numbers anywhere:** these percentages measure growth in *CFPB complaint counts*, not fraud incidence itself. Complaint volume can rise from more people using Zelle/P2P transfers each year, rising public awareness of Zelle scams, or increased regulatory attention — not only from more fraud actually occurring. Present this query's output as **"fraud-related complaint volume % change,"** not **"fraud increased X%."** Script 11's fraud-share metric is the more defensible headline claim for a CV/interview context, since it's normalized against each company's own complaint base; this query is best used as supporting detail, and it's a strong standalone demonstration of `LAG()`/window-function/CTE skill regardless of which headline number you lead with.

### `16_analysis_fraud_seasonality.sql`
**Business question:** Does fraud complaint volume vary by time of year?

```sql
SELECT
    d.month,
    d.month_name,
    COUNT(*) AS fraud_complaints,
    CAST(COUNT(*) AS DECIMAL(10,4))
        / SUM(COUNT(*)) OVER () * 100 AS pct_of_all_fraud
FROM fact_complaints f
JOIN dim_date d
    ON f.date_key = d.date_key
WHERE f.is_fraud_complaint = 1
  AND d.year BETWEEN 2020 AND 2025
GROUP BY d.month, d.month_name
ORDER BY d.month;
```

**Technique:** Same `SUM(...) OVER ()` window-function pattern as scripts 12/13, plus a second `WHERE` condition restricting to complete calendar years only.
**Design decision:** 2026 is deliberately excluded rather than annualized (unlike script 15) — since this query buckets by *month*, an incomplete 2026 would understate September–December specifically (they're missing a year's worth of data the other months still have), which annualizing the year as a whole wouldn't fix. Exclusion is the correct technique for this particular question, even though annualization was the correct technique for script 15's different question.
**Confirmed result:** Fairly flat across the year — January highest (9.7% vs. an 8.33% even baseline), August close behind (9.5%), February the clear low point (6.8%). Neither a tax-season spike (Feb–Apr) nor a strong holiday spike (Nov–Dec) showed up. Total across all twelve months (17,417) cross-validates exactly against the sum of 2020–2025 in the Fourth finding.
**Caveat:** the data can't explain *why* January stands out — resist the urge to assert a specific cause (post-holiday fraud discovery, New Year scam activity, complaint-processing backlogs are all plausible) without further evidence.

### `17_analysis_company_category_crosstab.sql`
**Business question:** For each company individually, which product categories does its fraud actually land in?

```sql
SELECT
    c.company_name,
    p.product_group,
    COUNT(*) AS fraud_complaints,
    CAST(COUNT(*) AS DECIMAL(10,4))
        / SUM(COUNT(*)) OVER (PARTITION BY c.company_name) * 100 AS pct_of_company_fraud
FROM fact_complaints f
JOIN dim_company c
    ON f.company_key = c.company_key
JOIN dim_product p
    ON f.product_key = p.product_key
WHERE f.is_fraud_complaint = 1
GROUP BY
    c.company_name,
    p.product_group
ORDER BY
    c.company_name,
    fraud_complaints DESC;
```

**Technique:** `SUM(COUNT(*)) OVER (PARTITION BY c.company_name)` — the same window-function idea as script 12, but partitioned so the percentage denominator restarts for each company instead of being one grand total shared across all three.
**Confirmed result:** American Express: Credit Card/Prepaid Card 46.4%, Debt Collection 30.9%, Money Transfer 12.9%. JPMorgan Chase: Money Transfer/Virtual Currency 51.4%, Checking/Savings 29.9%, Credit Card 12.6%. Truist: Checking/Savings 43.4%, Money Transfer 40.8%, Debt Collection 8.3%. All three companies' totals cross-validate exactly against the First finding (Amex 1,979, Chase 16,102, Truist 2,283).
**Why it matters for the portfolio:** Arguably the strongest single finding in the project. Amex's fraud centers on its actual core product (credit cards) — unsurprising since it isn't a Zelle bank. Chase's fraud is money-transfer-dominant (over half). Truist — despite the *same* Zelle/EWS exposure as Chase — splits almost evenly between checking/savings and money transfer, rather than mirroring Chase's profile. That's a specific, defensible difference between two banks with identical Zelle ownership status, and a much stronger claim than "both Zelle owners look similar because they're both exposed to Zelle."

---

## Suggested use for a portfolio README or CV

Lead with the First finding (fraud share by company) and the Seventh finding (company × category cross-tab) as your two headline results — the first is the most rigorous number in the project, the second is the most surprising and specific one. Use the category breakdown, geographic distribution, and seasonality as supporting detail that shows the fraud-filter design was non-trivial (script 08's allow-list decision is a good talking point). Use the trend queries (14, 15) to show growth over time, with the framing note above applied — "complaint volume trend," not "fraud trend." The ingestion troubleshooting story (a separate doc) and the data-quality decisions throughout this doc (the `"nan"` artifact, the `VARCHAR(50)` sizing, the fraud-classification allow-list) are strong "how do you actually debug data" talking points for an interview — arguably more valuable to walk through than the final numbers themselves.
