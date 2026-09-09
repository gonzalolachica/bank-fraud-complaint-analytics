-- Takes the raw CFPB product categories (which are messy and inconsistent -- the same
-- product sometimes has two slightly different names depending on when the complaint
-- was filed) and groups them into a smaller, clean set of product categories used
-- throughout the rest of this project.

DROP TABLE IF EXISTS dbo.dim_product;

CREATE TABLE dbo.dim_product (
product_key     INT,
product_name    VARCHAR(500),
product_group   VARCHAR(200)
);

INSERT INTO dbo.dim_product (product_key, product_name, product_group)
VALUES
    (1,  'Checking or savings account',                                                    'Checking or Savings Account'),
    (2,  'Credit card',                                                                    'Credit Card / Prepaid Card'),
    (3,  'Credit card or prepaid card',                                                    'Credit Card / Prepaid Card'),
    (4,  'Prepaid card',                                                                   'Credit Card / Prepaid Card'),
    (5,  'Credit reporting or other personal consumer reports',                            'Credit Reporting'),
    (6,  'Credit reporting, credit repair services, or other personal consumer reports',   'Credit Reporting'),
    (7,  'Debt collection',                                                                'Debt Collection'),
    (8,  'Money transfer, virtual currency, or money service',                             'Money Transfer / Virtual Currency'),
    (9,  'Mortgage',                                                                       'Mortgage'),
    (10, 'Vehicle loan or lease',                                                          'Vehicle Loan or Lease'),
    (11, 'Payday loan, title loan, personal loan, or advance loan',                        'Payday / Title / Personal Loan'),
    (12, 'Payday loan, title loan, or personal loan',                                      'Payday / Title / Personal Loan'),
    (13, 'Debt or credit management',                                                      'Debt or Credit Management'),
    (14, 'Student loan',                                                                   'Student Loan');

SELECT * FROM dbo.dim_product ORDER BY product_key;


-- Validation: confirmation that every product value in the clean data has a home here (should return no rows)
SELECT DISTINCT c.product
FROM dbo.stg_complaints_clean c
LEFT JOIN dbo.dim_product p ON c.product = p.product_name
WHERE p.product_key IS NULL;
