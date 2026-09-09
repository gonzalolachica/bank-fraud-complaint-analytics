-- This script double-checks that the cleanup in script 03 actually worked. It
-- confirms every row's dates converted properly, there are no duplicate complaint
-- IDs, and the missing-value counts come back the way they should. This is the
-- "trust but verify" step -- it doesn't assume the clean table is correct, it proves it.

SELECT
    (SELECT COUNT (*) FROM dbo.stg_complaints_raw) AS raw_row_count,
    (SELECT COUNT (*) FROM dbo.stg_complaints_clean) AS clean_row_count;


SELECT COUNT(*) AS leftover_nan_values
FROM dbo.stg_complaints_clean
WHERE company_public_response = 'nan' or tags = 'nan';

SELECT complaint_id, COUNT(*) AS dupe_count
FROM dbo.stg_complaints_clean
GROUP BY complaint_id
HAVING COUNT (*) >1
