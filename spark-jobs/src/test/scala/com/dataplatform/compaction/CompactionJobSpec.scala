package com.dataplatform.compaction

import org.apache.spark.sql.SparkSession
import org.scalatest.BeforeAndAfterAll
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import java.nio.file.Files

class CompactionJobSpec extends AnyFlatSpec with Matchers with BeforeAndAfterAll {

  private var spark: SparkSession = _
  private val tmpDir = Files.createTempDirectory("compaction-spec").toAbsolutePath.toString

  override def beforeAll(): Unit = {
    spark = SparkSession.builder()
      .master("local[2]")
      .appName("CompactionJobSpec")
      .config("spark.sql.shuffle.partitions", "2")
      .config("spark.ui.enabled", "false")
      .config("spark.driver.host", "127.0.0.1")
      .config("spark.driver.bindAddress", "127.0.0.1")
      .getOrCreate()
  }

  override def afterAll(): Unit = ()

  private def writeFragmentedParquet(path: String, numPartitions: Int): Unit = {
    val ss = spark
    import ss.implicits._
    (1 to 100).toDF("id")
      .repartition(numPartitions)
      .write.mode("overwrite").parquet(path)
  }

  behavior of "CompactionJob.compact"

  it should "reduce partition count via coalesce when targetFiles < current" in {
    val path = s"$tmpDir/coalesce_test"
    writeFragmentedParquet(path, numPartitions = 20)

    CompactionJob.compact(spark, path, targetFiles = 4)

    val result = spark.read.parquet(path)
    result.rdd.getNumPartitions should be <= 4
    result.count() shouldBe 100
  }

  it should "preserve all rows after compaction" in {
    val path = s"$tmpDir/rowcount_test"
    writeFragmentedParquet(path, numPartitions = 10)

    CompactionJob.compact(spark, path, targetFiles = 2)

    spark.read.parquet(path).count() shouldBe 100
  }
}
