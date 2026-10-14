#!/usr/bin/env python3
#  build-zh-vocab.py: regenerates src/rankvocab/zh.ts from wordfreq.
#    pip install wordfreq && python3 scripts/build-zh-vocab.py
import re
from pathlib import Path
from wordfreq import top_n_list

HERE = Path(__file__).resolve().parent
cjk = re.compile(r"^[一-鿿]{1,4}$")
words, seen = [], set()
for w in top_n_list("zh", 30000):
    if cjk.match(w) and w not in seen:
        seen.add(w); words.append(w)
    if len(words) == 10000:
        break
dest = HERE / "../src/rankvocab/zh.ts"
src = dest.read_text(encoding="utf8")
start = src.index("const RAW = `") + len("const RAW = `")
end = src.index("`;", start)
body = "\n" + "\n".join(" ".join(words[i:i + 20]) for i in range(0, len(words), 20)) + "\n"
dest.write_text(src[:start] + body + src[end:], encoding="utf8")
print(f"wrote {len(words)} words")
