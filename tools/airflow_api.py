"""Thin helper for Airflow 3 REST API — handles JWT auth automatically."""
import urllib.request, urllib.parse, json, sys

BASE = "http://localhost:8080"

def get_token(user="admin", password="admin"):
    body = json.dumps({"username": user, "password": password}).encode()
    req = urllib.request.Request(f"{BASE}/auth/token", data=body,
                                  headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req) as r:
        return json.load(r)["access_token"]

def api(method, path, payload=None, token=None):
    if token is None:
        token = get_token()
    body = json.dumps(payload).encode() if payload else None
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    req = urllib.request.Request(f"{BASE}/api/v2{path}", data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()}

cmd = sys.argv[1] if len(sys.argv) > 1 else "dags"

TOKEN = get_token()

if cmd == "dags":
    dags = api("GET", "/dags", token=TOKEN)["dags"]
    print(f"{'DAG ID':<40} {'PAUSED'}")
    print("-" * 50)
    for d in dags:
        print(f"{d['dag_id']:<40} {d['is_paused']}")

elif cmd == "unpause":
    dag_id = sys.argv[2]
    r = api("PATCH", f"/dags/{dag_id}", {"is_paused": False}, token=TOKEN)
    print(f"Unpaused {dag_id}:", r.get("is_paused", r))

elif cmd == "pause":
    dag_id = sys.argv[2]
    r = api("PATCH", f"/dags/{dag_id}", {"is_paused": True}, token=TOKEN)
    print(f"Paused {dag_id}:", r.get("is_paused", r))

elif cmd == "runs":
    dag_id = sys.argv[2]
    r = api("GET", f"/dags/{dag_id}/dagRuns?order_by=-start_date&limit=5", token=TOKEN)
    runs = r.get("dag_runs", [])
    if not runs:
        print("No runs yet.")
    for run in runs:
        rid = run.get("run_id") or run.get("dag_run_id", "?")
        print(f"  {rid:<55} state={run['state']}")

elif cmd == "vars":
    r = api("GET", "/variables", token=TOKEN)
    vars_ = r.get("variables", [])
    if not vars_:
        print("No variables set.")
    for v in vars_:
        print(f"  {v['key']:<40} = {v['value']}")

elif cmd == "trigger":
    dag_id = sys.argv[2]
    conf = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
    r = api("POST", f"/dags/{dag_id}/dagRuns", {"conf": conf}, token=TOKEN)
    print(f"Triggered {dag_id}:", r.get("run_id", r))
