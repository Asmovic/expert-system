"""Model-mismatch experiment.

Regenerates the held-out cases (seed 777) with deliberately changed simulator
physics, diagnoses them with the unchanged knowledge base, and compares the
results case by case with the nominal held-out split.

Run from the project folder:
    python tests/mismatch.py

Writes docs/12_model_mismatch.md and report/tables/eval_mismatch.tex.
Python only generates data and formats results. All diagnosis runs in Prolog.
"""

import json
import math
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "simulator"))
import dc_sim  # noqa: E402

PROFILES = [("mild", "m"), ("strong", "s")]
MODES = ["deductive", "ded_abd", "ded_cbd", "full"]
MODE_NAMES = {"deductive": "Deductive only", "ded_abd": "Deductive + abductive",
              "ded_cbd": "Deductive + consistency-based", "full": "Complete system"}
CATEGORIES = [("normal", "Normal"), ("single_fault", "Single faults"), ("instrumentation", "Instrumentation"),
              ("multiple", "Multiple faults"), ("incomplete", "Incomplete"), ("noisy", "High noise"),
              ("borderline", "Borderline")]
SPLITS = ["holdout"] + [f"mismatch_{p}" for p, _ in PROFILES] + ["mismatch_strong_rebased"]
SPLIT_NAMES = {"holdout": "Nominal", "mismatch_mild": "Mild mismatch", "mismatch_strong": "Strong mismatch",
               "mismatch_strong_rebased": "Strong, re-baselined"}
BS = "\\"


def swipl():
    exe = shutil.which("swipl")
    if exe:
        return exe
    fallback = r"C:\Program Files\swipl\bin\swipl.exe"
    if os.path.exists(fallback):
        return fallback
    sys.exit("swipl not found")


def generate():
    # Normal operating data under the strong physics, from a different seed, used
    # only to re-baseline the envelope thresholds (no fault labels are used).
    subprocess.run([sys.executable, "-I", "simulator/dc_sim.py", "--seed", "20261020", "--prefix", "c",
                    "--split", "recal_strong", "--physics", "strong", "--out", "data/recal_strong.pl",
                    "--csv", "data/recal_strong.csv", "--truth", "data/recal_strong.json"],
                   cwd=ROOT, check=True, capture_output=True, text=True)
    for profile, prefix in PROFILES:
        base = os.path.join("data", f"mismatch_{profile}")
        subprocess.run([sys.executable, "-I", "simulator/dc_sim.py", "--seed", "777", "--prefix", prefix,
                        "--split", f"mismatch_{profile}", "--physics", profile,
                        "--out", base + ".pl", "--csv", base + ".csv", "--truth", base + ".json"],
                       cwd=ROOT, check=True, capture_output=True, text=True)


def diagnose():
    files = ", ".join([f"'data/mismatch_{p}.pl'" for p, _ in PROFILES] + ["'data/recal_strong.pl'"])
    splits = ", ".join(SPLITS[:-1])
    goal = (f"load_files([{files}], []), "
            f"forall(( member(Sp, [{splits}]), case_split(C, Sp), case_category(C, K), "
            f"member(M, [deductive, ded_abd, ded_cbd, full]) ), "
            f"( expected(C, E0), msort(E0, E), diagnose_mode(M, C, G0), msort(G0, G), "
            f"( E == G -> O = 1 ; O = 0 ), format(\"ROW ~w ~w ~w ~w ~w~n\", [Sp, C, K, M, O]) )), "
            f"rebaseline(calibration, recal_strong, Off), format(\"OFFSETS ~w~n\", [Off]), apply_offsets(Off), "
            f"forall(( case_split(C, mismatch_strong), case_category(C, K), "
            f"member(M, [deductive, ded_abd, ded_cbd, full]) ), "
            f"( expected(C, E0), msort(E0, E), diagnose_mode(M, C, G0), msort(G0, G), "
            f"( E == G -> O = 1 ; O = 0 ), format(\"ROW mismatch_strong_rebased ~w ~w ~w ~w~n\", [C, K, M, O]) ))")
    out = subprocess.run([swipl(), "-q", "-g", goal, "-t", "halt", "main.pl", "tests/rebaseline.pl"],
                         cwd=ROOT, check=True, capture_output=True, text=True).stdout
    rows = {}
    for line in out.splitlines():
        if line.startswith("OFFSETS "):
            rows["offsets"] = line[8:]
        if line.startswith("ROW "):
            _, sp, case, cat, mode, ok = line.split()
            rows[(sp, case[1:], mode)] = (cat, int(ok))     # case[1:] drops the prefix letter for pairing
    return rows


