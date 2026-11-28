#!/usr/bin/env python3
import argparse
import json
import re
import ssl
import statistics
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

FORGEJO_PULLS = "https://forgejo.mac-mini-m4-pro.internal/api/v1/repos/ccycle/dotfiles/pulls"
REWORK_SUBJECT = re.compile(r"^(fix|revert)(\(|!|:)|^Revert ")
SCOPE = re.compile(r"^[a-z]+\(([^)]+)\)")
COMIN_GENERATION = re.compile(r'time="([^"]+)".*a generation is available for deployment with commit ([0-9a-f]{40})')
FAILED_CHANGE_WINDOW = timedelta(days=7)
STALE_ALERT_AGE = timedelta(hours=24)
PROMETHEUS_STEP_SECONDS = 300
PROMETHEUS_WINDOW = timedelta(days=30)

UNVERIFIED_TLS = ssl.create_default_context()
UNVERIFIED_TLS.check_hostname = False
UNVERIFIED_TLS.verify_mode = ssl.CERT_NONE


def get_json(url):
    with urllib.request.urlopen(url, timeout=30, context=UNVERIFIED_TLS) as response:
        return json.load(response)


def parse_time(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def commit_exists(sha):
    return subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"], capture_output=True).returncode == 0


def hours(delta):
    return round(delta.total_seconds() / 3600, 2)


def summarize(values):
    if not values:
        return {"count": 0}
    ordered = sorted(values)
    return {
        "count": len(ordered),
        "median": round(statistics.median(ordered), 2),
        "p90": round(ordered[min(len(ordered) - 1, int(len(ordered) * 0.9))], 2),
        "max": round(ordered[-1], 2),
    }


def merged_pulls():
    pulls, page = [], 1
    while batch := get_json(f"{FORGEJO_PULLS}?state=closed&limit=50&page={page}"):
        pulls += [p for p in batch if p["merged"] and p["base"]["ref"] == "main"]
        page += 1
    return sorted(pulls, key=lambda p: p["merged_at"])


def pull_commits(previous_sha, sha):
    log = git("log", "--format=%H%x09%aI%x09%s", f"{previous_sha}..{sha}")
    return [dict(zip(("sha", "authored", "subject"), line.split("\t", 2))) for line in log.splitlines()]


def scopes(commits):
    found = set()
    for commit in commits:
        if match := SCOPE.match(commit["subject"]):
            found |= {re.split(r"[/:]", s.strip())[0] for s in match.group(1).split(",")}
    return found


def comin_generation_times(log_path):
    first_seen = {}
    for line in Path(log_path).read_text().splitlines():
        if match := COMIN_GENERATION.search(line):
            first_seen.setdefault(match.group(2), parse_time(match.group(1)))
    return first_seen


def firing_alert_runs(prometheus):
    end = datetime.now(timezone.utc)
    start = end - PROMETHEUS_WINDOW
    query = urllib.parse.urlencode(
        {
            "query": 'ALERTS{alertstate="firing"}',
            "start": start.timestamp(),
            "end": end.timestamp(),
            "step": PROMETHEUS_STEP_SECONDS,
        }
    )
    series = get_json(f"{prometheus}/api/v1/query_range?{query}")["data"]["result"]
    resolved, ongoing = [], []
    for s in series:
        stamps = [float(t) for t, _ in s["values"]]
        run_start = previous = stamps[0]
        for stamp in stamps[1:] + [None]:
            if stamp is not None and stamp - previous <= 2 * PROMETHEUS_STEP_SECONDS:
                previous = stamp
                continue
            duration = (previous - run_start) / 3600
            is_ongoing = end.timestamp() - previous <= 2 * PROMETHEUS_STEP_SECONDS
            if is_ongoing:
                ongoing.append(f"{s['metric']['alertname']}/{s['metric'].get('job', '')}: {duration:.0f}h")
            else:
                resolved.append(round(duration, 2))
            if stamp is not None:
                run_start = previous = stamp
    return {"resolved_hours": summarize(resolved), "ongoing": sorted(ongoing)}


def dora(args):
    pulls = merged_pulls()
    rows, missing = [], []
    for previous, pull in zip(pulls, pulls[1:]):
        if not (commit_exists(previous["merge_commit_sha"]) and commit_exists(pull["merge_commit_sha"])):
            missing.append(pull["number"])
            continue
        commits = pull_commits(previous["merge_commit_sha"], pull["merge_commit_sha"])
        if not commits:
            missing.append(pull["number"])
            continue
        merged = parse_time(pull["merged_at"])
        rows.append(
            {
                "number": pull["number"],
                "merged": merged,
                "sha": pull["merge_commit_sha"],
                "lead_hours": hours(merged - min(parse_time(c["authored"]) for c in commits)),
                "rework": all(REWORK_SUBJECT.match(c["subject"]) for c in commits),
                "scopes": scopes(commits),
            }
        )

    changes = [r for r in rows if not r["rework"]]
    reworks = [r for r in rows if r["rework"]]
    failed = [
        c
        for c in changes
        if any(
            c["merged"] < r["merged"] <= c["merged"] + FAILED_CHANGE_WINDOW and c["scopes"] & r["scopes"]
            for r in reworks
        )
    ]
    weeks = Counter(r["merged"].strftime("%G-W%V") for r in rows)
    result = {
        "window": {"first_merge": rows[0]["merged"].isoformat(), "last_merge": rows[-1]["merged"].isoformat()},
        "pulls_measured": len(rows),
        "pulls_skipped_no_commits_on_main": missing,
        "deployment_frequency_per_week": {
            "median": statistics.median(weeks.values()),
            "last_4_weeks": [weeks[w] for w in sorted(weeks)[-4:]],
        },
        "lead_time_first_commit_to_merge_hours": summarize([r["lead_hours"] for r in rows]),
        "rework_rate": round(len(reworks) / len(rows), 3),
        "change_failure_rate": round(len(failed) / len(changes), 3),
        "failed_change_pulls": [c["number"] for c in failed],
    }
    if args.comin_log:
        seen = comin_generation_times(args.comin_log)
        result["merge_to_comin_pickup_hours"] = summarize(
            [hours(seen[r["sha"]] - r["merged"]) for r in rows if r["sha"] in seen]
        )
    result["time_to_restore"] = {host: firing_alert_runs(prometheus_url(host)) for host in args.host}
    print(json.dumps(result, indent=2))


def prometheus_url(host):
    return f"https://prometheus.{host}.internal"


def nix_eval(flake_ref, apply, failure_is_data):
    out = subprocess.run(
        ["nix", "eval", "--impure", "--json", f"{flake_ref}#darwinConfigurations", "--apply", apply],
        capture_output=True,
        text=True,
    )
    if out.returncode == 0:
        return json.loads(out.stdout)
    if failure_is_data:
        return None
    sys.exit(f"nix eval failed for {flake_ref}:\n{out.stderr}")


SYSTEM_DRV_PATHS = """
cs: builtins.listToAttrs (builtins.concatMap (name:
  let v = cs.${name}; in
  if v ? system then [ { inherit name; value = v.system.drvPath; } ]
  else if v ? aarch64-darwin then [ { name = "${name}.aarch64-darwin"; value = v.aarch64-darwin.system.drvPath; } ]
  else [ ]) (builtins.attrNames cs))
"""


def blast_radius(args):
    shas = [p["merge_commit_sha"] for p in merged_pulls()][-(args.pulls + 1) :]
    root = git("rev-parse", "--show-toplevel").strip()
    drv_paths = {}
    for sha in shas:
        drv_paths[sha] = nix_eval(f"git+file://{root}?rev={sha}", SYSTEM_DRV_PATHS, failure_is_data=True)
        print(f"evaluated {sha[:7]}", file=sys.stderr)
    rows = []
    for before, after in zip(shas, shas[1:]):
        if drv_paths[before] is None or drv_paths[after] is None:
            rows.append({"sha": after[:7], "changed_profiles": None})
            continue
        changed = sorted(p for p in drv_paths[after] if drv_paths[after][p] != drv_paths[before].get(p))
        feature_dirs = {
            path.split("/")[1]
            for path in git("diff", "--name-only", before, after).splitlines()
            if path.startswith("modules/") and path.count("/") >= 2
        }
        rows.append(
            {
                "sha": after[:7],
                "changed_profiles": changed,
                "every_profile": changed == sorted(drv_paths[after]),
                "feature_dirs": sorted(feature_dirs),
            }
        )
    measured = [r for r in rows if r["changed_profiles"] is not None]
    print(
        json.dumps(
            {
                "pulls_measured": len(measured),
                "pulls_eval_failed": [r["sha"] for r in rows if r["changed_profiles"] is None],
                "changed_profiles_per_pull": summarize([len(r["changed_profiles"]) for r in measured]),
                "pulls_changing_every_profile": sum(1 for r in measured if r["every_profile"]),
                "pulls_by_changed_profile": dict(Counter(p for r in measured for p in r["changed_profiles"])),
                "pulls": rows,
            },
            indent=2,
        )
    )


def endpoint_is_up(url):
    try:
        with urllib.request.urlopen(url, timeout=10, context=UNVERIFIED_TLS) as response:
            return response.status < 500
    except urllib.error.HTTPError as error:
        return error.code < 500
    except OSError:
        return False


def detection(args):
    result = {}
    now = datetime.now(timezone.utc)
    for host in args.host:
        prometheus = prometheus_url(host)
        probed = {
            s["metric"].get("instance", "").rstrip("/")
            for s in get_json(f"{prometheus}/api/v1/series?match[]=probe_success")["data"]
        }
        endpoints = nix_eval(
            ".", f'cs: map (e: e.url) cs."{host}".config.services.caddy.portalEntries', failure_is_data=False
        )
        firing = [a for a in get_json(f"{prometheus}/api/v1/alerts")["data"]["alerts"] if a["state"] == "firing"]
        result[host] = {
            "endpoints": len(endpoints),
            "endpoints_probed": sum(1 for e in endpoints if e.rstrip("/") in probed),
            "endpoints_down_now": [e for e in endpoints if not endpoint_is_up(e)],
            "alerts_firing": len(firing),
            "alerts_firing_over_24h": sorted(
                f"{a['labels']['alertname']}/{a['labels'].get('job', '')}"
                for a in firing
                if now - parse_time(a["activeAt"]) > STALE_ALERT_AGE
            ),
        }
    print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(required=True)
    p = sub.add_parser("dora")
    p.add_argument("--host", action="append", required=True)
    p.add_argument("--comin-log")
    p.set_defaults(run=dora)
    p = sub.add_parser("blast-radius")
    p.add_argument("--pulls", type=int, required=True)
    p.set_defaults(run=blast_radius)
    p = sub.add_parser("detection")
    p.add_argument("--host", action="append", required=True)
    p.set_defaults(run=detection)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
