-- Silver records
-- SELECT *
-- FROM read_parquet('C:/Users/sofiane/work/data-platform-ops-e2e/silver-transactions/**/*.parquet', hive_partitioning=true)
-- LIMIT 20;

SELECT b.transaction_type as trans_type, count(*) as total_transactions
FROM read_parquet('bronze-transactions/**/*.parquet', hive_partitioning=true) b
JOIN read_parquet('silver-transactions/**/*.parquet', hive_partitioning=true) s
  ON b.transaction_id = s.transaction_id
-- WHERE b.amount_valid = true;
-- where b.transaction_type = 'deposit';
GROUP BY b.transaction_type
-- where b.transaction_type = 'deposit'

-- Bronze records
-- SELECT *
-- FROM read_parquet('C:/Users/sofiane/work/data-platform-ops-e2e/bronze-transactions/**/*.parquet', hive_partitioning=true)
-- LIMIT 20;