def wilson(k, n):
    z = 1.96
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return c - h, c + h


def mcnemar(a, b):
    """a, b: lists of 0/1 for paired cases. Returns (only a right, only b right, exact two-sided p)."""
    b01 = sum(1 for x, y in zip(a, b) if x and not y)
    b10 = sum(1 for x, y in zip(a, b) if y and not x)
    n = b01 + b10
    if n == 0:
        return b01, b10, 1.0
    k = min(b01, b10)
    return b01, b10, min(1.0, 2 * sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n)


def holm(ps):
    """Holm step-down adjusted p-values, in input order."""
    m = len(ps)
    adj = [0.0] * m
    prev = 0.0
    for k, i in enumerate(sorted(range(m), key=lambda j: ps[j])):
        prev = min(1.0, max(prev, (m - k) * ps[i]))
        adj[i] = prev
    return adj


def p_text(p, tex=False):
    """Three decimals, or '< 0.001' when the value would print as 0.000."""
    if p < 0.0005:
        return BS + "textless\\,0.001" if tex else "< 0.001"
    return f"{p:.3f}"


def results(rows):
    ids = sorted({k[1] for k in rows if isinstance(k, tuple) and k[0] == "holdout"})
    table = {}
    for sp in SPLITS:
        for m in MODES:
            oks = [rows[(sp, i, m)][1] for i in ids]
            cats = [rows[(sp, i, m)][0] for i in ids]
            table[(sp, m)] = (oks, cats)
    return ids, table


