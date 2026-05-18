package com.dataplatform.common

import org.apache.spark.sql.SparkSession

object SparkSessionFactory {

  /** Returns the existing SparkSession or creates one configured for YARN.
   *  Tests override this by creating a local session BEFORE calling any job's main(). */
  def getOrCreate(appName: String): SparkSession =
    SparkSession.builder()
      .appName(appName)
      .enableHiveSupport()
      .getOrCreate()
}
