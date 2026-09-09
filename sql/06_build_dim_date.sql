-- Builds a full calendar table covering 2020 through 2026 -- one row per day, with
-- the year, quarter, month, and day of week already broken out. Having this table
-- means later queries can group complaints by year or month without doing date math
-- every time.

DROP TABLE IF EXISTS dbo.dim_date;

CREATE TABLE dbo.dim_date (
    date_key      INT,
    full_date     DATE,
    year          INT,
    quarter       INT,
    month         INT,
    month_name    VARCHAR(20),
    day           INT,
    day_of_week   INT,
    day_name      VARCHAR(20),
    is_weekend    BIT
);
GO

WITH digits AS (
    SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
numbers AS (
    SELECT d1.d + d2.d*10 + d3.d*100 + d4.d*1000 AS n
    FROM digits d1 CROSS JOIN digits d2 CROSS JOIN digits d3 CROSS JOIN digits d4
),
calendar AS (
    SELECT DATEADD(DAY, n, CAST('2020-01-01' AS DATE)) AS full_date
    FROM numbers
    WHERE DATEADD(DAY, n, CAST('2020-01-01' AS DATE)) <= '2026-12-31'
)
INSERT INTO dbo.dim_date (date_key, full_date, year, quarter, month, month_name, day, day_of_week, day_name, is_weekend)
SELECT
    YEAR(full_date)*10000 + MONTH(full_date)*100 + DAY(full_date) AS date_key,
    full_date,
    YEAR(full_date)                                AS year,
    DATEPART(QUARTER, full_date)                   AS quarter,
    MONTH(full_date)                               AS month,
    DATENAME(MONTH, full_date)                     AS month_name,
    DAY(full_date)                                 AS day,
    DATEPART(WEEKDAY, full_date)                   AS day_of_week,
    DATENAME(WEEKDAY, full_date)                   AS day_name,
    CASE WHEN DATEPART(WEEKDAY, full_date) IN (1,7) THEN 1 ELSE 0 END AS is_weekend
FROM calendar;
GO

SELECT COUNT(*) FROM dbo.dim_date;
SELECT TOP 5 * FROM dbo.dim_date ORDER BY full_date;
SELECT TOP 5 * FROM dbo.dim_date ORDER BY full_date DESC;

--Verify it created the table properly
SELECT * FROM dbo.dim_date

SELECT product, COUNT(*) AS cnt
FROM dbo.stg_complaints_clean
GROUP BY product
ORDER BY cnt DESC;
