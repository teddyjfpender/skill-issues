import re
import sys
from typing import List, Optional, Tuple

if len(sys.argv) != 2:
    raise SystemExit("usage: ensure_scarb_toml.py <Scarb.toml>")

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

section_re = re.compile(r"^\s*\[([^\]]+)\]\s*$")

blocks: List[Tuple[Optional[str], List[str]]] = []
current_name: Optional[str] = None
current_lines: List[str] = []

for line in lines:
    match = section_re.match(line)
    if match:
        if current_lines or current_name is not None:
            blocks.append((current_name, current_lines))
        current_name = match.group(1).strip()
        current_lines = [line]
    else:
        current_lines.append(line)

if current_lines or current_name is not None:
    blocks.append((current_name, current_lines))

remove_sections = {"cairo", "scripts", "dependencies", "executable"}
filtered_blocks: List[Tuple[Optional[str], List[str]]] = []
for name, block_lines in blocks:
    if name in remove_sections:
        continue
    filtered_blocks.append((name, block_lines))

insert_block = [
    "\n",
    "[cairo]\n",
    "enable-gas = true\n",
    "\n",
    "[scripts]\n",
    "test = \"snforge test\"\n",
    "\n",
    "[dependencies]\n",
    "cairo_execute = \"2.14.0\"\n",
    "snforge_std = \"0.55.0\"\n",
]

inserted = False
new_lines: List[str] = []
for name, block_lines in filtered_blocks:
    new_lines.extend(block_lines)
    if name == "package" and not inserted:
        # Ensure exactly one blank line before the inserted block.
        if new_lines and not new_lines[-1].endswith("\n"):
            new_lines[-1] = new_lines[-1] + "\n"
        new_lines.extend(insert_block)
        inserted = True

if not inserted:
    if new_lines and not new_lines[-1].endswith("\n"):
        new_lines[-1] = new_lines[-1] + "\n"
    new_lines.extend(insert_block)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
