import json
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: extract_code.py <assistant_json> <output_file>")

json_path = sys.argv[1]
out_path = sys.argv[2]

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

code = data.get("code")
if not isinstance(code, str):
    raise SystemExit("assistant output missing 'code' string")

with open(out_path, "w", encoding="utf-8") as f:
    f.write(code)
    if not code.endswith("\n"):
        f.write("\n")
