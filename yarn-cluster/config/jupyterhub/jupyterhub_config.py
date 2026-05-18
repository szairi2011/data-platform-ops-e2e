import os
from dockerspawner import DockerSpawner
from jupyterhub.auth import DummyAuthenticator

c = get_config()  # noqa: F821  (injected by JupyterHub at runtime)

# ── Authenticator ──────────────────────────────────────────────────────────
c.JupyterHub.authenticator_class = DummyAuthenticator
c.DummyAuthenticator.password = "jupyter"

# ── Spawner ────────────────────────────────────────────────────────────────
c.JupyterHub.spawner_class = DockerSpawner

# Singleuser image with sparkmagic pre-installed
c.DockerSpawner.image = "yarn-cluster-singleuser:latest"

# Join the same Docker network as the YARN cluster
c.DockerSpawner.network_name = os.environ.get("DOCKER_NETWORK_NAME", "spark-net")
c.DockerSpawner.use_internal_ip = True
c.DockerSpawner.remove = True

# Mount a persistent volume per user
c.DockerSpawner.volumes = {
    "jupyterhub-user-{username}": "/home/jovyan/work"
}

# ── Hub networking ─────────────────────────────────────────────────────────
# HUB_IP must be the container name so singleuser containers can reach it
c.JupyterHub.hub_ip = "0.0.0.0"
c.JupyterHub.hub_connect_ip = os.environ.get("HUB_IP", "jupyterhub")

# ── SparkMagic config path inside singleuser container ────────────────────
c.DockerSpawner.environment = {
    "SPARKMAGIC_CONF_DIR": "/home/jovyan/.sparkmagic",
}
