"""Production WSGI server; override settings with GUNICORN_CMD_ARGS."""

import json
import os

from lil_request_logging.gunicorn import AccessLogger

bind = "0.0.0.0:8000"
# Threads allow cloudflared to reuse HTTP connections and let exports wait on
# Lambda without occupying an entire process. No greenlet monkey-patching.
worker_class = "gthread"
workers = int(os.environ.get("WEB_CONCURRENCY", "4"))
threads = 2
keepalive = 5

# This detects unresponsive workers, not individual long-running exports.
timeout = 60
# ECS gives the app 30 seconds after SIGTERM; leave time for process cleanup.
# The cloudflared sidecar drains requests before ECS stops the app.
graceful_timeout = 25
worker_tmp_dir = "/dev/shm"

accesslog = "-"
errorlog = "-"
capture_output = True


# The only ingress is cloudflared over loopback; the task has no inbound SG rules.
class TunnelAccessLogger(AccessLogger):
    trusted_peers = ("127.0.0.1", "::1")


logger_class = TunnelAccessLogger
# Match Sentry's tier and build identifier without initializing Django here.
raw_env = [
    "SERVICE_NAME=h2o",
    f"ENVIRONMENT={json.loads(os.environ.get('APP_CONFIG', '{}')).get('TIER', 'dev')}",
    f"SENTRY_RELEASE={os.environ.get('H2O_RELEASE', '')}",
]
# ECS owns process lifecycle; no separate administrative socket is needed.
control_socket_disable = True
# No upstream component needs to override WSGI routing via HTTP headers.
forwarder_headers = ""
