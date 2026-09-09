-- Answers: how has fraud complaint volume changed year over year, for each company?
-- Important note: the most recent year (2026) in this data is incomplete -- it only
-- covers part of the year -- so its raw count looks lower than it really would be for
-- a full year. That correction is handled in script 15, not here; this script
-- intentionally shows the numbers exactly as they are in the data.

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

-- Confirmed result: all three companies show steady growth 2020->2025
-- (e.g. Chase: 802 -> 3,739). 2026 shows lower raw counts for all three --
-- this is a partial-year artifact, not a real decline (see script 15).
