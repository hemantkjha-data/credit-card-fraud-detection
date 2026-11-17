-- ============================================================
-- Credit Card Fraud Detection — SQL Analysis
-- Data: 30,000 card transactions, 180 confirmed frauds (0.6%)
-- ============================================================

-- 1. Fraud rate by hour of day (detects card-testing / night-time patterns)
SELECT txn_hour,
       COUNT(*) AS txns,
       SUM(is_fraud) AS frauds,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 0) AS fraud_amount
FROM transactions
GROUP BY txn_hour
ORDER BY txn_hour;

-- 2. Fraud concentration by amount bucket (value-tilt of fraud)
SELECT CASE WHEN amount < 1000 THEN 'a <1K'
            WHEN amount < 5000 THEN 'b 1-5K'
            WHEN amount < 15000 THEN 'c 5-15K'
            WHEN amount < 30000 THEN 'd 15-30K'
            ELSE 'e 30K+' END AS amount_bucket,
       COUNT(*) AS txns,
       SUM(is_fraud) AS frauds,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY amount_bucket
ORDER BY amount_bucket;

-- 3. Fraud rate by merchant category, card type and region
SELECT 'merchant' AS dimension, merchant_category AS key,
       COUNT(*) AS txns, SUM(is_fraud) AS frauds,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions GROUP BY merchant_category
UNION ALL
SELECT 'card', card_type, COUNT(*), SUM(is_fraud),
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2)
FROM transactions GROUP BY card_type
UNION ALL
SELECT 'region', region, COUNT(*), SUM(is_fraud),
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2)
FROM transactions GROUP BY region;

-- 4. High-velocity cards (many txns in 24h) — account-takeover signal
SELECT txn_velocity_24h,
       COUNT(*) AS cards,
       SUM(is_fraud) AS frauds,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY txn_velocity_24h
ORDER BY txn_velocity_24h;

-- 5. Rule-based fraud detector + confusion matrix
-- Rule: large amount OR (international + high velocity) OR (very high velocity + moderate amount)
SELECT
  SUM(CASE WHEN is_fraud = 1 AND (amount >= 15000
        OR (is_international = 1 AND txn_velocity_24h >= 5)
        OR (txn_velocity_24h >= 8 AND amount >= 3000)) THEN 1 ELSE 0 END) AS true_positives,
  SUM(CASE WHEN is_fraud = 0 AND (amount >= 15000
        OR (is_international = 1 AND txn_velocity_24h >= 5)
        OR (txn_velocity_24h >= 8 AND amount >= 3000)) THEN 1 ELSE 0 END) AS false_positives,
  SUM(CASE WHEN is_fraud = 1 AND NOT (amount >= 15000
        OR (is_international = 1 AND txn_velocity_24h >= 5)
        OR (txn_velocity_24h >= 8 AND amount >= 3000)) THEN 1 ELSE 0 END) AS false_negatives
FROM transactions;

-- 6. Value capture: how much of the fraud rupee value the rule recovers
SELECT ROUND(SUM(CASE WHEN is_fraud = 1 AND (amount >= 15000
        OR (is_international = 1 AND txn_velocity_24h >= 5)
        OR (txn_velocity_24h >= 8 AND amount >= 3000)) THEN amount ELSE 0 END), 0) AS fraud_value_captured,
       ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 0) AS total_fraud_value
FROM transactions;
