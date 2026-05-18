package com.dataplatform.gold

import org.apache.spark.sql.SparkSession
import org.scalatest.BeforeAndAfterAll
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import java.nio.file.Files

class GoldAggregatorSpec extends AnyFlatSpec with Matchers with BeforeAndAfterAll {

  private var spark: SparkSession = _
  private val tmpDir = Files.createTempDirectory("gold-spec").toAbsolutePath.toString

  override def beforeAll(): Unit = {
    spark = SparkSession.builder()
      .master("local[2]")
      .appName("GoldAggregatorSpec")
      .config("spark.sql.shuffle.partitions", "2")
      .config("spark.ui.enabled", "false")
      .config("spark.driver.host", "127.0.0.1")
      .config("spark.driver.bindAddress", "127.0.0.1")
      .getOrCreate()
  }

  override def afterAll(): Unit = ()

  private def makeSilverParquet(path: String): Unit = {
    val ss = spark
    import ss.implicits._
    Seq(
      ("id1", 42.5,  "A", "2026-01-01"),
      ("id2", 99.0,  "A", "2026-01-01"),
      ("id3", 10.0,  "B", "2026-01-02"),
    ).toDF("id", "value", "category", "event_date")
      .write.mode("overwrite").partitionBy("event_date").parquet(path)
  }

  behavior of "GoldAggregator.aggregate"

  it should "sum values and count records per (event_date, category)" in {
    val silverPath = s"$tmpDir/silver_agg"
    makeSilverParquet(silverPath)

    val silver = spark.read.parquet(silverPath)
    val gold   = GoldAggregator.aggregate(silver)

    gold.count() shouldBe 2  // (2026-01-01,A) and (2026-01-02,B)

    val row = gold.filter("category = 'A' AND event_date = '2026-01-01'").first()
    row.getAs[Double]("daily_total")  shouldBe 141.5 +- 0.01
    row.getAs[Long]("record_count")   shouldBe 2L
  }

  it should "write output partitioned by event_date" in {
    val silverPath = s"$tmpDir/silver_write"
    val goldPath   = s"$tmpDir/gold_write"
    makeSilverParquet(silverPath)

    GoldAggregator.run(spark, silverPath, goldPath, database = "test_db", table = "test_table")

    val result = spark.read.parquet(goldPath)
    result.count() should be > 0L
    result.columns should contain("daily_total")
  }
}
