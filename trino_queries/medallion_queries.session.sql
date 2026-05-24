
-- ============================================================
--  MEDALLION PLATFORM — Trino Query Playbook
--  Catalog : hive
--  Default schema configured in settings: transactions_db
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 1 — HMS METADATA DISCOVERY                     ║
-- ╚══════════════════════════════════════════════════════════╝

-- 1.1  List all catalogs registered in Trino
SHOW CATALOGS;

-- 1.2  List all schemas inside the hive catalog
SHOW SCHEMAS FROM hive;

-- 1.3  List all tables in the transactions domain
SHOW TABLES FROM hive.transactions_db;

-- 1.4  Partition listing for Gold (what dates were aggregated?)
SELECT "$path", booked_date
FROM   hive.transactions_db.gold_transactions
GROUP  BY "$path", booked_date
ORDER  BY booked_date;

-- 1.5  Full column-level schema — Bronze transactions table
DESCRIBE hive.transactions_db.bronze_transactions;

-- 1.6  Full column-level schema — Silver transactions table
DESCRIBE hive.transactions_db.silver_transactions;

-- 1.7  Full column-level schema — Gold transactions table
DESCRIBE hive.transactions_db.gold_transactions;

-- 1.8  Partition listing for Bronze (what dates were ingested?)
SELECT "$path", booked_date
FROM   hive.transactions_db.bronze_transactions
GROUP  BY "$path", booked_date
ORDER  BY booked_date;

-- 1.9  Partition listing for Silver
SELECT "$path", booked_date
FROM   hive.transactions_db.silver_transactions
GROUP  BY "$path", booked_date
ORDER  BY booked_date;

-- 1.10  Storage / format metadata via information_schema
SELECT table_schema,
       table_name,
       table_type
FROM   hive.information_schema.tables
WHERE  table_schema = 'transactions_db'
ORDER  BY table_name;

-- 1.11  All columns across all medallion tables (data dictionary view)
SELECT table_schema,
       table_name,
       column_name,
       ordinal_position,
       data_type,
       is_nullable
FROM   hive.information_schema.columns
WHERE  table_schema = 'transactions_db'
ORDER  BY table_name, ordinal_position;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 2 — BRONZE LAYER                               ║
-- ║  Raw ingested data, minimal cleaning                     ║
-- ║  Schema: transaction_id, booked_at, amount,              ║
-- ║          transaction_type  |  partition: booked_date     ║
-- ╚══════════════════════════════════════════════════════════╝

-- 2.1  Quick sanity — first 20 rows (all partitions)
SELECT *
FROM   hive.transactions_db.bronze_transactions
ORDER  BY booked_at
LIMIT  20;

-- 2.2  Row count per partition (data volume by day)
SELECT booked_date,
       COUNT(*) AS row_count
FROM   hive.transactions_db.bronze_transactions
GROUP  BY booked_date
ORDER  BY booked_date;

-- 2.3  Type distribution (volume by transaction_type)
SELECT transaction_type,
       COUNT(*)                                AS txn_count,
       ROUND(SUM(amount), 2)                  AS total_amount,
       ROUND(AVG(amount), 2)                  AS avg_amount,
       ROUND(MIN(amount), 2)                  AS min_amount,
       ROUND(MAX(amount), 2)                  AS max_amount
FROM   hive.transactions_db.bronze_transactions
GROUP  BY transaction_type
ORDER  BY txn_count DESC;

-- 2.4  NULL / data-quality audit on Bronze
SELECT COUNT(*)                                                 AS total_rows,
       COUNT(*) FILTER (WHERE transaction_id IS NULL)          AS null_txn_id,
       COUNT(*) FILTER (WHERE booked_at IS NULL)               AS null_booked_at,
       COUNT(*) FILTER (WHERE amount IS NULL)                  AS null_amount,
       COUNT(*) FILTER (WHERE transaction_type IS NULL)        AS null_txn_type,
       COUNT(DISTINCT transaction_id)                          AS distinct_txn_ids
FROM   hive.transactions_db.bronze_transactions;

-- 2.5  Duplicate transaction_id check in Bronze
SELECT transaction_id,
       COUNT(*) AS occurrences
