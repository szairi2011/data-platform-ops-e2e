FROM apache/hive:4.0.0

# Add PostgreSQL JDBC driver (required for HMS backing store)
USER root
RUN curl -fsSL \
    https://jdbc.postgresql.org/download/postgresql-42.7.3.jar \
    -o /opt/hive/lib/postgresql-42.7.3.jar
USER hive
