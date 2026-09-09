-- Builds a reference table of every distinct complaint issue/sub-issue combination
-- (275 of them) and marks which ones are actually fraud-related. This isn't done with
-- a simple keyword search -- an early attempt using LIKE '%fraud%' and similar keyword
-- matches was found to misclassify real complaints (for example, a billing complaint
-- about an "identity theft protection" subscription service isn't actually about
-- identity theft). Instead, this uses a manually reviewed list of exactly which
-- issue/sub-issue pairs count as fraud-related.

DROP TABLE IF EXISTS dbo.dim_issue;

CREATE TABLE dbo.dim_issue (
    issue_key         INT,
    issue             VARCHAR(500),
    sub_issue         VARCHAR(500),
    is_fraud_related  BIT NOT NULL
    );
    GO

INSERT INTO dbo.dim_issue (issue_key,issue,sub_issue,is_fraud_related)
SELECT
    row_number() OVER (ORDER BY issue,sub_issue) AS  issue_key,
      issue,
    sub_issue,
    0
FROM (
    SELECT DISTINCT issue, sub_issue
    FROM dbo.stg_complaints_clean
) AS distinct_issues;
GO

-- Flag the fraud-related sub_issues
UPDATE dbo.dim_issue
SET is_fraud_related = 1
WHERE sub_issue IN (
    'Transaction was not authorized',
    'Card opened without my consent or knowledge',
    'Debt was result of identity theft',
    'Card opened as result of identity theft or fraud',
    'Account opened without my consent or knowledge',
    'Loan opened without my consent or knowledge'
);
GO

-- Flag the fraud-related issues (no sub_issue)
UPDATE dbo.dim_issue
SET is_fraud_related = 1
WHERE sub_issue IS NULL
  AND issue IN (
    'Fraud or scam',
    'Account opened as a result of fraud',
    'Problem with fraud alerts or security freezes',
    'Unauthorized transactions or other transaction problem',
    'Unauthorized withdrawals or charges'
);
GO

SELECT COUNT(*) FROM dbo.dim_issue;
SELECT is_fraud_related, COUNT(*) FROM dbo.dim_issue GROUP BY is_fraud_related;
SELECT issue, sub_issue FROM dbo.dim_issue WHERE is_fraud_related = 1 ORDER BY issue, sub_issue;

SELECT is_fraud_related, COUNT(*) FROM dbo.dim_issue GROUP BY is_fraud_related
