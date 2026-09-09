# Plain-language header comments — paste each block at the top of its matching script

## 01_load_stg_complaints_raw.sql
```sql
-- This script reloads the raw staging table in the warehouse from the cleaned data
-- sitting in the lakehouse. Think of it as a refresh step: if this table ever needs
-- to be rebuilt, this is what re-copies the correctly-parsed CFPB data across without
-- having to re-pull anything from the CFPB API.
```

## 02_data_quality_checks.sql
```sql
-- This script doesn't change any data -- it just looks. It runs a handful of
-- read-only checks against the raw staging table to spot problems before cleaning
-- begins: things like the "nan"/"None" text showing up where real values are missing,
-- dates that don't convert properly, and duplicate complaint IDs. Everything found
-- here is what script 03 goes on to fix.
```

## 03_build_stg_complaints_clean.sql
```sql
-- This is the actual cleanup step. It takes the raw staging data and produces a
-- proper, typed version of it: real DATE columns instead of text, right-sized
-- VARCHAR columns, and the "nan"/"None" text artifacts converted to real NULLs.
-- Every later script in this project builds off of this clean table, not the raw one.
```

## 04_validate_stg_complaints_clean.sql
```sql
-- This script double-checks that the cleanup in script 03 actually worked. It
-- confirms every row's dates converted properly, there are no duplicate complaint
-- IDs, and the missing-value counts come back the way they should. This is the
-- "trust but verify" step -- it doesn't assume the clean table is correct, it proves it.
```

## 05_build_dim_company.sql
```sql
-- Builds a small reference table with the three companies in this project (Truist,
-- JPMorgan Chase, American Express) and a flag for whether each one co-owns Zelle.
-- This is typed in by hand rather than pulled from the data, since which companies
-- are being compared is a fixed decision for this project, not something to detect.
```

## 06_build_dim_date.sql
```sql
-- Builds a full calendar table covering 2020 through 2026 -- one row per day, with
-- the year, quarter, month, and day of week already broken out. Having this table
-- means later queries can group complaints by year or month without doing date math
-- every time.
```

## 07_build_dim_product.sql
```sql
-- Takes the raw CFPB product categories (which are messy and inconsistent -- the same
-- product sometimes has two slightly different names depending on when the complaint
-- was filed) and groups them into a smaller, clean set of product categories used
-- throughout the rest of this project.
```

## 08_build_dim_issue.sql
```sql
-- Builds a reference table of every distinct complaint issue/sub-issue combination
-- (275 of them) and marks which ones are actually fraud-related. This isn't done with
-- a simple keyword search -- an early attempt using LIKE '%fraud%' and similar keyword
-- matches was found to misclassify real complaints (for example, a billing complaint
-- about an "identity theft protection" subscription service isn't actually about
-- identity theft). Instead, this uses a manually reviewed list of exactly which
-- issue/sub-issue pairs count as fraud-related.
```

## 09_build_dim_geography.sql
```sql
-- Builds a reference table of US states (plus an explicit "Unknown" row for complaints
-- with no state on file), along with each state's full name and Census region. The
-- state code column is sized generously on purpose -- some CFPB records list a full
-- location name like "United States Minor Outlying Islands" instead of a normal
-- two-letter code, and a tight column size would have cut that off.
```

## 10_build_fact_complaints.sql
```sql
-- This is the heart of the data model. It joins every complaint to its company, date,
-- product, and issue information, and calculates one key flag: whether that complaint
-- counts as fraud/scam-related. That flag combines two things -- whether the issue
-- itself was marked fraud-related, or whether the complaint falls under the "Money
-- transfer, virtual currency, or money service" category. Every analysis query in this
-- project (scripts 11 onward) runs against this table.
```

## 11_analysis_fraud_by_company.sql
```sql
-- Answers: out of each company's total complaints, what percentage were fraud-related?
-- This is the project's core comparison number -- it shows Chase, Truist, and Amex
-- side by side on how much of their complaint load is fraud, not just raw counts.
```

## 12_analysis_category_breakdown.sql
```sql
-- Answers: when a complaint IS fraud-related, which product category does it actually
-- get filed under? This matters because fraud complaints don't all land in the obvious
-- "money transfer" category -- a lot of them get filed under checking/savings accounts
-- or credit cards instead, which is exactly why the fraud definition in script 08
-- couldn't rely on product category alone.
```

## 13_analysis_geographic_distribution.sql
```sql
-- Answers: which US states have the most fraud complaints? Breaks down fraud
-- complaint counts and percentages by state and region.
```

## 14_analysis_fraud_trend_over_time.sql
```sql
-- Answers: how has fraud complaint volume changed year over year, for each company?
-- Important note: the most recent year (2026) in this data is incomplete -- it only
-- covers part of the year -- so its raw count looks lower than it really would be for
-- a full year. That correction is handled in script 15, not here; this script
-- intentionally shows the numbers exactly as they are in the data.
```

## 15_analysis_fraud_trend_yoy_pct_change.sql
```sql
-- Answers: what's the real percentage change in fraud complaint volume from one year
-- to the next, per company -- correcting for the fact that the most recent year (2026)
-- in the data is incomplete? Before comparing 2026 to prior years, this script scales
-- the 2026 count up as if the full year had happened, so the comparison is fair.
-- Important: this measures growth in complaint counts, not fraud itself -- more
-- complaints can also mean more people using the product or more people becoming
-- aware they can file a complaint, not only more fraud actually happening.
```

## 16_analysis_fraud_seasonality.sql
```sql
-- Answers: does fraud complaint volume vary depending on the time of year? This looks
-- at fraud complaints by calendar month, combined across every complete year on file
-- (2020-2025). The most recent year, 2026, is left out of this one on purpose --
-- it's not finished yet, and including a partial year would make the last few months
-- look artificially low compared to the others.
```

## 17_analysis_company_category_crosstab.sql
```sql
-- Answers: for each company individually, which product categories does ITS fraud
-- actually show up in? This is the same idea as script 12's category breakdown, but
-- broken out separately for each company instead of combining all three together --
-- so you can see whether Chase, Truist, and Amex actually have different fraud
-- patterns, rather than assuming they look the same just because two of them are
-- both exposed to Zelle.
```