FROM   hive.transactions_db.bronze_transactions
GROUP  BY transaction_id
HAVING COUNT(*) > 1
ORDER  BY occurrences DESC;

-- 2.6  Daily cash-flow summary from Bronze (deposits vs withdrawals)
SELECT booked_date,
       ROUND(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 2) AS total_inflows,
       ROUND(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END), 2) AS total_outflows,
       ROUND(SUM(amount), 2)                                      AS net_flow,
       COUNT(*)                                                    AS txn_count
FROM   hive.transactions_db.bronze_transactions
GROUP  BY booked_date
ORDER  BY booked_date;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 3 — SILVER LAYER                               ║
-- ║  Cleaned, validated, enriched data                       ║
-- ║  Extra column: amount_valid BOOLEAN                      ║
-- ║  Partition: booked_date (same key as Bronze)             ║
-- ╚══════════════════════════════════════════════════════════╝

-- 3.1  Quick sanity — first 20 rows
SELECT *
FROM   hive.transactions_db.silver_transactions
ORDER  BY booked_at
LIMIT  20;

-- 3.2  Row count per partition
SELECT booked_date,
       COUNT(*)                                            AS row_count,
       COUNT(*) FILTER (WHERE amount_valid = TRUE)        AS valid_amount_count,
       COUNT(*) FILTER (WHERE amount_valid = FALSE)       AS invalid_amount_count
FROM   hive.transactions_db.silver_transactions
GROUP  BY booked_date
ORDER  BY booked_date;

-- 3.3  Valid transactions only — type breakdown with amounts
SELECT transaction_type,
       COUNT(*)                                AS txn_count,
       ROUND(SUM(amount), 2)                  AS total_amount,
       ROUND(AVG(amount), 2)                  AS avg_amount
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY transaction_type
ORDER  BY txn_count DESC;

-- 3.4  Flagged (invalid amount) transactions — spot-check
SELECT *
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = FALSE
ORDER  BY booked_date;

-- 3.5  Running net balance over time (Silver, valid amounts only)
SELECT booked_date,
       ROUND(SUM(amount), 2)                                           AS daily_net,
       ROUND(SUM(SUM(amount)) OVER (ORDER BY booked_date
                                    ROWS BETWEEN UNBOUNDED PRECEDING
                                             AND CURRENT ROW), 2)      AS running_balance
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;

-- 3.6  Amount percentile distribution (Silver)
SELECT transaction_type,
       APPROX_PERCENTILE(amount, 0.25)  AS p25,
       APPROX_PERCENTILE(amount, 0.50)  AS median,
       APPROX_PERCENTILE(amount, 0.75)  AS p75,
       APPROX_PERCENTILE(amount, 0.95)  AS p95
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY transaction_type;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 4 — CROSS-LAYER RECONCILIATION                 ║
-- ║  Bronze ↔ Silver ↔ Gold quality gates                    ║
-- ╚══════════════════════════════════════════════════════════╝

-- 4.1  Row counts per layer per date — detect drops
SELECT b.booked_date,
       COUNT(DISTINCT b.transaction_id)  AS bronze_count,
       COUNT(DISTINCT s.transaction_id)  AS silver_count,
       COUNT(DISTINCT b.transaction_id)
         - COUNT(DISTINCT s.transaction_id) AS dropped_in_silver
FROM   hive.transactions_db.bronze_transactions b
LEFT   JOIN hive.transactions_db.silver_transactions s
       ON b.transaction_id = s.transaction_id
GROUP  BY b.booked_date
ORDER  BY b.booked_date;

-- 4.2  Transactions in Bronze but MISSING from Silver (dead-letter candidates)
SELECT b.*
FROM   hive.transactions_db.bronze_transactions b
WHERE  NOT EXISTS (
    SELECT 1
    FROM   hive.transactions_db.silver_transactions s
    WHERE  s.transaction_id = b.transaction_id
);

-- 4.3  Amount discrepancy between Bronze and Silver
--      (should be 0 for valid rows; non-zero indicates transform bug)
SELECT b.transaction_id,
       b.booked_date,
       b.amount                        AS bronze_amount,
       s.amount                        AS silver_amount,
       b.amount - s.amount             AS delta
