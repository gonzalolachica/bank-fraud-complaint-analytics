# CFPB Data Ingestion — Troubleshooting Log

Plain-English record of what went wrong during Phase 2 (ingestion), how we figured out why, and how we fixed it. Written chronologically, step by step.

## The short version

We started with a manual "download the CSV, hand-edit it in Notepad, drag it into Fabric" process. It silently corrupted the data. We traced the corruption to how the data was being parsed, tried a couple of fixes, hit two more separate bugs along the way (a blocked request, a wrong company name, and an API limit), and ended up replacing the whole ingestion step with a small, repeatable Python script in a Fabric notebook. Final result: **176,927 clean rows**, all three companies (Truist, JPMorgan Chase, American Express), correctly parsed.

## Step by step

### 1. Original approach: download + Notepad + drag-and-drop
The process was: download the CFPB CSV by hand, open it in Notepad to rename the header row to match our table's column names, save it, then drag it into the Fabric Lakehouse and use "Load to Tables."

**Why this was a problem:** it's manual, not repeatable, and — as it turned out — not safe for a large file with complex text fields.

### 2. First sign of trouble: garbage values where they shouldn't be
After loading, a simple `SELECT company, COUNT(*)` query showed nonsense: values like `Web`, `Servicemember`, `Older American`, and long response-text sentences appearing in the `company` column, alongside real company names. About half the rows had `company = NULL`. JPMorgan Chase didn't show up in the results at all.

### 3. Diagnosing the cause: quoted commas weren't being respected
CFPB's product names often contain commas — e.g. `"Credit reporting, credit repair services, or other personal consumer reports"`. Standard CSV format wraps such fields in quotes so the commas inside don't get mistaken for column separators. We fetched a raw sample directly from CFPB's API and confirmed: **the source file is correctly quoted.** The corruption was happening during ingestion — something in the loading process wasn't respecting those quotes, so it was splitting fields at every comma, including the ones inside quotes, and shifting everything after that point sideways.

### 4. First fix attempt: a Fabric "Copy Job" with explicit quote settings
We rebuilt the ingestion as a proper Fabric Copy Job pulling directly from the CFPB API, with the quote character and escape character explicitly set to `"`. This fixed *some* of the misalignment, but a data preview afterward showed a second, worse problem: fragments of complaint narrative text (long free-form paragraphs) were leaking into the `date_received` and `product` columns. This pointed to a second bug — the parser wasn't correctly handling text fields that contained embedded line breaks (a complaint narrative can span multiple paragraphs), so it was treating a line break inside a quoted field as the start of a brand new row.

### 5. The real fix: replace the loader with a Python notebook
Rather than keep fighting Fabric's built-in CSV parser, we switched to a Fabric Notebook running Python (`pandas` + `requests`). Pandas handles standard CSV quoting and embedded line breaks correctly by default — no special configuration needed. We also dropped the `consumer_complaint_narrative` field entirely: the project is scoped as structured-data-only (CFPB narrative field is out of scope, and it was the most error-prone field in the whole file anyway).

### 6. Bug: CFPB blocked the request (403 Forbidden)
Python's default request identifies itself in a way that CFPB's site blocks (a common anti-bot measure on government sites). Fixed by sending a normal browser-style `User-Agent` header.

### 7. Bug: notebook had no lakehouse attached
Writing a table from the notebook requires the notebook to have a Lakehouse attached as its default target (Fabric needs to know *where* `saveAsTable(...)` should write to). Fixed by attaching the existing `staging_lakehouse` from the notebook's Lakehouses panel.

### 8. Bug: wrong exact company name for JPMorgan Chase
Our filter used `"JP MORGAN CHASE & CO"` — but CFPB's actual stored value is `"JPMORGAN CHASE & CO."` (one word, trailing period). Complaint filters need an *exact* string match, so the wrong spelling silently returned zero JPMorgan Chase rows every time, even while Truist and American Express worked fine. We found the correct spelling by searching CFPB's data for anything mentioning "chase" and reading back the real value.

### 9. Bug: pulling JPMorgan Chase's full date range in one request failed
Even with the correct name, pulling all of JPMorgan Chase's 2020–2026 complaints in a single request returned an error mentioning "size" — most likely an internal limit on how many results the API will return in one shot. JPMorgan Chase has a much larger complaint volume than Truist or Amex (it's the largest US bank by assets), so it was the only one of the three hitting that ceiling. Fixed by pulling year-by-year (2020, 2021, ... 2026) and combining the results — every year's slice was small enough to succeed.

### 10. Final clean pull
- 2020: 14,041 rows
- 2021: 16,619 rows
- 2022: 19,853 rows
- 2023: 25,281 rows
- 2024: 32,123 rows
- 2025: 40,164 rows
- 2026: 28,846 rows
- **Total: 176,927 rows** — JPMorgan Chase & Co. (108,722), American Express (43,793), Truist (24,412)

Written to the lakehouse as `complaints_2026_clean`. The old corrupted tables (`complaints-2026`) were deleted. The warehouse's `dbo.stg_complaints_raw` was reloaded from this clean source (schema updated to 15 columns, narrative field removed).

## Data quality / standardization pass

Handled in the star-schema build (see `docs/sql-scripts-documentation.md`, scripts 01-10):

- **"nan" string artifact**: converting the pandas dataframe to text (`.astype(str)`) before writing to the lakehouse turned genuinely missing values into the literal text `"nan"` in some columns (e.g. `company_public_response`, `tags`) — told apart from CFPB's own legitimate `"None"` convention (real source data meaning "no response given") and cleaned up in script 03.
- **Date format**: `date_received` / `date_sent_to_company` arrived as ISO 8601 timestamp text in a `VARCHAR` column — converted to a real `DATE` type in script 03, with every row confirmed to convert cleanly in script 04.
- **Duplicate `complaint_id` check** — confirmed each complaint appears exactly once (script 04).

## The final ingestion notebook

The working notebook (`notebooks/ingest_cfpb_complaints.ipynb`) implements the fix from step 5 onward: pulls each year's data from the CFPB Complaint Search API with a browser-style `User-Agent`, concatenates the seven yearly frames, renames columns to snake_case, drops the narrative field, and writes the result to the lakehouse as `complaints_2026_clean`.

## Why this is worth keeping in the portfolio writeup

This is a better interview story than "the pipeline just worked": diagnosing silent data corruption from first symptoms, proving the fix by fetching and inspecting raw source bytes, isolating unrelated bugs one at a time (quoting → embedded newlines → blocked request → wrong filter string → API result-size limit) instead of guessing, and replacing a fragile manual process with a small, reproducible script.
