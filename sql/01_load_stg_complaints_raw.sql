-- This script reloads the raw staging table in the warehouse from the cleaned data
-- sitting in the lakehouse. Think of it as a refresh step: if this table ever needs
-- to be rebuilt, this is what re-copies the correctly-parsed CFPB data across without
-- having to re-pull anything from the CFPB API.

DROP TABLE IF EXISTS dbo.stg_complaints_raw;
CREATE TABLE dbo.stg_complaints_raw (
    date_received                 VARCHAR(8000),
    product                       VARCHAR(8000),
    sub_product                   VARCHAR(8000),
    issue                         VARCHAR(8000),
    sub_issue                     VARCHAR(8000),
    company_public_response       VARCHAR(8000),
    company                       VARCHAR(8000),
    state                         VARCHAR(8000),
    zip_code                      VARCHAR(8000),
    tags                          VARCHAR(8000),
    submitted_via                 VARCHAR(8000),
    date_sent_to_company          VARCHAR(8000),
    company_response_to_consumer  VARCHAR(8000),
    timely_response               VARCHAR(8000),
    complaint_id                  VARCHAR(8000)
);
INSERT INTO dbo.stg_complaints_raw (
    date_received, product, sub_product, issue, sub_issue,
    company_public_response, company, state, zip_code, tags,
    submitted_via, date_sent_to_company, company_response_to_consumer,
    timely_response, complaint_id
)
SELECT
    date_received, product, sub_product, issue, sub_issue,
    company_public_response, company, state, zip_code, tags,
    submitted_via, date_sent_to_company, company_response_to_consumer,
    timely_response, complaint_id
FROM [staging_lakehouse].[dbo].[complaints_2026_landed];

SELECT COUNT(*) FROM dbo.stg_complaints_raw;
