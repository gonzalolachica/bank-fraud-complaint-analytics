-- Answers: out of each company's total complaints, what percentage were fraud-related?
-- This is the project's core comparison number -- it shows Chase, Truist, and Amex
-- side by side on how much of their complaint load is fraud, not just raw counts.

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

-- Confirmed result: JPMorgan Chase & Co. 14.8% (16,102 / 108,722),
-- Truist Financial Corporation 9.4% (2,283 / 24,412),
-- American Express Company 4.5% (1,979 / 43,793).
