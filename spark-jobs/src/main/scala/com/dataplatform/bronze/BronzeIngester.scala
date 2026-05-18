package com.dataplatform.bronze

import com.dataplatform.common.{AppConfig, SparkSessionFactory}
import org.apache.spark.sql.{DataFrame, SaveMode, SparkSession}
import org.apache.spark.sql.functions.{col, to_date}
import org.apache.spark.sql.types._

object BronzeIngester {

  /** Input schema for raw CSV files. */
  val rawSchema: StructType = StructType(Seq(
    StructField("id",         StringType,    nullable = false),
    StructField("event_time", TimestampType, nullable = true),
    StructField("value",      DoubleType,    nullable = true),
    StructField("category",   StringType,    nullable = true),
  ))

  /** Read raw CSVs with PERMISSIVE mode; split into good / bad records. */
  def readRaw(spark: SparkSession, inputPath: String): (DataFrame, DataFrame) = {
    val schemaWithCorrupt = rawSchema.add("_corrupt_record", StringType)

    val raw = spark.read
      .option("mode", "PERMISSIVE")
      .option("columnNameOfCorruptRecord", "_corrupt_record")
      .schema(schemaWithCorrupt)
      .csv(inputPath)

    val good = raw.filter(col("_corrupt_record").isNull).drop("_corrupt_record")
    val bad  = raw.filter(col("_corrupt_record").isNotNull)
    (good, bad)
  }

  /** Write Bronze Parquet (partitioned by ingest_date) + dead-letter for bad rows. */
  def run(spark: SparkSession, inputPath: String, bronzePath: String, deadLetterPath: String): Unit = {
    val (good, bad) = readRaw(spark, inputPath)

    if (!bad.isEmpty) {
      bad.write
        .mode(SaveMode.Append)
        .parquet(deadLetterPath)
    }

    // Partition overwrite = idempotent re-runs for the same date
    spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
    good
      .withColumn("ingest_date", to_date(col("event_time")))
      .write
      .mode(SaveMode.Overwrite)
      .partitionBy("ingest_date")
      .parquet(bronzePath)
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionFactory.getOrCreate("BronzeIngester")
    run(spark, AppConfig.Paths.raw, AppConfig.Paths.bronze, AppConfig.Paths.deadLetter)
    spark.stop()
  }
}
