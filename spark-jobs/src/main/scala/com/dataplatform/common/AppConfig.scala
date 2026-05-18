package com.dataplatform.common

import com.typesafe.config.{Config, ConfigFactory}

object AppConfig {

  private val conf: Config = ConfigFactory.load()

  object Paths {
    val raw: String        = conf.getString("app.paths.raw")
    val bronze: String     = conf.getString("app.paths.bronze")
    val silver: String     = conf.getString("app.paths.silver")
    val gold: String       = conf.getString("app.paths.gold")
    val deadLetter: String = conf.getString("app.paths.dead-letter")
    val jars: String       = conf.getString("app.paths.jars")
  }

  object Hive {
    val database: String  = conf.getString("app.hive.database")
    val goldTable: String = conf.getString("app.hive.gold-table")
  }

  object Silver {
    val watermarkConfKey: String  = conf.getString("app.silver.watermark-conf-key")
    val defaultWatermark: String  = conf.getString("app.silver.default-watermark")
  }

  object Compaction {
    val layer: String    = conf.getString("app.compaction.layer")
    val targetFiles: Int = conf.getInt("app.compaction.target-files")
  }
}
