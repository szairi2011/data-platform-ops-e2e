FROM yarn-cluster-hadoop:latest

ENV SPARK_HOME=/opt/spark
ENV PYSPARK_PYTHON=/usr/bin/python3.10
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV YARN_CONF_DIR=/opt/hadoop/etc/hadoop
ENV PATH=$PATH:${SPARK_HOME}/bin

# Python 3.10 (available on Ubuntu 22.04 Jammy)
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3.10-dev python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python

# Copy Spark binaries from official image (same version as cluster)
COPY --from=apache/spark:3.5.3 /opt/spark ${SPARK_HOME}

# Livy
ARG LIVY_VERSION=0.9.0-incubating
ENV LIVY_HOME=/opt/livy

RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL \
    https://archive.apache.org/dist/incubator/livy/${LIVY_VERSION}/apache-livy-${LIVY_VERSION}_2.12-bin.zip \
    -o /tmp/livy.zip \
    && unzip /tmp/livy.zip -d /opt/ \
    && mv /opt/apache-livy-${LIVY_VERSION}_2.12-bin ${LIVY_HOME} \
    && rm /tmp/livy.zip

ENV PATH=$PATH:${LIVY_HOME}/bin

EXPOSE 8998
CMD ["/opt/livy/bin/livy-server"]
