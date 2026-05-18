"""
compaction.py — Weekly compaction DAG
Runs CompactionJob for bronze, silver, and gold layers sequentially.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow.decorators import dag
from airflow.models import Variable
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

DEFAULT_ARGS = {
    "owner": "data-platform",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

JAR_HDFS_PATH = Variable.get("JAR_HDFS_PATH", default_var="hdfs:///jars/spark-jobs-assembly.jar")
PIPELINE_ENV = Variable.get("PIPELINE_ENV", default_var="dev")


def _compaction_task(layer: str) -> SparkSubmitOperator:
    return SparkSubmitOperator(
        task_id=f"compaction_{layer}",
        conn_id="spark_yarn",
        application=JAR_HDFS_PATH,
        java_class="com.dataplatform.compaction.CompactionJob",
        name=f"compaction_{layer}_{PIPELINE_ENV}",
        deploy_mode="cluster",
        conf={
            "spark.dataplatform.compaction.layer": layer,
            "spark.dataplatform.compaction.targetFiles": "4",
            "spark.yarn.submit.waitAppCompletion": "true",
            "spark.hadoop.fs.defaultFS": "hdfs://namenode:9000",
        },
        verbose=False,
    )


@dag(
    dag_id="compaction",
    description="Weekly compaction of bronze, silver, and gold layers",
    start_date=datetime(2026, 1, 1),
    schedule="@weekly",
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["compaction", "spark", "yarn"],
)
def compaction():
    compaction_bronze = _compaction_task("bronze")
    compaction_silver = _compaction_task("silver")
    compaction_gold = _compaction_task("gold")

    compaction_bronze >> compaction_silver >> compaction_gold


compaction()
