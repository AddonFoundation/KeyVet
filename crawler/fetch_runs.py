
import requests, time, json, argparse

BASE = "https://raider.io/api/v1"

def get(session, path, **params):
    while True:
        r = session.get(f"{BASE}{path}", params=params)
        if r.status_code == 429:
            wait = int(r.headers.get("Retry-After", 5))
            time.sleep(wait)
            continue
        r.raise_for_status()
        return r.json()

def main(min_level, out_path):
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {API_KEY}"  # confirm actual auth header name

    periods = get(session, "/periods")
    current_period = periods["current_period"]  # confirm actual field name

    all_runs = []
    page = 0
    while True:
        data = get(session, "/mythic-plus/runs",
                    season="current",       # confirm actual accepted values
                    region="us",
                    page=page)
        runs = data.get("rankings", [])     # confirm actual response key
        if not runs:
            break
        filtered = [r for r in runs if r["mythic_level"] >= min_level]
        all_runs.extend(filtered)
        page += 1

    with open(out_path, "w") as f:
        json.dump(all_runs, f)
