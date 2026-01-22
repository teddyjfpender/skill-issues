import json
import sys

if len(sys.argv) != 6:
    raise SystemExit(
        "usage: steps_to_verify.py <steps_file> <verify_json> <started_at> <ended_at> <project_dir>"
    )

steps_file = sys.argv[1]
verify_json = sys.argv[2]
started_at = sys.argv[3]
ended_at = sys.argv[4]
project_dir = sys.argv[5]

steps = []
with open(steps_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        steps.append(json.loads(line))

status_counts = {"pass": 0, "fail": 0, "skipped": 0}
for step in steps:
    status = step.get("status", "")
    if status in status_counts:
        status_counts[status] += 1

overall_status = "pass"
if status_counts["fail"] > 0:
    overall_status = "fail"

failed_steps = [step["step"] for step in steps if step.get("status") == "fail"]

total_duration = sum(step.get("duration_sec", 0) for step in steps)

payload = {
    "version": 1,
    "status": overall_status,
    "started_at": started_at,
    "ended_at": ended_at,
    "duration_sec": total_duration,
    "project_dir": project_dir,
    "counts": status_counts,
    "failed_steps": failed_steps,
    "steps": steps,
}

with open(verify_json, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=False)
    f.write("\n")
