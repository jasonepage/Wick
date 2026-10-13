#!/usr/bin/env python3
#
#  build-gloss-wordnet.py: builds public/gloss/{es,fr,it,de}.json, the short
#  meaning shown next to each guess when the web menus are in that language.
#  (Chinese comes from ECDICT instead; see build-gloss-zh.mjs.)
#
#  Sources, all linked to English WordNet by synset, so "ocean" maps to the
#  sense that means the sea and not something else:
#    - Open Multilingual Wordnet 1.4 (omw-en, omw-es, omw-fr, omw-it)
#      https://github.com/omwn/omw-data/releases/tag/v1.4
#    - OdeNet 1.4 for German (CC BY-SA 4.0), used to confirm German candidates
#      https://github.com/hdaSprachtechnologie/odenet/releases/tag/v1.4
#    - Ding / FreeDict English-German 1.9 (GPL-3) for the German words themselves;
#      OdeNet's automatic links are too rough on their own (big -> üppig).
#      https://freedict.org/ (Debian/Ubuntu package dict-freedict-eng-deu)
#    - ECDICT's ecdict.csv, used ONLY at build time to map an inflected English
#      form (students, was) to its base word. No ECDICT data ships here.
#
#  Run from wick-web:
#    python3 scripts/build-gloss-wordnet.py /path/to/omw-1.4 /path/to/odenet-1.4/deWordNet.xml /path/to/ecdict.csv /path/to/freedict-eng-deu.dict
#
#  Only the words the game can score are kept (wick-api/src/rankvocab.ts plus
#  the daily pool). A daily answer always uses the pool's own translation so the
#  guess row and the solved screen agree. No packages beyond the standard library.
#

import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
if len(sys.argv) != 5:
    sys.exit("usage: build-gloss-wordnet.py <omw-1.4 dir> <deWordNet.xml> <ecdict.csv> <freedict-eng-deu.dict>")
OMW, ODENET, ECDICT, DING = (Path(a) for a in sys.argv[1:5])

# ── the words we want ────────────────────────────────────────────────────────
rank_src = (HERE / "../../wick-api/src/rankvocab.ts").read_text(encoding="utf8")
raw = re.search(r"const RAW = `([\s\S]*?)`;", rank_src).group(1)
want = {w.lower() for w in raw.split() if w}
pool = json.loads((HERE / "../src/game/dailyPool.json").read_text(encoding="utf8"))
for e in pool:
    want.add(e["en"].lower())
print(f"wanted words: {len(want)}")

# ── base forms for inflected words, from ECDICT's "exchange" column ("0:run") ──
csv.field_size_limit(10**8)
lemma_of = {}
with open(ECDICT, encoding="utf8") as f:
    for row in csv.DictReader(f):
        w = row["word"].lower()
        if w not in want:
            continue
        m = re.search(r"(?:^|/)0:([^/]+)", row.get("exchange") or "")
        if m:
            lemma_of[w] = m.group(1).lower()
print(f"inflected forms with a base word: {len(lemma_of)}")

# ── English: lemma -> ordered list of synset ILI ids ─────────────────────────
def iter_lexicon(path):
    """Yield ('entry', lemma, pos, [synset ids]) and ('synset', id, ili) in file order."""
    for _, el in ET.iterparse(path, events=("end",)):
        tag = el.tag.split("}")[-1]
        if tag == "LexicalEntry":
            lem = el.find("Lemma")
            senses = [s.get("synset") for s in el.findall("Sense")]
            yield ("entry", lem.get("writtenForm"), lem.get("partOfSpeech"), senses)
            el.clear()
        elif tag == "Synset":
            yield ("synset", el.get("id"), el.get("ili"), None)
            el.clear()

en_senses = {}   # lemma -> [synset id] in sense order (WordNet lists common senses first)
en_ili = {}      # synset id -> ili
for kind, a, b, c in iter_lexicon(OMW / "omw-en" / "omw-en.xml"):
    if kind == "entry":
        w = a.lower()
        if w in want and " " not in w:
            en_senses.setdefault(w, []).extend(c)
    else:
        en_ili[a] = b
print(f"english entries found: {len(en_senses)}")

