FROM eclipse-temurin:11-jre-jammy

ARG HADOOP_VERSION=3.3.6
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget ssh rsync procps netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa \
    && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys \
    && chmod 0600 /root/.ssh/authorized_keys

RUN curl -fsSL \
    https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    | tar -xz -C /opt/ \
    && mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} \
    && echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh \
    && echo "export HADOOP_HOME=${HADOOP_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

COPY docker/hadoop/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${HADOOP_HOME}
ENTRYPOINT ["/entrypoint.sh"]