FROM   hive.transactions_db.bronze_transactions b
JOIN   hive.transactions_db.silver_transactions s
       ON b.transaction_id = s.transaction_id
WHERE  b.amount <> s.amount
   OR (b.amount IS NULL AND s.amount IS NOT NULL)
   OR (b.amount IS NOT NULL AND s.amount IS NULL);

-- 4.4  Transaction type preservation check Bronze → Silver
SELECT b.transaction_type             AS bronze_type,
       s.transaction_type             AS silver_type,
       COUNT(*)                       AS mismatch_count
FROM   hive.transactions_db.bronze_transactions b
JOIN   hive.transactions_db.silver_transactions s
       ON b.transaction_id = s.transaction_id
WHERE  b.transaction_type <> s.transaction_type
GROUP  BY b.transaction_type, s.transaction_type;

-- 4.5  Partition coverage — dates present in Bronze but absent in Silver
SELECT DISTINCT booked_date
FROM   hive.transactions_db.bronze_transactions
WHERE  booked_date NOT IN (
    SELECT DISTINCT booked_date
    FROM   hive.transactions_db.silver_transactions
)
ORDER  BY booked_date;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 5 — GOLD LAYER                                 ║
-- ║  Pre-aggregated daily totals per transaction type        ║
-- ║  Schema: transaction_type, daily_total, record_count     ║
-- ║          |  partition: booked_date                       ║
-- ╚══════════════════════════════════════════════════════════╝

-- 5.1  Quick sanity — first 20 gold rows
SELECT *
FROM   hive.transactions_db.gold_transactions
ORDER  BY booked_date, transaction_type
LIMIT  20;

-- 5.2  Row count per partition (gold partitions)
SELECT booked_date,
       COUNT(*)                          AS type_count,
       ROUND(SUM(daily_total), 2)        AS total_amount,
       SUM(record_count)                 AS total_records
FROM   hive.transactions_db.gold_transactions
GROUP  BY booked_date
ORDER  BY booked_date;

-- 5.3  Transaction type breakdown at the Gold layer
SELECT transaction_type,
       ROUND(SUM(daily_total), 2)        AS grand_total,
       SUM(record_count)                 AS total_records,
       COUNT(DISTINCT booked_date)        AS days_present
FROM   hive.transactions_db.gold_transactions
GROUP  BY transaction_type
ORDER  BY grand_total DESC;

-- 5.4  Silver-to-Gold validation (delta = 0 means GoldAggregator is correct)
WITH silver_agg AS (
    SELECT booked_date,
           transaction_type,
           ROUND(SUM(amount), 2)         AS computed_total,
           COUNT(*)                      AS computed_count
    FROM   hive.transactions_db.silver_transactions
    WHERE  amount_valid = TRUE
    GROUP  BY booked_date, transaction_type
)
SELECT COALESCE(g.booked_date,       s.booked_date)       AS booked_date,
       COALESCE(g.transaction_type,  s.transaction_type)  AS transaction_type,
       s.computed_total                                    AS silver_total,
       g.daily_total                                       AS gold_total,
       s.computed_count                                    AS silver_count,
       g.record_count                                      AS gold_count,
       ROUND(COALESCE(s.computed_total, 0) - COALESCE(g.daily_total, 0), 4) AS total_delta
FROM   silver_agg s
FULL   OUTER JOIN hive.transactions_db.gold_transactions g
       ON s.booked_date      = g.booked_date
      AND s.transaction_type = g.transaction_type
ORDER  BY booked_date, transaction_type;

-- 5.5  Partition coverage — dates in Silver missing from Gold (incomplete runs)
SELECT DISTINCT booked_date
FROM   hive.transactions_db.silver_transactions
WHERE  booked_date NOT IN (
    SELECT DISTINCT booked_date
    FROM   hive.transactions_db.gold_transactions
)
ORDER  BY booked_date;

-- 5.6  Running cumulative totals from Gold (per transaction type)
SELECT booked_date,
       transaction_type,
       daily_total,
       ROUND(SUM(daily_total) OVER (
           PARTITION BY transaction_type
           ORDER BY booked_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ), 2)                             AS cumulative_total
