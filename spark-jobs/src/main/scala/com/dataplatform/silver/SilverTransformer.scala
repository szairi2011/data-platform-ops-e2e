package com.dataplatform.silver

import com.dataplatform.common.{AppConfig, SparkSessionFactory}
import org.apache.spark.sql.{DataFrame, SaveMode, SparkSession}
import org.apache.spark.sql.functions.{broadcast, col, to_date}

object SilverTransformer {

  /** Read only bronze partitions newer than watermark (partition pruning). */
  def readIncremental(spark: SparkSession, bronzePath: String, watermark: String): DataFrame =
    spark.read
      .parquet(bronzePath)
      .filter(col("ingest_date") > watermark)

  /** Enrich with a small dimension table via broadcast join. */
  def enrich(fact: DataFrame, dim: DataFrame): DataFrame =
    fact.join(broadcast(dim), Seq("category"), "left")

  /** Full Silver transform: incremental read → broadcast join → write partitioned Parquet. */
  def run(spark: SparkSession,
          bronzePath: String,
          silverPath: String,
          dimPath: String,
          watermark: String): Unit = {

    val bronze = readIncremental(spark, bronzePath, watermark)

    val silver =
      if (dimPath.nonEmpty && spark.catalog.tableExists(dimPath)) {
        val dim = spark.read.parquet(dimPath)
        enrich(bronze, dim)
      } else {
        bronze
      }

    spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
    silver
      .withColumn("event_date", to_date(col("event_time")))
      .write
      .mode(SaveMode.Overwrite)
      .partitionBy("event_date")
      .parquet(silverPath)
  }

  def main(args: Array[String]): Unit = {
    val spark     = SparkSessionFactory.getOrCreate("SilverTransformer")
    val watermark = spark.conf.getOption(AppConfig.Silver.watermarkConfKey)
                          .getOrElse(AppConfig.Silver.defaultWatermark)
    run(spark, AppConfig.Paths.bronze, AppConfig.Paths.silver, dimPath = "", watermark)
    spark.stop()
  }
}
