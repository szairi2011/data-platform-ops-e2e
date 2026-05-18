package com.dataplatform.silver

import com.dataplatform.bronze.BronzeIngester
import org.apache.spark.sql.SparkSession
import org.scalatest.BeforeAndAfterAll
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import java.nio.file.Files

class SilverTransformerSpec extends AnyFlatSpec with Matchers with BeforeAndAfterAll {

  private var spark: SparkSession = _
  private val tmpDir = Files.createTempDirectory("silver-spec").toAbsolutePath.toString

  override def beforeAll(): Unit = {
    spark = SparkSession.builder()
      .master("local[2]")
      .appName("SilverTransformerSpec")
      .config("spark.sql.shuffle.partitions", "2")
      .config("spark.ui.enabled", "false")
      .config("spark.driver.host", "127.0.0.1")
      .config("spark.driver.bindAddress", "127.0.0.1")
      .getOrCreate()
  }

  override def afterAll(): Unit = ()

  private def makeBronzeParquet(path: String): Unit = {
    val ss = spark
    import ss.implicits._
    Seq(
      ("id1", "2026-01-01 10:00:00", 42.5, "A", "2026-01-01"),
      ("id2", "2026-01-02 11:00:00", 99.0, "B", "2026-01-02"),
      ("id3", "2026-01-03 09:00:00", 10.0, "A", "2026-01-03"),
    ).toDF("id", "event_time", "value", "category", "ingest_date")
      .write.mode("overwrite").partitionBy("ingest_date").parquet(path)
  }

  behavior of "SilverTransformer"

  it should "read only partitions newer than watermark" in {
    val bronze = s"$tmpDir/bronze_incr"
    val silver = s"$tmpDir/silver_incr"
    makeBronzeParquet(bronze)

    SilverTransformer.run(spark, bronze, silver, dimPath = "", watermark = "2026-01-01")

    // 2026-01-01 partition is excluded (not strictly greater)
    val result = spark.read.parquet(silver)
    result.count() shouldBe 2
  }

  it should "return all rows when watermark is before all data" in {
    val bronze = s"$tmpDir/bronze_all"
    val silver = s"$tmpDir/silver_all"
    makeBronzeParquet(bronze)

    SilverTransformer.run(spark, bronze, silver, dimPath = "", watermark = "1970-01-01")

    spark.read.parquet(silver).count() shouldBe 3
  }

  it should "add event_date column to output" in {
    val bronze = s"$tmpDir/bronze_col"
    val silver = s"$tmpDir/silver_col"
    makeBronzeParquet(bronze)

    SilverTransformer.run(spark, bronze, silver, dimPath = "", watermark = "1970-01-01")

    spark.read.parquet(silver).columns should contain("event_date")
  }
}
