-- Answers: does fraud complaint volume vary depending on the time of year? This looks
-- at fraud complaints by calendar month, combined across every complete year on file
-- (2020-2025). The most recent year, 2026, is left out of this one on purpose --
-- it's not finished yet, and including a partial year would make the last few months
-- look artificially low compared to the others.

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

-- Confirmed result: fairly flat across the year -- January highest (9.7%),
-- August close behind (9.5%), February the clear low point (6.8%).
