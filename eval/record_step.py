import json
import sys

if len(sys.argv) < 9:
    raise SystemExit(
        "usage: record_step.py <steps_file> <step> <cmd> <status> <exit_code> <duration_sec> <stdout_path> <stderr_path> [message]"
    )

steps_file = sys.argv[1]
step = sys.argv[2]
cmd = sys.argv[3]
status = sys.argv[4]
exit_code = int(sys.argv[5])
duration_sec = int(sys.argv[6])
stdout_path = sys.argv[7]
stderr_path = sys.argv[8]
message = sys.argv[9] if len(sys.argv) > 9 else ""

record = {
    "step": step,
    "cmd": cmd,
    "status": status,
    "exit_code": exit_code,
    "duration_sec": duration_sec,
    "stdout_path": stdout_path,
    "stderr_path": stderr_path,
    "message": message,
}

with open(steps_file, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, sort_keys=True) + "\n")
