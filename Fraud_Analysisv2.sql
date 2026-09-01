-- Apple Services Fraud Analysis based on self fabricated data transactions.csv

--database overview
SELECT * FROM transactions;

--TASK 1: Count total transactions, fraud transactions, and calculate fraud rate by product.
SELECT
    product_name,
    COUNT(*)                                        AS total_transactions,
    SUM(is_fraud)                                   AS fraud_count,
    ROUND(100.0 * SUM(is_fraud) / COUNT(*), 1)      AS fraud_rate_pct,
    ROUND(AVG(amount)::numeric,2)                           AS avg_transaction_amount
FROM  transactions
GROUP BY product_name
ORDER BY fraud_count DESC;

--TASK 2: Find all fraudulent transactions where the account is less than 30 days old 
--the highest risk segment.
--Filtering + JOIN Pattern (Beginner)
SELECT
    transaction_id,
    product_name,
    amount,
    fraud_type,
    device_type,
    account_age_days,
    transaction_date
FROM  transactions
WHERE is_fraud = 1
  AND account_age_days < 30
ORDER BY amount DESC;

--TASK 3:
--Using a CTE, first calculate fraud stats by product, 
--then flag products that are above the average fraud rate.
--Using CTE + Aggregation 

WITH product_stats AS (
    SELECT
        product_name,
        COUNT(*)                                    AS total_txns,
        SUM(is_fraud)                               AS fraud_count,
        ROUND(100.0 * SUM(is_fraud) / COUNT(*), 1)  AS fraud_rate_pct,
        ROUND(SUM(CASE WHEN is_fraud = 1
              THEN amount ELSE 0 END)::numeric, 2)           AS total_fraud_amount
    FROM  transactions
    GROUP BY product_name
)
SELECT
    *,
    ROUND(AVG(fraud_rate_pct) OVER (), 1)           AS avg_fraud_rate,
    CASE
        WHEN fraud_rate_pct > AVG(fraud_rate_pct) OVER ()
        THEN 'High Risk ⚠️'
        ELSE 'Normal ✅'
    END AS risk_flag
FROM  product_stats
ORDER BY fraud_rate_pct DESC;


--TASK 4:Rank fraud types by total dollar amount lost, and show each type's share of total fraud losses.
--Using RANK + Window Functions (Intermediate)

WITH fraud_by_type AS (
    SELECT
        fraud_type,
        COUNT(*)            AS fraud_count,
        ROUND(SUM(amount)::numeric, 2) AS total_amount
    FROM  transactions
    WHERE is_fraud = 1
    GROUP BY fraud_type
)
SELECT
    fraud_type,
    fraud_count,
    total_amount,
    RANK() OVER (ORDER BY total_amount DESC)            AS amount_rank,
    ROUND(100.0 * total_amount /
          SUM(total_amount) OVER (), 1)                 AS pct_of_total_losses
FROM  fraud_by_type
ORDER BY amount_rank;


--TASK 5: Show daily fraud counts and flag days where fraud spiked more than 20% compared to the previous day.
-- LAG + Daily Trend (Advanced)

WITH daily_fraud AS (
    SELECT
        transaction_date,
        COUNT(*)  AS daily_fraud_count,
        ROUND(SUM(amount)::numeric, 2) AS daily_fraud_amount
    FROM  transactions
    WHERE is_fraud = 1
    GROUP BY transaction_date
),
with_lag AS (
    SELECT
        transaction_date,
        daily_fraud_count,
        daily_fraud_amount,
        LAG(daily_fraud_count, 1) OVER (ORDER BY transaction_date) AS prev_day_count
    FROM daily_fraud
)
SELECT
    transaction_date,
    daily_fraud_count,
    prev_day_count,
    daily_fraud_count - prev_day_count                  AS day_over_day_change,
    CASE
        WHEN prev_day_count > 0
         AND (daily_fraud_count - prev_day_count) * 1.0
             / prev_day_count > 0.20
        THEN '⚠️ Spike Detected'
        ELSE '✅ Normal'
    END AS alert_flag
FROM  with_lag
ORDER BY transaction_date;


--TASK 6: For each product and device type combination, show fraud rate, rank, running total of fraud amount, and risk classification.
--Full Analysis Query (Advanced)

WITH device_product_stats AS (
    SELECT
        product_name,
        device_type,
        COUNT(*)                                        AS total_txns,
        SUM(is_fraud)                                   AS fraud_count,
        ROUND(100.0 * SUM(is_fraud) / COUNT(*), 1)      AS fraud_rate_pct,
        ROUND(SUM(CASE WHEN is_fraud = 1
              THEN amount ELSE 0 END)::numeric, 2)               AS fraud_amount
    FROM  transactions
    GROUP BY product_name, device_type
)
SELECT
    product_name,
    device_type,
    total_txns,
    fraud_count,
    fraud_rate_pct,
    fraud_amount,
    RANK() OVER (ORDER BY fraud_rate_pct DESC)          AS fraud_rate_rank,
    SUM(fraud_amount) OVER (
        ORDER BY fraud_amount DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS running_fraud_total,
    CASE
        WHEN fraud_rate_pct >= 50 THEN '🔴 Critical'
        WHEN fraud_rate_pct >= 25 THEN '🟡 High'
        ELSE                           '🟢 Normal'
    END AS risk_level
FROM  device_product_stats
ORDER BY fraud_rate_rank;