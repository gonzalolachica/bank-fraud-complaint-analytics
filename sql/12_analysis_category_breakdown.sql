-- Answers: when a complaint IS fraud-related, which product category does it actually
-- get filed under? This matters because fraud complaints don't all land in the obvious
-- "money transfer" category -- a lot of them get filed under checking/savings accounts
-- or credit cards instead, which is exactly why the fraud definition in script 08
-- couldn't rely on product category alone.

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

-- Confirmed result: Money Transfer/Virtual Currency 46.5% (9,467),
-- Checking or Savings Account 29.2% (5,955), Credit Card/Prepaid Card 15.0% (3,052),
-- Debt Collection 7.6% (1,541), remaining categories under 2% combined.
