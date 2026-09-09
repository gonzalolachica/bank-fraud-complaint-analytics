-- This is the actual cleanup step. It takes the raw staging data and produces a
-- proper, typed version of it: real DATE columns instead of text, right-sized
-- VARCHAR columns, and the "nan"/"None" text artifacts converted to real NULLs.
-- Every later script in this project builds off of this clean table, not the raw one.

DROP TABLE IF EXISTS dbo.stg_complaints_clean;

CREATE TABLE dbo.stg_complaints_clean (
    complaint_id                  BIGINT,
    date_received                 DATE,
    date_sent_to_company          DATE,
    product                       VARCHAR(500),
    sub_product                   VARCHAR(500),
    issue                         VARCHAR(500),
    sub_issue                     VARCHAR(500),
    company                       VARCHAR(300),
    company_public_response       VARCHAR(4000),
    company_response_to_consumer  VARCHAR(300),
    state                         VARCHAR(50),
    zip_code                      VARCHAR(20),
    tags                          VARCHAR(200),
    submitted_via                 VARCHAR(100),
    timely_response                VARCHAR(20)
);

INSERT INTO dbo.stg_complaints_clean (
    complaint_id, date_received, date_sent_to_company, product, sub_product,
    issue, sub_issue, company, company_public_response, company_response_to_consumer,
    state, zip_code, tags, submitted_via, timely_response
)
SELECT
    TRY_CAST(complaint_id AS BIGINT)                                     AS complaint_id,
    TRY_CAST(date_received AS DATE)                                      AS date_received,
    TRY_CAST(date_sent_to_company AS DATE)                               AS date_sent_to_company,
    NULLIF(LTRIM(RTRIM(product)), 'nan')                                 AS product,
    NULLIF(LTRIM(RTRIM(sub_product)), 'nan')                             AS sub_product,
    NULLIF(LTRIM(RTRIM(issue)), 'nan')                                   AS issue,
    NULLIF(LTRIM(RTRIM(sub_issue)), 'nan')                               AS sub_issue,
    NULLIF(LTRIM(RTRIM(company)), 'nan')                                 AS company,
    NULLIF(NULLIF(LTRIM(RTRIM(company_public_response)), 'nan'), 'None') AS company_public_response,
    NULLIF(LTRIM(RTRIM(company_response_to_consumer)), 'nan')            AS company_response_to_consumer,
    NULLIF(LTRIM(RTRIM(state)), 'nan')                                   AS state,
    NULLIF(LTRIM(RTRIM(zip_code)), 'nan')                                AS zip_code,
    NULLIF(NULLIF(LTRIM(RTRIM(tags)), 'nan'), 'None')                    AS tags,
    NULLIF(LTRIM(RTRIM(submitted_via)), 'nan')                           AS submitted_via,
    NULLIF(LTRIM(RTRIM(timely_response)), 'nan')                         AS timely_response
FROM dbo.stg_complaints_raw;
