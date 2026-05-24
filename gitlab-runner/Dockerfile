FROM gitlab/gitlab-runner:latest

# ── Docker CLI ───────────────────────────────────────────────────────────────
# The daemon runs on the host; we reach it via the mounted /var/run/docker.sock.
# Lets the shell executor run `docker cp` / `docker exec` against YARN containers.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
     > /etc/apt/sources.list.d/docker.list \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends docker-ce-cli \
 && rm -rf /var/lib/apt/lists/*

# ── Java 11 + SBT ────────────────────────────────────────────────────────────
# Shell executor ignores `image:` — tools must be baked into this image.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends openjdk-11-jdk-headless \
 && echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" \
      > /etc/apt/sources.list.d/sbt.list \
 && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" \
      | apt-key add - \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends sbt \
 && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# -- Docker socket GID fix ----------------------------------------------------
# At container startup, detect the host docker socket GID and add gitlab-runner
# to that group. Portable across hosts regardless of their docker GID.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
