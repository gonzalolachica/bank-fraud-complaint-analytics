-- Builds a small reference table with the three companies in this project (Truist,
-- JPMorgan Chase, American Express) and a flag for whether each one co-owns Zelle.
-- This is typed in by hand rather than pulled from the data, since which companies
-- are being compared is a fixed decision for this project, not something to detect.

DROP TABLE IF EXISTS dbo.dim_company;

CREATE TABLE dbo.dim_company (
company_key     INT,
company_name    VARCHAR(300),
is_zelle_owner  BIT
);

INSERT INTO dbo.dim_company (company_key,company_name,is_zelle_owner)
VALUES
    (1, 'TRUIST FINANCIAL CORPORATION', 1),
    (2, 'JPMORGAN CHASE & CO.', 1),
    (3, 'AMERICAN EXPRESS COMPANY', 0);

SELECT * FROM dbo.dim_company;
