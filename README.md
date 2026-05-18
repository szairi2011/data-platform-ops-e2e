# data-platform-ops-e2e

End-to-end data platform: YARN cluster, Spark jobs (Medallion pipeline), Airflow orchestration, and data governance (OpenMetadata + OpenLineage).

## Stack

| Submodule | Purpose |
|-----------|---------|
| `yarn-cluster/` | Hadoop 3.3.6 + Spark 3.5.3 + Hive Metastore + Livy + JupyterHub |
| `spark-jobs/` | Scala Spark jobs (Bronze → Silver → Gold → Compaction) |
| `airflow-dags/` | Airflow 2.9 DAGs + SparkSubmitOperator |
| `data-governance/` | OpenMetadata + OpenLineage + Great Expectations |

## Quick Start

```bash
# First-time clone
./bootstrap.sh

# Start stacks
./ops.sh start yarn
./ops.sh start airflow
./ops.sh start governance
./ops.sh start all

# Build & deploy Spark JARs (local)
./ops.sh build spark-jobs
```

## Architecture

- Each submodule is independently deployable with its own `docker-compose.yml`
- Root `docker-compose.yml` orchestrates all stacks via `include:`
- CI/CD (GitHub Actions in `spark-jobs`) handles JAR build → HDFS upload → Airflow Variable update
- Airflow triggers jobs via `SparkSubmitOperator` (YARN cluster mode)
- OpenLineage events are emitted from each Spark job to OpenMetadata