# ── target languages: ili -> [lemmas] ────────────────────────────────────────
def target_table(path):
    syn_lemmas = {}
    syn_ili = {}
    for kind, a, b, c in iter_lexicon(path):
        if kind == "entry":
            for sid in c:
                syn_lemmas.setdefault(sid, []).append(a)
        else:
            syn_ili[a] = b
    out = {}
    for sid, lemmas in syn_lemmas.items():
        ili = syn_ili.get(sid)
        if ili:
            out.setdefault(ili, []).extend(lemmas)
    return out

def plain(l):
    return " " not in l and "_" not in l and len(l) <= 18

def pick(word, table):
    """The target lemma that covers the most of the English word's senses.
    A word like "time" has senses for a period, an occasion and the clock; the
    lemma shared by most of them (tiempo) is the one a learner wants, not the
    one from whichever sense happens to be listed first (vez). Single words
    win over phrases; ties go to the earliest sense."""
    score = {}
    for i, sid in enumerate(en_senses[word]):
        for l in table.get(en_ili.get(sid, ""), []):
            if l.lower() == word:
                continue                       # "banana" -> "banana" tells nothing; skip unless it is all there is
            sc = score.setdefault(l, [0, i])
            sc[0] += 1
    if not score:
        for sid in en_senses[word]:
            for l in table.get(en_ili.get(sid, ""), []):
                return l.replace("_", " ")
        return None
    best = max(score, key=lambda l: (plain(l), score[l][0], -score[l][1]))
    if not plain(best) and len(best) > 24:
        return None
    return best.replace("_", " ")

def build(lang, table):
    out = {}
    for w in sorted(want):
        base = w if w in en_senses else lemma_of.get(w)
        if not base or base not in en_senses:
            continue
        g = pick(base, table)
        if g:
            out[w] = g
    # Daily answers use the pool's own translation, so the row matches the solved screen.
    for e in pool:
        out[e["en"].lower()] = e[lang]
    dest = HERE / "../public/gloss" / f"{lang}.json"
    dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf8")
    print(f"{lang}: wrote {len(out)} entries to {dest.name}; missing {len(want) - len(out)}")

for lang in ("es", "fr", "it"):
    build(lang, target_table(OMW / f"omw-{lang}" / f"omw-{lang}.xml"))

# ── German: Ding entries, scored, with OdeNet as a tie-breaker ──────────────
# Ding has many entries per headword (dog: Hund, but also the dog on a crane).
# Score every German item by how often it recurs across the word's entries,
# weigh specialist entries ([naut.], [techn.]) down, first items up, and add a
# bonus when OdeNet also lists it for one of the word's senses.
from collections import Counter
odenet = target_table(ODENET)
ding = {}
lines = DING.read_text(encoding="utf8").split("\n")
for i, l in enumerate(lines):
    m = re.match(r"^([A-Za-z][A-Za-z'-]*) /", l)
    if not m:
        continue
    w = m.group(1).lower()
    if w not in want:
        continue
    t = lines[i + 1] if i + 1 < len(lines) else ""
    specialist = bool(re.search(r"\[(?!ugs|geh|poet|selten)[a-z]+\.\]", t))
    t = re.sub(r"<[^>]*>|\[[^\]]*\]|\{[^}]*\}|\([^)]*\)", "", t)
    items = [x.strip() for x in re.split(r"[,;]", t) if x.strip()]
    c = ding.setdefault(w, Counter())
    for k, x in enumerate(items):
        if len(x) > 24 or any(ch in x for ch in "…/.:"):
            continue
        c[x] += (1 if specialist else 2) * (2 if k == 0 else 1)

out = {}
for w in sorted(want):
    c = ding.get(w)
    if not c:
        continue
    base = w if w in en_senses else lemma_of.get(w)
    known = set()
    if base in en_senses:
        for sid in en_senses[base]:
            known.update(l.lower() for l in odenet.get(en_ili.get(sid, ""), []))
    out[w] = max(c, key=lambda x: (c[x] + (5 if x.lower() in known else 0), " " not in x, -len(x)))
for e in pool:
    out[e["en"].lower()] = e["de"]
dest = HERE / "../public/gloss/de.json"
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf8")
print(f"de: wrote {len(out)} entries to {dest.name}; missing {len(want) - len(out)}")
