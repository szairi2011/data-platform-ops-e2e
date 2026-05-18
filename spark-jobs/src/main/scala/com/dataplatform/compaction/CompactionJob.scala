package com.dataplatform.compaction

import com.dataplatform.common.{AppConfig, SparkSessionFactory}
import org.apache.spark.sql.{SaveMode, SparkSession}

object CompactionJob {

  /** Compact a Parquet layer to `targetFiles` output files.
   *  Uses coalesce (no shuffle) when reducing, repartition when increasing. */
  def compact(spark: SparkSession, path: String, targetFiles: Int): Unit = {
    val df       = spark.read.parquet(path)
    val current  = df.rdd.getNumPartitions

    val compacted =
      if (current > targetFiles) df.coalesce(targetFiles)
      else                       df.repartition(targetFiles)

    // Write to a temp path then replace (atomic swap)
    val tmpPath = path + "._compaction_tmp"
    compacted.write
      .mode(SaveMode.Overwrite)
      .parquet(tmpPath)

    // Overwrite original: read tmp, write back to original path
    spark.read.parquet(tmpPath).write
      .mode(SaveMode.Overwrite)
      .parquet(path)
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionFactory.getOrCreate("CompactionJob")

    // Layer and target-files can be overridden at submission via --conf
    val layer = spark.conf.getOption("spark.dataplatform.compaction.layer")
                    .getOrElse(AppConfig.Compaction.layer)
    val targetFiles = spark.conf.getOption("spark.dataplatform.compaction.targetFiles")
                          .map(_.toInt)
                          .getOrElse(AppConfig.Compaction.targetFiles)

    val path = layer match {
      case "bronze" => AppConfig.Paths.bronze
      case "silver" => AppConfig.Paths.silver
      case "gold"   => AppConfig.Paths.gold
      case other    => throw new IllegalArgumentException(s"Unknown layer: $other")
    }

    compact(spark, path, targetFiles)
    spark.stop()
  }
}
