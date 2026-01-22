import json
import os
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: write_run_metadata.py <out_json>")

out_path = sys.argv[1]

def getenv(name, default=""):
    value = os.environ.get(name)
    if value is None:
        return default
    return value

payload = {
    "prompt_id": getenv("RUN_PROMPT_ID"),
    "prompt_path": getenv("RUN_PROMPT_PATH"),
    "prompt_used": getenv("RUN_PROMPT_USED"),
    "skill": getenv("RUN_SKILL"),
    "disable_skills": getenv("RUN_DISABLE_SKILLS") == "1",
    "schema_path": getenv("RUN_SCHEMA_PATH"),
    "work_dir": getenv("RUN_WORK_DIR"),
    "out_file": getenv("RUN_OUT_FILE"),
    "results_dir": getenv("RUN_RESULTS_DIR"),
    "model": getenv("RUN_MODEL"),
    "codex_exit_code": int(getenv("RUN_CODEX_EXIT", "0") or 0),
    "started_at": getenv("RUN_STARTED_AT"),
    "ended_at": getenv("RUN_ENDED_AT"),
    "codex_jsonl": getenv("RUN_CODEX_JSONL"),
    "codex_stderr": getenv("RUN_CODEX_STDERR"),
    "last_message": getenv("RUN_LAST_MESSAGE"),
    "codex_args": getenv("RUN_CODEX_ARGS"),
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=False)
    f.write("\n")
