# data-platform-ops-e2e — Umbrella Spec (SDD)

## Purpose

This is the **Spec-Driven Development (SDD)** instruction file for the umbrella repo.
Copilot must read this before making any changes to the root workspace.

---

## Repo Layout

```
data-platform-ops-e2e/
├── bootstrap.sh              ← First-time setup: clone submodules + verify tooling
├── ops.sh                    ← Operator CLI: start/stop/build individual stacks
├── docker-compose.yml        ← Thin orchestrator (compose include: pattern)
├── .gitmodules               ← Submodule registry
├── .github/
│   └── copilot-instructions.md  ← This file
│
├── yarn-cluster/             ← Submodule: szairi2011/yarn-cluster
├── spark-jobs/               ← Submodule: szairi2011/spark-jobs
├── airflow-dags-prod/        ← Submodule: szairi2011/airflow-dags-prod
└── data-governance/          ← Submodule: szairi2011/data-governance
```

---

## Version Matrix (pinned — do not deviate)

| Component | Version | Notes |
|-----------|---------|-------|
| Java | eclipse-temurin:11-jre-jammy | Base for Hadoop + Livy |
| Hadoop | 3.3.6 | |
| Spark | 3.5.3 (apache/spark:3.5.3) | Scala 2.12 build |
| Python | 3.10 | Must match across Livy driver + NodeManager workers |
| Livy | 0.9.0-incubating | apache-livy-0.9.0-incubating_2.12-bin.zip |
| Hive Metastore | apache/hive:4.0.0 | JRE 17 + PostgreSQL JDBC 42.7.3 |
| PostgreSQL | 16-alpine | HMS backing store |
| JupyterHub | quay.io/jupyterhub/jupyterhub:4.1.6 | |
| Singleuser | quay.io/jupyter/pyspark-notebook:spark-3.5.3 | + sparkmagic 0.23.0 |
| Scala | 2.12.x | Must match Spark 3.5.3 binary |
| Airflow | 3.2.1 | Python 3.10, apache-airflow-providers-apache-spark |
| OpenMetadata | docker.getcollate.io/openmetadata/server:latest | Self-contained stack |

---

## Submodule Responsibilities

### yarn-cluster
- Source: `szairi2011/yarn-cluster` (new standalone repo)
- Image versions match `learn-jupyterhub-with-livy` — same version matrix, new compose from scratch
- Provides: Hadoop YARN, Spark, Hive Metastore, Livy, JupyterHub
- Own compose file: `yarn-cluster/docker-compose.yml`
- Network: `spark-net`

### spark-jobs
- Scala SBT project, 4 Medallion jobs:
  1. `BronzeIngester` — Raw → Bronze Parquet (schema enforcement, dead-letter, idempotency)
  2. `SilverTransformer` — Bronze → Silver (incremental, broadcast joins, partition pruning)
  3. `GoldAggregator` — Silver → Gold Hive (Hive DDL writes, atomic writes, output partitioning)
  4. `CompactionJob` — Housekeeping (small files, coalesce vs repartition)
- Cross-cutting: ScalaTest unit tests (no cluster), Typesafe Config, single SparkSession
- CI/CD: GitHub Actions two-job workflow:
  - Job 1 (`ubuntu-latest`): sbt test → sbt assembly → upload JAR as Actions artifact
  - Job 2 (`self-hosted`, same machine as Docker cluster): download artifact → docker cp → hdfs dfs -put → update Airflow Variables
- Airflow Variables set by CI/CD: `JAR_HDFS_PATH` (fixed HDFS path), `JAR_VERSION` (git SHA)

### airflow-dags-prod
- Airflow 3.2.1 + SparkSubmitOperator (YARN cluster mode)
- DAGs are environment-aware (dev/staging/prod) via Airflow Variables/Connections
- Does NOT trigger CI/CD — CI/CD triggers are code-push only
- JAR path read from Airflow Variable `JAR_HDFS_PATH` (set by spark-jobs CI/CD)

### data-governance
- OpenMetadata (self-contained Docker stack)
- OpenLineage events from Spark jobs → OpenMetadata's OpenLineage endpoint
- Great Expectations suites validate Silver + Gold outputs as Airflow tasks
- Hive Metastore as schema catalog (already in yarn-cluster stack)

---

## ops.sh Contract

```
ops.sh start yarn        # starts yarn-cluster stack only
ops.sh start airflow     # starts airflow stack only
ops.sh start governance  # starts OpenMetadata stack only
ops.sh start all         # starts everything

ops.sh stop yarn|airflow|governance|all

ops.sh build spark-jobs  # local: sbt assembly + upload JAR to HDFS
```

Each `start` command calls the submodule's own compose directly.
Granular control = memory usage management (laptop-safe).

---

## CI/CD vs Airflow Separation

```
CODE PUSH → GitHub Actions (spark-jobs):
  sbt test → sbt assembly → upload JAR to HDFS → set Airflow Variable JAR_VERSION

SCHEDULE/EVENT → Airflow:
  SparkSubmitOperator → YARN cluster mode → reads JAR_VERSION Variable
```

Airflow does NOT trigger CI/CD. CI/CD does NOT call Airflow DAGs directly.

---

## Spark Deploy Mode (YARN cluster)

- Driver runs on NodeManager (not Airflow worker)
- JAR must be on HDFS before submission
- Airflow worker needs: yarn-site.xml, core-site.xml, spark-submit binary
- SparkSubmitOperator polls YARN REST API for terminal state

---

## SDD Rules for Copilot

1. **No code without a spec**: Each submodule has its own `.instructions.md` that drives implementation.
2. **Read the submodule spec first** before editing any file in that submodule.
3. **Version matrix is frozen**: Do not suggest version upgrades without explicit user request.
4. **Submodule independence**: Each submodule must be runnable standalone (`docker compose up` in its directory).
5. **No cross-submodule imports**: Submodules communicate via shared HDFS paths, Airflow Variables, and network addresses only.
6. **ops.sh is the single operator entry point**: Do not add new top-level scripts for stack operations.