def write_outputs(ids, table, offsets):
    n = len(ids)
    md = ["# Model-Mismatch Experiment", "",
          "Generated by `tests/mismatch.py`. Do not edit by hand. Every case is synthetic.", "",
          "The held-out cases (seed 777) were regenerated with deliberately changed simulator physics, and "
          "diagnosed with the unchanged knowledge base. Each case keeps its faults, severities and random draws, "
          "so the comparison with the nominal split is paired case by case.", "",
          "| Parameter | Nominal | Mild | Strong |", "|---|---|---|---|"]
    keys = sorted(set(dc_sim.PHYSICS["mild"]) | set(dc_sim.PHYSICS["strong"]))
    nominal = {"HA_AIR": 15.0, "HA_WATER_DESIGN": 10.0, "DEFICIT_HOT_SHARE": 0.4, "P_IDLE": 0.40, "P_MAX": 0.90,
               "M_SERVER_NOM": 0.055, "AIRFLOW_MARGIN": 1.1, "T_ROOM": 25.0, "BETA_TOP_BASE": 0.10,
               "CPU_SHARE": 0.55, "R_TH_NOM": 90.0, "NOISE_SCALE": 1.0}
    for k in keys:
        md.append(f"| `{k}` | {nominal[k]:g} | {dc_sim.PHYSICS['mild'].get(k, nominal[k]):g} | "
                  f"{dc_sim.PHYSICS['strong'].get(k, nominal[k]):g} |")
    md += ["", "## Re-baselining", "",
           "For the last column, three envelope thresholds were shifted by how far the normal envelope moved, "
           "measured on normal cases only, generated under the strong physics with a different seed "
           "(20261020). No fault labels were used. Offsets applied, in kelvin or degrees Celsius:", "",
           f"`{offsets}`", "",
           "## Exact match", "", "| Mode | " + " | ".join(SPLIT_NAMES[s] for s in SPLITS) + " |",
           "|---" * (len(SPLITS) + 1) + "|"]
    tex = ["% Generated by tests/mismatch.py. Do not edit by hand.",
           f"{BS}begin{{table}}[htbp]", f"  {BS}centering", f"  {BS}footnotesize", f"  {BS}setlength{{{BS}tabcolsep}}{{4pt}}",
           f"  {BS}caption{{Model mismatch: exact match of each reasoning mode when the held-out cases are regenerated "
           f"with changed simulator physics and diagnosed with the unchanged knowledge base. The last pair of columns "
           f"re-baselines three envelope thresholds from normal operating data only. $p$: exact McNemar test against "
           f"the nominal split, paired case by case. Confidence intervals are in {BS}texttt{{docs/12{BS}_model{BS}_mismatch.md}}.}}",
           f"  {BS}label{{tab:mismatch}}",
           f"  {BS}begin{{tabular}}{{L{{3.2cm}}rrrrrrr}}", f"  {BS}toprule",
           f"  Mode & Nominal & Mild & $p$ & Strong & $p$ & Re-baselined & $p$ {BS}{BS}", f"  {BS}midrule"]
    for m in MODES:
        cells_md, cells_tex = [], []
        base = table[("holdout", m)][0]
        for sp in SPLITS:
            oks = table[(sp, m)][0]
            k = sum(oks)
            lo, hi = wilson(k, n)
            cells_md.append(f"{k / n * 100:.1f}% ({lo * 100:.1f} to {hi * 100:.1f})")
            cell = f"{k / n * 100:.1f}{BS}%"
            if sp == "holdout":
                cells_tex.append(cell)
            else:
                _, _, p = mcnemar(base, oks)
                pt = f"{BS}textbf{{{p_text(p, True)}}}" if p < 0.05 else p_text(p, True)
                cells_tex += [cell, pt]
        md.append(f"| {MODE_NAMES[m]} | " + " | ".join(cells_md) + " |")
        tex.append(f"  {MODE_NAMES[m]} & " + " & ".join(cells_tex) + f" {BS}{BS}")
    tex += [f"  {BS}bottomrule", f"  {BS}end{{tabular}}", f"{BS}end{{table}}", ""]

    md += ["", "## Paired change against the nominal split", "",
           "| Mode | Profile | Correct only at nominal | Correct only under mismatch | p |", "|---|---|---|---|---|"]
    for m in MODES:
        base = table[("holdout", m)][0]
        for sp in SPLITS[1:]:
            a, b, p = mcnemar(base, table[(sp, m)][0])
            md.append(f"| {MODE_NAMES[m]} | {SPLIT_NAMES[sp]} | {a} | {b} | {p_text(p)} |")

    md += ["", "## Exact match by category, complete system", "",
           "| Category | Cases | " + " | ".join(SPLIT_NAMES[s] for s in SPLITS) + " |",
           "|---" * (len(SPLITS) + 2) + "|"]
    tex2 = ["% Generated by tests/mismatch.py. Do not edit by hand.",
            f"{BS}begin{{table}}[htbp]", f"  {BS}centering", f"  {BS}small",
            f"  {BS}caption{{Model mismatch by test category: exact matches of the complete system.}}",
            f"  {BS}label{{tab:mismatch-categories}}",
            f"  {BS}begin{{tabular}}{{L{{3.4cm}}rrrrr}}", f"  {BS}toprule",
            f"  Category & Cases & Nominal & Mild & Strong & Re-baselined {BS}{BS}", f"  {BS}midrule"]
    for cat, label in CATEGORIES:
        counts = []
        for sp in SPLITS:
            oks, cats = table[(sp, "full")]
            counts.append(sum(o for o, c in zip(oks, cats) if c == cat))
        total = sum(1 for c in table[("holdout", "full")][1] if c == cat)
        md.append(f"| {label} | {total} | " + " | ".join(str(c) for c in counts) + " |")
        tex2.append(f"  {label} & {total} & " + " & ".join(str(c) for c in counts) + f" {BS}{BS}")
    tex2 += [f"  {BS}bottomrule", f"  {BS}end{{tabular}}", f"{BS}end{{table}}", ""]

    with open(os.path.join(ROOT, "docs", "12_model_mismatch.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(md) + "\n")
    with open(os.path.join(ROOT, "report", "tables", "eval_mismatch.tex"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(tex))
    with open(os.path.join(ROOT, "report", "tables", "eval_mismatch_categories.tex"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(tex2))
    print("\n".join(md))


def main():
    os.chdir(ROOT)
    generate()
    rows = diagnose()
    raw = rows.pop("offsets", "")
    import re
    offsets = ", ".join(f"{name} +{float(val):.2f}" for name, val in re.findall(r"(\w+)-([\d.]+)", raw)) or "none"
    ids, table = results(rows)
    write_outputs(ids, table, offsets)


if __name__ == "__main__":
    main()
