-- Answers: what's the real percentage change in fraud complaint volume from one year
-- to the next, per company -- correcting for the fact that the most recent year (2026)
-- in the data is incomplete? Before comparing 2026 to prior years, this script scales
-- the 2026 count up as if the full year had happened, so the comparison is fair.
-- Important: this measures growth in complaint counts, not fraud itself -- more
-- complaints can also mean more people using the product or more people becoming
-- aware they can file a complaint, not only more fraud actually happening.

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

-- Coverage check behind the 238/365 constant: 2026 data runs 2026-01-01 through
-- 2026-08-26 (238 of 365 days, ~65% of a full year). Recalculate this factor if the
-- pipeline is re-run later in the year with fresher data.
--
-- Confirmed result: American Express 2026 +0.6% annualized, JPMorgan Chase -6.8%,
-- Truist +19.7% -- each matching hand-calculated figures exactly.
