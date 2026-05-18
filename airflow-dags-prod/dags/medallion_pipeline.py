"""
medallion_pipeline.py — Medallion Pipeline DAG
Runs: Bronze → Silver → Gold
Great Expectations validation gates after Silver and Gold.
JAR path read from Airflow Variable `JAR_HDFS_PATH`.
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
SILVER_WATERMARK = Variable.get("SILVER_WATERMARK", default_var="1970-01-01")


def _spark_submit(
    task_id: str,
    main_class: str,
    extra_conf: dict | None = None,
) -> SparkSubmitOperator:
    conf = {
        "spark.yarn.submit.waitAppCompletion": "true",
        "spark.hadoop.fs.defaultFS": "hdfs://namenode:9000",
    }
    if extra_conf:
        conf.update(extra_conf)

    return SparkSubmitOperator(
        task_id=task_id,
        conn_id="spark_yarn",
        application=JAR_HDFS_PATH,
        java_class=main_class,
        name=f"{task_id}_{PIPELINE_ENV}",
        deploy_mode="cluster",
        conf=conf,
        verbose=False,
    )


@dag(
    dag_id="medallion_pipeline",
    description="Bronze → Silver → Gold medallion pipeline",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["medallion", "spark", "yarn"],
)
def medallion_pipeline():
    bronze_ingest = _spark_submit(
        task_id="bronze_ingest",
        main_class="com.dataplatform.bronze.BronzeIngester",
    )

    silver_transform = _spark_submit(
        task_id="silver_transform",
        main_class="com.dataplatform.silver.SilverTransformer",
        extra_conf={f"spark.dataplatform.silver.watermark": SILVER_WATERMARK},
    )

    gold_aggregate = _spark_submit(
        task_id="gold_aggregate",
        main_class="com.dataplatform.gold.GoldAggregator",
    )

    bronze_ingest >> silver_transform >> gold_aggregate


medallion_pipeline()
