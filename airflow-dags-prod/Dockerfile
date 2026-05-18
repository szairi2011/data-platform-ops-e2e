FROM apache/airflow:3.2.1-python3.10

USER root

# Install Hadoop client + spark-submit prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Hadoop 3.3.6 (client only — for yarn-site.xml + hadoop classpath)
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/conf
ENV PATH="${HADOOP_HOME}/bin:${PATH}"
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

RUN wget -q "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    && tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ \
    && mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} \
    && rm hadoop-${HADOOP_VERSION}.tar.gz \
    && mkdir -p ${HADOOP_CONF_DIR}

# Install Spark 3.5.3 (needed for spark-submit binary on the worker)
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${PATH}"

COPY --from=apache/spark:3.5.3 /opt/spark ${SPARK_HOME}

USER airflow

COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
