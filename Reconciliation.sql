--SQL Challenges
--Challenge 1 Find all transactions that exist in both systems. Show transaction_id, product, sds_amount, irecon_amount, and the dollar difference.
-- INNER JOIN 
SELECT
    s.transaction_id,
    s.product_name,
    s.amount    AS sds_amount,
    i.amount    AS irecon_amount,
    (s.amount - i.amount) AS amount_diff
FROM       sds    s
INNER JOIN irecon i
    ON s.transaction_id = i.transaction_id;

--Challenge 2: find all SDS transactions that are missing from iRecon
SELECT
	s.transaction_id,
	s.product_name,
	s.amount,
	s.transaction_date
FROM sds s
LEFT JOIN irecon i
	ON s.transaction_id = i.transaction_id
WHERE i.transaction_id IS NULL;


-- Challenge 3 — FULL OUTER JOIN (Intermediate)
--Write the complete reconciliation query. Classify every transaction as:
-- Match
-- Missing in iRecon
-- Missing in SDS
-- Amount Mismatch
-- Decision Mismatch

SELECT
    COALESCE(s.transaction_id, i.transaction_id) AS transaction_id,
    COALESCE(s.product_name,   i.product_name)   AS product_name,
    s.amount   AS sds_amount,
    i.amount   AS irecon_amount,
    s.decision AS sds_decision,
    i.decision AS irecon_decision,
    CASE
        WHEN i.transaction_id IS NULL       THEN 'Missing in iRecon'
        WHEN s.transaction_id IS NULL       THEN 'Missing in SDS'
        WHEN s.amount   != i.amount         THEN 'Amount Mismatch'
        WHEN s.decision != i.decision       THEN 'Decision Mismatch'
        ELSE 'Match'
    END AS recon_status
FROM            sds    s
FULL OUTER JOIN irecon i
    ON s.transaction_id = i.transaction_id
ORDER BY recon_status;

--Challenge 4 — CTE (Intermediate)
--Using a CTE, classify all transactions then summarize the count and total dollar impact per mismatch type.

WITH recon_classified AS (
    SELECT
        COALESCE(s.transaction_id, i.transaction_id) AS transaction_id,
        COALESCE(s.product_name,   i.product_name)   AS product_name,
        COALESCE(s.amount, 0)                         AS sds_amount,
        COALESCE(i.amount, 0)                         AS irecon_amount,
        CASE
            WHEN i.transaction_id IS NULL   THEN 'Missing in iRecon'
            WHEN s.transaction_id IS NULL   THEN 'Missing in SDS'
            WHEN s.amount != i.amount       THEN 'Amount Mismatch'
            WHEN s.decision != i.decision   THEN 'Decision Mismatch'
            ELSE 'Match'
        END AS recon_status
    FROM            sds    s
    FULL OUTER JOIN irecon i
        ON s.transaction_id = i.transaction_id
)
SELECT
    recon_status,
    COUNT(*)                                          AS record_count,
    SUM(ABS(sds_amount - irecon_amount))    AS total_dollar_impact
FROM  recon_classified
GROUP BY recon_status
ORDER BY record_count DESC;


--Challenge 5 — Window Functions (Advanced)
--For each product, show total mismatches, rank by mismatch count, and flag if above average.

WITH mismatches AS (
    SELECT
        COALESCE(s.product_name, i.product_name) AS product_name,
        CASE
            WHEN i.transaction_id IS NULL   THEN 'Missing in iRecon'
            WHEN s.transaction_id IS NULL   THEN 'Missing in SDS'
            WHEN s.amount != i.amount       THEN 'Amount Mismatch'
            WHEN s.decision != i.decision   THEN 'Decision Mismatch'
            ELSE 'Match'
        END AS recon_status
    FROM            sds   s
    FULL OUTER JOIN irecon i
        ON s.transaction_id = i.transaction_id
),
product_counts AS (
    SELECT
        product_name,
        COUNT(*) AS mismatch_count
    FROM  mismatches
    WHERE recon_status != 'Match'
    GROUP BY product_name
)
SELECT
    product_name,
    mismatch_count,
    RANK() OVER (ORDER BY mismatch_count DESC)          AS rank,
    AVG(mismatch_count) OVER ()                         AS overall_avg,
    CASE
        WHEN mismatch_count > AVG(mismatch_count) OVER ()
        THEN 'Above Average ⚠️'
        ELSE 'Below Average ✅'
    END AS vs_average
FROM  product_counts
ORDER BY rank;