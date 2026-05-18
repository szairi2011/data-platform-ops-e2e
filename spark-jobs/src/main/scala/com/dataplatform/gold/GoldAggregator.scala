package com.dataplatform.gold

import com.dataplatform.common.{AppConfig, SparkSessionFactory}
import org.apache.spark.sql.{DataFrame, SaveMode, SparkSession}
import org.apache.spark.sql.functions.{col, sum, count}

object GoldAggregator {

  /** Aggregate Silver data into daily totals per entity. */
  def aggregate(silver: DataFrame): DataFrame =
    silver
      .groupBy("event_date", "category")
      .agg(
        sum("value").as("daily_total"),
        count("id").as("record_count"),
      )

  /** Write aggregated DataFrame to Parquet (test-safe, no Hive dependency). */
  def writeTo(df: DataFrame, outputPath: String, database: String, table: String): Unit = {
    df.write
      .mode(SaveMode.Overwrite)
      .partitionBy("event_date")
      .parquet(outputPath)
  }

  /** Create Hive external table DDL if not exists (cluster-only path). */
  def ensureHiveTable(spark: SparkSession, database: String, table: String, goldPath: String): Unit = {
    spark.sql(s"CREATE DATABASE IF NOT EXISTS $database")
    spark.sql(
      s"""CREATE TABLE IF NOT EXISTS $database.$table (
         |  category     STRING,
         |  daily_total  DOUBLE,
         |  record_count BIGINT
         |)
         |PARTITIONED BY (event_date DATE)
         |STORED AS PARQUET
         |LOCATION '$goldPath'
         |""".stripMargin
    )
  }

  def run(spark: SparkSession, silverPath: String, goldPath: String,
          database: String, table: String): Unit = {
    val silver    = spark.read.parquet(silverPath)
    val goldDf    = aggregate(silver)
    writeTo(goldDf, goldPath, database, table)
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionFactory.getOrCreate("GoldAggregator")
    run(spark, AppConfig.Paths.silver, AppConfig.Paths.gold, AppConfig.Hive.database, AppConfig.Hive.goldTable)
    spark.stop()
  }
}
