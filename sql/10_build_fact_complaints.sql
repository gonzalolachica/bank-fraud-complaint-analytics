-- This is the heart of the data model. It joins every complaint to its company, date,
-- product, and issue information, and calculates one key flag: whether that complaint
-- counts as fraud/scam-related. That flag combines two things -- whether the issue
-- itself was marked fraud-related, or whether the complaint falls under the "Money
-- transfer, virtual currency, or money service" category. Every analysis query in this
-- project (scripts 11 onward) runs against this table.

DROP TABLE IF EXISTS dbo.fact_complaints;

CREATE TABLE dbo.fact_complaints (
    complaint_id         BIGINT,
    date_key             INT,
    company_key          INT,
    product_key          INT,
    issue_key            INT,
    geography_key        INT,
    is_fraud_complaint   BIT NOT NULL,
    company_response     VARCHAR(300),
    timely_response      VARCHAR(20),
    submitted_via        VARCHAR(100)
);
GO

INSERT INTO dbo.fact_complaints (
    complaint_id, date_key, company_key, product_key, issue_key, geography_key,
    is_fraud_complaint, company_response, timely_response, submitted_via
)

SELECT
    c.complaint_id,
    YEAR(c.date_received)*10000 + MONTH(c.date_received)*100 + DAY(c.date_received) AS date_key,
    co.company_key,
    p.product_key,
    i.issue_key,
    g.geography_key,
    CASE WHEN i.is_fraud_related = 1 OR p.product_group = 'Money Transfer / Virtual Currency'
         THEN 1 ELSE 0 END AS is_fraud_complaint,
    c.company_response_to_consumer,
    c.timely_response,
    c.submitted_via
FROM dbo.stg_complaints_clean c
JOIN dbo.dim_company  co ON c.company = co.company_name
JOIN dbo.dim_product  p  ON c.product = p.product_name
JOIN dbo.dim_issue    i  ON c.issue = i.issue AND ISNULL(c.sub_issue,'') = ISNULL(i.sub_issue,'')
JOIN dbo.dim_geography g ON ISNULL(c.state,'UNK') = g.state_code;
GO

-- Row-count check
SELECT COUNT(*) FROM dbo.fact_complaints;
SELECT COUNT(*) FROM dbo.stg_complaints_clean;
