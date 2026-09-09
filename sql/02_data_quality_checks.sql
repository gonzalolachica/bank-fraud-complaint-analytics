-- This script doesn't change any data -- it just looks. It runs a handful of
-- read-only checks against the raw staging table to spot problems before cleaning
-- begins: things like the "nan"/"None" text showing up where real values are missing,
-- dates that don't convert properly, and duplicate complaint IDs. Everything found
-- here is what script 03 goes on to fix.

SELECT
    SUM(CASE WHEN company_public_response IS NULL THEN 1 ELSE 0 END) AS null_count,
    SUM(CASE WHEN company_public_response='nan' THEN 1 ELSE 0 END) AS literal_nan_count,
    SUM(CASE WHEN company_public_response='none' THEN 1 ELSE 0 END) AS literal_null_count,
    COUNT (*) AS total_rows

FROM dbo.stg_complaints_raw;

SELECT
    SUM(CASE WHEN tags IS NULL THEN 1 ELSE 0 END) AS null_count,
    SUM(CASE WHEN tags='nan' THEN 1 ELSE 0 END) AS literal_nan_count,
    SUM(CASE WHEN tags='none' THEN 1 ELSE 0 END) AS literal_null_count,
    COUNT (*) AS total_rows

FROM dbo.stg_complaints_raw;


SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN TRY_CAST(date_received as [DATE]) IS NULL THEN 1 ELSE 0 END) AS unparseable_date_received,
    SUM(CASE WHEN TRY_CAST(date_sent_to_company as [DATE]) IS NULL THEN 1 ELSE 0 END) AS unparseable_date_sent
FROM dbo.stg_complaints_raw;

SELECT complaint_id, COUNT(*) AS dupe_count
from dbo.stg_complaints_raw
GROUP BY complaint_id
HAVING COUNT(*) > 1;