FROM   hive.transactions_db.gold_transactions
ORDER  BY transaction_type, booked_date;

-- 5.7  Weekly rollup from Gold (aggregate the aggregates)
SELECT DATE_TRUNC('week', booked_date)  AS week_start,
       transaction_type,
       ROUND(SUM(daily_total), 2)       AS weekly_total,
       SUM(record_count)                AS weekly_records
FROM   hive.transactions_db.gold_transactions
GROUP  BY DATE_TRUNC('week', booked_date), transaction_type
ORDER  BY week_start, transaction_type;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 5b — SILVER ANALYTICS (AD-HOC)                 ║
-- ║  On-demand aggregations computed live from Silver        ║
-- ╚══════════════════════════════════════════════════════════╝

-- 5b.1  Re-compute daily totals from Silver (mirrors GoldAggregator logic)
SELECT booked_date,
       transaction_type,
       ROUND(SUM(amount), 2)            AS daily_total,
       COUNT(*)                         AS record_count
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date, transaction_type
ORDER  BY booked_date, transaction_type;

-- 5b.2  Weekly aggregation — net cash flow per transaction type
SELECT DATE_TRUNC('week', booked_date)      AS week_start,
       transaction_type,
       ROUND(SUM(amount), 2)               AS weekly_net,
       COUNT(*)                             AS txn_count
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY DATE_TRUNC('week', booked_date), transaction_type
ORDER  BY week_start, transaction_type;

-- 5b.3  Top-3 largest transactions per day (window function)
SELECT *
FROM (
    SELECT booked_date,
           transaction_id,
           transaction_type,
           amount,
           RANK() OVER (PARTITION BY booked_date ORDER BY ABS(amount) DESC) AS rnk
    FROM   hive.transactions_db.silver_transactions
    WHERE  amount_valid = TRUE
)
WHERE rnk <= 3
ORDER BY booked_date, rnk;

-- 5b.4  Deposit-to-withdrawal ratio per day (liquidity indicator)
SELECT booked_date,
       ROUND(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 2)  AS deposits,
       ROUND(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 2) AS withdrawals,
       ROUND(
         SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)
         / NULLIF(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 0),
       2)                                                           AS deposit_withdrawal_ratio
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;

-- 5b.5  Day-over-day net delta from Silver
SELECT booked_date,
       ROUND(SUM(amount), 2)                                          AS daily_net,
       ROUND(
         SUM(amount)
         - LAG(SUM(amount)) OVER (ORDER BY booked_date),
       2)                                                             AS day_over_day_delta
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;


WHERE rnk <= 3
ORDER BY booked_date, rnk;

-- 5.4  Deposit-to-withdrawal ratio per day (liquidity indicator)
SELECT booked_date,
       ROUND(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 2)  AS deposits,
       ROUND(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 2) AS withdrawals,
       ROUND(
         SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)
         / NULLIF(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 0),
       2)                                                           AS deposit_withdrawal_ratio
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;

-- 5.5  Month-over-month growth (using LAG — works across dates in sample)
SELECT booked_date,
       ROUND(SUM(amount), 2)                                          AS daily_net,
       ROUND(
         SUM(amount)
         - LAG(SUM(amount)) OVER (ORDER BY booked_date),
       2)                                                             AS day_over_day_delta
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 6 — DATA VIRTUALIZATION                        ║
-- ║  Cross-schema federation & Trino-specific features       ║
-- ╚══════════════════════════════════════════════════════════╝

-- 6.1  Unified medallion view — all three layers in one query
--      Shows each transaction's journey: Bronze → Silver → Gold-equivalent
SELECT b.transaction_id,
       b.booked_date,
       b.transaction_type,
       b.amount                                    AS bronze_amount,
       s.amount_valid                              AS silver_valid,
       s.amount                                    AS silver_amount,
       ROUND(SUM(s.amount) OVER (
           PARTITION BY b.booked_date, b.transaction_type
       ), 2)                                       AS daily_type_total
FROM   hive.transactions_db.bronze_transactions b
LEFT   JOIN hive.transactions_db.silver_transactions s
       ON b.transaction_id = s.transaction_id
