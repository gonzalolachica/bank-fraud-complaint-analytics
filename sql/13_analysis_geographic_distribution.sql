-- Answers: which US states have the most fraud complaints? Breaks down fraud
-- complaint counts and percentages by state and region.

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

-- Confirmed result: California (3,047, 15.0%), New York (2,310, 11.3%),
-- Florida (2,251, 11.1%), Texas (1,957, 9.6%), Illinois (1,181, 5.8%) lead;
-- "Unknown/Not Specified" accounts for 647 (3.2%).
