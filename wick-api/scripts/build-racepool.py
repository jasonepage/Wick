#!/usr/bin/env python3
#
#  build-racepool.py: turns scripts/racepool.txt (+ racepool-zh.txt) into the
#  MATCH_WORDS table in src/words.ts. Drops anything that is also a daily
#  answer (wick-web/src/game/dailyPool.json) so a race can never spoil the
#  day's puzzle, and anything with a duplicate English form.
#
#    python3 scripts/build-racepool.py
#

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
LANGS = ["en", "es", "fr", "it", "de", "zh"]

def rows(path, n):
    out = []
    for line in Path(path).read_text(encoding="utf8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != n:
            raise SystemExit(f"{path}: bad line: {line}")
        out.append(parts)
    return out

base = rows(HERE / "racepool.txt", 5)
zh = {en: z for en, z in rows(HERE / "racepool-zh.txt", 2)}
daily = {e["en"].lower() for e in json.loads((HERE / "../../wick-web/src/game/dailyPool.json").read_text(encoding="utf8"))}

seen = set()
entries = []
dropped = []
for en, es, fr, it, de in base:
    en = en.lower()
    if en in daily:
        dropped.append(f"{en} (daily)")
        continue
    if en in seen:
        dropped.append(f"{en} (dup)")
        continue
    if en not in zh:
        raise SystemExit(f"no Chinese for {en}")
    seen.add(en)
    entries.append({"en": en, "es": es.lower(), "fr": fr.lower(), "it": it.lower(), "de": de.lower(), "zh": zh[en]})

for e in entries:
    for l in LANGS:
        if not e[l] or "`" in e[l] or "${" in e[l]:
            raise SystemExit(f"bad {l} for {e['en']}")

src_path = HERE / "../src/words.ts"
src = src_path.read_text(encoding="utf8")
start = src.index("export const MATCH_WORDS: readonly MatchWord[] = [")
end = src.index("];", start) + 2
body = "export const MATCH_WORDS: readonly MatchWord[] = [\n" + "".join(
    "  W(" + ", ".join(json.dumps(e[l], ensure_ascii=False) for l in LANGS) + "),\n" for e in entries
) + "];"
src_path.write_text(src[:start] + body + src[end:], encoding="utf8")
print(f"wrote {len(entries)} race words; dropped {len(dropped)}: {', '.join(dropped)}")
