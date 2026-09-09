-- Answers: for each company individually, which product categories does ITS fraud
-- actually show up in? This is the same idea as script 12's category breakdown, but
-- broken out separately for each company instead of combining all three together --
-- so you can see whether Chase, Truist, and Amex actually have different fraud
-- patterns, rather than assuming they look the same just because two of them are
-- both exposed to Zelle.

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

-- Confirmed result: American Express: Credit Card/Prepaid Card 46.4%, Debt Collection
-- 30.9%, Money Transfer 12.9%. JPMorgan Chase: Money Transfer/Virtual Currency 51.4%,
-- Checking/Savings 29.9%, Credit Card 12.6%. Truist: Checking/Savings 43.4%,
-- Money Transfer 40.8%, Debt Collection 8.3%.