ORDER  BY b.booked_date, b.transaction_type, b.transaction_id
LIMIT  50;

-- 6.2  Federation: cross-schema validation — Silver recomputed vs Gold stored
--      Moved to Section 5.4 (canonical location). Kept here for reference:
--      delta = 0 means Gold is correct; run 5.4 for the authoritative check.
WITH silver_agg AS (
    SELECT booked_date,
           transaction_type,
           ROUND(SUM(amount), 2)   AS computed_total,
           COUNT(*)                AS computed_count
    FROM   hive.transactions_db.silver_transactions
    WHERE  amount_valid = TRUE
    GROUP  BY booked_date, transaction_type
),
gold AS (
    SELECT booked_date,
           transaction_type,
           daily_total,
           record_count
    FROM   hive.transactions_db.gold_transactions
)
SELECT COALESCE(g.booked_date,      s.booked_date)       AS booked_date,
       COALESCE(g.transaction_type, s.transaction_type)  AS transaction_type,
       s.computed_total                                   AS silver_total,
       g.daily_total                                      AS gold_total,
       s.computed_count                                   AS silver_count,
       g.record_count                                     AS gold_count,
       ROUND(COALESCE(s.computed_total, 0) - COALESCE(g.daily_total, 0), 4) AS total_delta
FROM   silver_agg s
FULL   OUTER JOIN gold g
       ON s.booked_date      = g.booked_date
      AND s.transaction_type = g.transaction_type
ORDER  BY booked_date, transaction_type;

-- 6.3  Virtual "current balance" view using ONLY Trino (no ETL job)
--      Materialises the running net per type from raw Silver in real-time
SELECT transaction_type,
       ROUND(SUM(amount), 2)                  AS lifetime_net,
       COUNT(*)                               AS total_txn_count,
       MIN(booked_date)                       AS first_txn_date,
       MAX(booked_date)                       AS last_txn_date
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY transaction_type
ORDER  BY lifetime_net DESC;

-- 6.4  Time-series pivot: daily amounts per type as columns
--      (Trino does not have native PIVOT, so we use conditional aggregation)
SELECT booked_date,
       ROUND(SUM(CASE WHEN transaction_type = 'deposit'    THEN amount END), 2) AS deposit,
       ROUND(SUM(CASE WHEN transaction_type = 'withdrawal' THEN amount END), 2) AS withdrawal,
       ROUND(SUM(CASE WHEN transaction_type = 'payment'    THEN amount END), 2) AS payment,
       ROUND(SUM(CASE WHEN transaction_type = 'transfer'   THEN amount END), 2) AS transfer,
       ROUND(SUM(CASE WHEN transaction_type = 'fee'        THEN amount END), 2) AS fee,
       ROUND(SUM(amount), 2)                                                    AS total
FROM   hive.transactions_db.silver_transactions
WHERE  amount_valid = TRUE
GROUP  BY booked_date
ORDER  BY booked_date;

-- 6.5  Virtual SLA check — latency from raw to Silver
--      Measures how many days after booked_at a partition appears in Silver
--      (useful when comparing booked_date partition across Bronze/Silver)
SELECT s.booked_date,
       COUNT(s.transaction_id)                              AS silver_row_count,
       COUNT(b.transaction_id)                              AS bronze_row_count,
       ROUND(
         100.0 * COUNT(s.transaction_id) / NULLIF(COUNT(b.transaction_id), 0),
       1)                                                   AS silver_coverage_pct
FROM   hive.transactions_db.bronze_transactions b
LEFT   JOIN hive.transactions_db.silver_transactions s
       ON b.transaction_id = s.transaction_id
      AND b.booked_date    = s.booked_date
GROUP  BY s.booked_date
ORDER  BY s.booked_date;

-- 6.6  Data freshness check — last loaded partition per layer
SELECT 'bronze' AS layer, MAX(booked_date) AS last_partition
FROM   hive.transactions_db.bronze_transactions
UNION ALL
SELECT 'silver', MAX(booked_date)
FROM   hive.transactions_db.silver_transactions
UNION ALL
SELECT 'gold',   MAX(booked_date)
FROM   hive.transactions_db.gold_transactions
ORDER  BY layer;
