import requests, time, json, argparse, os

BASE = "https://raider.io/api/v1"
API_KEY = os.environ["RAIDERIO_API_KEY"]
SEASON = "season-mn-2"

DUNGEONS = [
    "altar-of-fangs",
    "den-of-nalorakk",
    "kings-rest",
    "murder-row",
    "ruby-life-pools",
    "temple-of-sethraliss",
    "the-blinding-vale",
    "voidscar-arena",
]

def get(session, path, **params):
    params["access_key"] = API_KEY
    while True:
        r = session.get(f"{BASE}{path}", params=params)
        if r.status_code == 429:
            wait = int(r.headers.get("Retry-After", 5))
            print(f"Rate limited, waiting {wait}s...")
            time.sleep(wait)
            continue
        if r.status_code == 400:
            return None  # signal "no more pages"
        r.raise_for_status()
        return r.json()

def extract_run(rank_entry):
    run = rank_entry["run"]
    return {
        "mythic_level": run["mythic_level"],
        "completed_at": run["completed_at"],
        "dungeon": run["dungeon"]["slug"],
        "status": run["status"],
        "score": rank_entry["score"],
        "roster": [
            {
                "name": member["character"]["name"],
                "realm": member["character"]["realm"]["slug"],
                "region": member["character"]["region"]["slug"],
                "class": member["character"]["class"]["slug"],
                "spec": member["character"]["spec"]["slug"],
                "role": member["role"],
            }
            for member in run["roster"]
        ],
    }

def fetch_dungeon(session, dungeon_slug, min_level):
    print(f"=== Fetching {dungeon_slug} ===")
    runs_for_dungeon = []
    page = 0
    while True:
        data = get(session, "/mythic-plus/runs",
                    season=SEASON,
                    region="us",
                    dungeon=dungeon_slug,
                    page=page)
        if data is None:
            print(f"  {dungeon_slug}: hit last page at {page}, stopping.")
            break
        runs = data.get("rankings", [])
        if not runs:
            print(f"  {dungeon_slug}: no more runs at page {page}, stopping.")
            break
        filtered = [extract_run(r) for r in runs if r["run"]["mythic_level"] >= min_level]
        runs_for_dungeon.extend(filtered)
        page += 1
    print(f"  {dungeon_slug}: {len(runs_for_dungeon)} qualifying runs")
    return runs_for_dungeon

def main(min_level, out_path):
    session = requests.Session()

    all_runs = []
    for dungeon_slug in DUNGEONS:
        all_runs.extend(fetch_dungeon(session, dungeon_slug, min_level))

    print(f"Total qualifying runs collected across all dungeons: {len(all_runs)}")
    with open(out_path, "w") as f:
        json.dump(all_runs, f)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-level", type=int, required=True)
    parser.add_argument("--out", type=str, required=True)
    args = parser.parse_args()
    main(args.min_level, args.out)