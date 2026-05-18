FROM yarn-cluster-hadoop:latest

ENV SPARK_HOME=/opt/spark
ENV PYSPARK_PYTHON=/usr/bin/python3.10
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV PATH=$PATH:${SPARK_HOME}/bin

# Python 3.10 — must match Livy driver Python version
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3.10-dev python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python

# Copy Spark binaries from official image
COPY --from=apache/spark:3.5.3 /opt/spark ${SPARK_HOME}

CMD ["yarn", "nodemanager"]
