"""Convert report/references.bib to RIS for import into EndNote.

    python tests/bib_to_ris.py            # writes report/references.ris

Each record keeps its BibTeX key in the RIS label field (LB), which EndNote
imports as "Label", so the keys used by \\cite in the report survive the
round trip. The script also reports the counts it wrote so they can be
checked against the 77 entries in the bibliography.
"""
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIB = ROOT / "report" / "references.bib"
RIS = ROOT / "report" / "references.ris"

BS = chr(92)

# BibTeX type -> RIS type
TYPES = {
    "article": "JOUR",
    "book": "BOOK",
    "incollection": "CHAP",
    "inproceedings": "CPAPER",
    "manual": "STAND",
    "techreport": "RPRT",
    "online": "ELEC",
    "misc": "GEN",
}

ACCENTS = {"'": "́", "`": "̀", '"': "̈", "^": "̂",
           "~": "̃", "c": "̧", "v": "̌", "=": "̄"}


def parse(text):
    """Return a list of (type, key, {field: value}) from BibTeX text."""
    entries = []
    pos = 0
    head = re.compile(r"@(\w+)\s*\{\s*([^,\s]+)\s*,")
    while True:
        m = head.search(text, pos)
        if not m:
            break
        etype, key = m.group(1).lower(), m.group(2)
        i = m.end()
        fields = {}
        while True:
            fm = re.compile(r"\s*(\w+)\s*=\s*").match(text, i)
            if not fm:
                break
            name = fm.group(1).lower()
            i = fm.end()
            if text[i] == "{":
                depth, j = 0, i
                while True:
                    if text[j] == "{":
                        depth += 1
                    elif text[j] == "}":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                value = text[i + 1:j]
                i = j + 1
            elif text[i] == '"':
                j = text.index('"', i + 1)
                value = text[i + 1:j]
                i = j + 1
            else:
                vm = re.compile(r"[^,}\s]+").match(text, i)
                value = vm.group(0)
                i = vm.end()
            fields[name] = value
            cm = re.compile(r"\s*,").match(text, i)
            if cm:
                i = cm.end()
        entries.append((etype, key, fields))
        pos = i
    return entries


def clean(value):
    """Turn a BibTeX field value into plain Unicode text."""
    s = value
    # accents such as {\'e}, \'{e}, \"o
    acc = re.compile(r"\{?" + re.escape(BS) + r"([" + re.escape("'`\"^~=") + r"]|[cv](?=[\s{]))\s*\{?(\w)\}?\}?")
    s = acc.sub(lambda m: unicodedata.normalize("NFC", m.group(2) + ACCENTS[m.group(1)]), s)
    s = s.replace(BS + "&", "&").replace(BS + "%", "%").replace(BS + "_", "_")
    s = s.replace(BS + "textdegree", "°").replace(BS + ",", " ")
    s = s.replace("---", "—").replace("--", "–").replace("~", " ")
    s = s.replace("{", "").replace("}", "")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def names(value):
    """Split a BibTeX name list; corporate names in double braces stay whole."""
    parts = re.split(r"\s+and\s+", value.strip())
    return [clean(p) for p in parts if p.strip()]


def to_ris(etype, key, f):
    ty = TYPES.get(etype, "GEN")
    if ty == "BOOK" and "editor" in f and "author" not in f:
        ty = "EDBOOK"  # EndNote "Edited Book": its first name field is Editor
    lines = [("TY", ty)]
    for a in names(f.get("author", "")):
        lines.append(("AU", a))
    editor_tag = "ED" if etype in ("incollection", "inproceedings") or "author" in f else "AU"
    for e in names(f.get("editor", "")):
        lines.append((editor_tag, e))
    lines.append(("TI", clean(f["title"])))
    if "journal" in f:
        lines.append(("T2", clean(f["journal"])))
    if "booktitle" in f:
        lines.append(("T2", clean(f["booktitle"])))
    if "year" in f:
        lines.append(("PY", clean(f["year"])))
    for tag, name in (("VL", "volume"), ("IS", "number"), ("ET", "edition"),
                      ("PB", "publisher"), ("CY", "address"), ("DO", "doi"),
                      ("UR", "url"), ("N1", "note"), ("M3", "type")):
        if name in f:
            lines.append((tag, clean(f[name])))
    for name in ("institution", "organization"):
        if name in f and "publisher" not in f:
            lines.append(("PB", clean(f[name])))
    if "pages" in f:
        p = clean(f["pages"]).split("–")
        lines.append(("SP", p[0].strip()))
        if len(p) > 1:
            lines.append(("EP", p[1].strip()))
    if "urldate" in f:
        lines.append(("Y2", clean(f["urldate"])))
    if f.get("eprinttype", "").lower() == "arxiv":
        lines.append(("UR", "https://arxiv.org/abs/" + clean(f["eprint"])))
    lines.append(("LB", key))
    lines.append(("ER", ""))
    return "".join(f"{t}  - {v}\n" for t, v in lines)


def main():
    entries = parse(BIB.read_text(encoding="utf-8"))
    keys = [k for _, k, _ in entries]
    dupes = {k for k in keys if keys.count(k) > 1}
    if dupes:
        sys.exit(f"duplicate keys: {sorted(dupes)}")
    leftover = []
    out = []
    for etype, key, f in entries:
        rec = to_ris(etype, key, f)
        if BS in rec or "{" in rec or "}" in rec:
            leftover.append(key)
        out.append(rec)
    RIS.write_text("\n".join(out), encoding="utf-8")
    print(f"wrote {len(entries)} records to {RIS.relative_to(ROOT)}")
    if leftover:
        print("unconverted LaTeX left in:", ", ".join(leftover))
        sys.exit(1)


if __name__ == "__main__":
    main()
