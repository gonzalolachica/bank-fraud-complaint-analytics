-- Builds a reference table of US states (plus an explicit "Unknown" row for complaints
-- with no state on file), along with each state's full name and Census region. The
-- state code column is sized generously on purpose -- some CFPB records list a full
-- location name like "United States Minor Outlying Islands" instead of a normal
-- two-letter code, and a tight column size would have cut that off.

DROP TABLE IF EXISTS dbo.dim_geography;

CREATE TABLE dbo.dim_geography(
    geography_key       INT,
    state_code          VARCHAR(50),
    state_name          VARCHAR(100),
    region              VARCHAR(50)
);
GO

INSERT INTO dbo.dim_geography (geography_key, state_code, state_name, region)
SELECT
    ROW_NUMBER() OVER(ORDER BY state_code) AS geography_key,
    state_code,
    CASE state_code
       WHEN 'AL' THEN 'Alabama' WHEN 'AK' THEN 'Alaska' WHEN 'AZ' THEN 'Arizona' WHEN 'AR' THEN 'Arkansas'
        WHEN 'CA' THEN 'California' WHEN 'CO' THEN 'Colorado' WHEN 'CT' THEN 'Connecticut' WHEN 'DE' THEN 'Delaware'
        WHEN 'DC' THEN 'District of Columbia' WHEN 'FL' THEN 'Florida' WHEN 'GA' THEN 'Georgia' WHEN 'HI' THEN 'Hawaii'
        WHEN 'ID' THEN 'Idaho' WHEN 'IL' THEN 'Illinois' WHEN 'IN' THEN 'Indiana' WHEN 'IA' THEN 'Iowa'
        WHEN 'KS' THEN 'Kansas' WHEN 'KY' THEN 'Kentucky' WHEN 'LA' THEN 'Louisiana' WHEN 'ME' THEN 'Maine'
        WHEN 'MD' THEN 'Maryland' WHEN 'MA' THEN 'Massachusetts' WHEN 'MI' THEN 'Michigan' WHEN 'MN' THEN 'Minnesota'
        WHEN 'MS' THEN 'Mississippi' WHEN 'MO' THEN 'Missouri' WHEN 'MT' THEN 'Montana' WHEN 'NE' THEN 'Nebraska'
        WHEN 'NV' THEN 'Nevada' WHEN 'NH' THEN 'New Hampshire' WHEN 'NJ' THEN 'New Jersey' WHEN 'NM' THEN 'New Mexico'
        WHEN 'NY' THEN 'New York' WHEN 'NC' THEN 'North Carolina' WHEN 'ND' THEN 'North Dakota' WHEN 'OH' THEN 'Ohio'
        WHEN 'OK' THEN 'Oklahoma' WHEN 'OR' THEN 'Oregon' WHEN 'PA' THEN 'Pennsylvania' WHEN 'RI' THEN 'Rhode Island'
        WHEN 'SC' THEN 'South Carolina' WHEN 'SD' THEN 'South Dakota' WHEN 'TN' THEN 'Tennessee' WHEN 'TX' THEN 'Texas'
        WHEN 'UT' THEN 'Utah' WHEN 'VT' THEN 'Vermont' WHEN 'VA' THEN 'Virginia' WHEN 'WA' THEN 'Washington'
        WHEN 'WV' THEN 'West Virginia' WHEN 'WI' THEN 'Wisconsin' WHEN 'WY' THEN 'Wyoming'
        WHEN 'PR' THEN 'Puerto Rico' WHEN 'VI' THEN 'U.S. Virgin Islands' WHEN 'GU' THEN 'Guam'
        WHEN 'MP' THEN 'Northern Mariana Islands' WHEN 'AS' THEN 'American Samoa'
        WHEN 'AA' THEN 'Armed Forces Americas' WHEN 'AE' THEN 'Armed Forces Europe' WHEN 'AP' THEN 'Armed Forces Pacific'
        WHEN 'UNITED STATES MINOR OUTLYING ISLANDS' THEN 'United States Minor Outlying Islands'
        WHEN 'UNK' THEN 'Unknown / Not Specified'
        ELSE state_code
    END AS state_name,
    CASE
        WHEN state_code IN ('CT','ME','MA','NH','RI','VT','NJ','NY','PA') THEN 'Northeast'
        WHEN state_code IN ('IL','IN','MI','OH','WI','IA','KS','MN','MO','NE','ND','SD') THEN 'Midwest'
        WHEN state_code IN ('DE','FL','GA','MD','NC','SC','VA','DC','WV','AL','KY','MS','TN','AR','LA','OK','TX') THEN 'South'
        WHEN state_code IN ('AZ','CO','ID','MT','NV','NM','UT','WY','AK','CA','HI','OR','WA') THEN 'West'
        WHEN state_code IN ('PR','VI','GU','MP','AS','AA','AE','AP','UNITED STATES MINOR OUTLYING ISLANDS') THEN 'U.S. Territories / Military'
        ELSE 'Unknown'
    END AS region
FROM (
    SELECT DISTINCT ISNULL(state, 'UNK') AS state_code
    FROM dbo.stg_complaints_clean
) AS distinct_states;
GO

SELECT COUNT (*) FROM dbo.dim_geography
SELECT * FROM dbo.dim_geography ORDER BY region, state_name
