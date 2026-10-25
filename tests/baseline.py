"""Data-driven baseline, for comparison only (review item B6).

Run from the project folder:

    python tests/baseline.py     # needs scikit-learn; a few minutes

The project framework forbids replacing the symbolic system with machine
learning, not comparing against it. This script trains standard classifiers
on the raw readings, with no engineering knowledge, and tests them on the
same cases as the expert system:

  Features   every (variable, entity) reading of a case, as one vector.
             A missing reading is NaN. The UPS mode is 1 for bypass, else 0.
  Labels     binary relevance over the fault labels seen in training, for
             example chw_supply_loss(crah_1). A case with no predicted fault
             is predicted normal.
  Models     a random forest of 300 trees and a single decision tree.
  Training   (a) the calibration split, 255 cases, the data the knowledge
             base was checked against; (b) ten further simulated splits,
             2550 labelled cases, far more fault data than a real site has.
  Testing    the held-out split, the five held-out seeds of tests/seeds.py,
             and the two model-mismatch profiles of tests/mismatch.py.

The expert system is diagnosed on the same cases, so the comparison is
paired. Writes data/baseline/, docs/17_baseline_comparison.md and
report/tables/eval_baseline.tex, and prints the counts as JSON.
"""

import csv
import json
import math
import os
import subprocess
import sys

import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mismatch import MODE_NAMES, BS, swipl, wilson, mcnemar, p_text  # noqa: E402
from seeds import NEW_SEEDS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAIN_SEEDS = [(5000 + i, "t" + "abcdefghij"[i - 1]) for i in range(1, 11)]

# test set -> list of (csv, truth json) files, and how the expert system names its split
TEST_SETS = {
    "holdout": [("data/holdout_cases.csv", "data/holdout_truth.json")],
    "five_seeds": [("data/holdout_cases.csv", "data/holdout_truth.json")]
                  + [(f"data/seeds/holdout_{s}.csv", f"data/seeds/holdout_{s}.json") for s, _ in NEW_SEEDS],
    "mismatch_mild": [("data/mismatch_mild.csv", "data/mismatch_mild.json")],
    "mismatch_strong": [("data/mismatch_strong.csv", "data/mismatch_strong.json")],
}
TEST_NAMES = {"holdout": "Held-out (seed 777)", "five_seeds": "Five seeds, pooled",
              "mismatch_mild": "Mild model mismatch", "mismatch_strong": "Strong model mismatch"}
PROLOG_FILES = {"holdout": [], "five_seeds": [f"data/seeds/holdout_{s}.pl" for s, _ in NEW_SEEDS],
                "mismatch_mild": ["data/mismatch_mild.pl"], "mismatch_strong": ["data/mismatch_strong.pl"]}
PROLOG_SPLITS = {"holdout": ["holdout"], "five_seeds": ["holdout"] + [f"seed{s}" for s, _ in NEW_SEEDS],
                 "mismatch_mild": ["mismatch_mild"], "mismatch_strong": ["mismatch_strong"]}
ES_MODES = ["ded_abd", "full"]


def generate_training():
    os.makedirs(os.path.join(ROOT, "data", "baseline"), exist_ok=True)
    for seed, prefix in TRAIN_SEEDS:
        base = os.path.join("data", "baseline", f"train_{seed}")
        if os.path.exists(base + ".csv") and os.path.exists(base + ".json"):
            continue
        subprocess.run([sys.executable, "-I", "simulator/dc_sim.py", "--seed", str(seed), "--prefix", prefix,
                        "--split", "train", "--out", base + ".pl", "--csv", base + ".csv", "--truth", base + ".json"],
                       cwd=ROOT, check=True, capture_output=True, text=True)


def load(pairs):
    """Returns a list of (case id, category, readings dict, expected label list)."""
    out = []
    for csv_path, truth_path in pairs:
        readings = {}
        with open(os.path.join(ROOT, csv_path), encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                v = row["value"]
                if row["variable"] == "ups_mode":
                    x = 1.0 if v == "bypass" else 0.0
                else:
                    try:
                        x = float(v)
                    except ValueError:
                        continue
                readings.setdefault(row["case_id"], {})[(row["variable"], row["entity"])] = x
        with open(os.path.join(ROOT, truth_path), encoding="utf-8") as fh:
            truth = json.load(fh)["cases"]
        for c in truth:
            out.append((c["id"], c["category"], readings.get(c["id"], {}), sorted(c["expected"])))
    return out


def matrix(cases, columns):
    X = np.full((len(cases), len(columns)), np.nan)
    index = {k: j for j, k in enumerate(columns)}
    for i, (_, _, r, _) in enumerate(cases):
        for k, x in r.items():
            j = index.get(k)
            if j is not None:
                X[i, j] = x
    return X


def fit(model, train):
    """Fits the model once; returns predict(test) -> label lists, and the labels seen in training."""
    columns = sorted({k for _, _, r, _ in train for k in r})
    labels = sorted({l for *_, e in train for l in e if l != "normal"})
    Y = np.array([[1 if l in e else 0 for l in labels] for *_, e in train])
    model.fit(matrix(train, columns), Y)

    def predict(test):
        P = np.atleast_2d(model.predict(matrix(test, columns)))
        return [sorted(l for l, y in zip(labels, row) if y) or ["normal"] for row in P]
    return predict, set(labels)


def expert_rows():
    """(test set, case id, mode) -> 1/0, from the Prolog system on the same cases."""
    rows = {}
    for ts in TEST_SETS:
        files = ", ".join(f"'{f}'" for f in PROLOG_FILES[ts])
        splits = ", ".join(PROLOG_SPLITS[ts])
        goal = ((f"load_files([{files}], []), " if files else "")
                + f"forall(( member(Sp, [{splits}]), case_split(C, Sp), member(M, [{', '.join(ES_MODES)}]) ), "
                f"( expected(C, E0), msort(E0, E), diagnose_mode(M, C, G0), msort(G0, G), "
                f"( E == G -> O = 1 ; O = 0 ), format(\"ROW ~w ~w ~w~n\", [C, M, O]) ))")
        out = subprocess.run([swipl(), "-q", "-g", goal, "-t", "halt", "main.pl"],
                             cwd=ROOT, check=True, capture_output=True, text=True).stdout
        for line in out.splitlines():
            if line.startswith("ROW "):
                _, c, m, ok = line.split()
                rows[(ts, c, m)] = int(ok)
    return rows


MODELS = {
    "forest": ("Random forest", lambda: RandomForestClassifier(n_estimators=300, random_state=0, n_jobs=-1)),
    "tree": ("Decision tree", lambda: DecisionTreeClassifier(random_state=0)),
}
REGIMES = {"cal": "calibration, 255 cases", "big": "2550 extra simulated cases"}
CATEGORIES = ["normal", "single_fault", "instrumentation", "multiple", "incomplete", "borderline", "noisy"]


def main():
    generate_training()
    train = {"cal": load([("data/generated_cases.csv", "data/generated_truth.json")]),
             "big": load([(f"data/baseline/train_{s}.csv", f"data/baseline/train_{s}.json") for s, _ in TRAIN_SEEDS])}
    tests = {ts: load(pairs) for ts, pairs in TEST_SETS.items()}
    es = expert_rows()

    ok = {}        # (model, regime, test set) -> list of 0/1 in test-case order
    unseen = {}    # (regime, test set) -> cases with a true label never seen in training
    hold_preds = {}
    for regime, tr in train.items():
        for mk, (_, make) in MODELS.items():
            predict, seen = fit(make(), tr)
            for ts, te in tests.items():
                preds = predict(te)
                ok[(mk, regime, ts)] = [int(p == e) for p, (*_, e) in zip(preds, te)]
                unseen[(regime, ts)] = sum(1 for *_, e in te if any(l != "normal" and l not in seen for l in e))
                if ts == "holdout":
                    hold_preds[(mk, regime)] = preds
    es_ok = {(m, ts): [es[(ts, c, m)] for c, *_ in te] for m in ES_MODES for ts, te in tests.items()}

    # ---- outputs -------------------------------------------------------------
    pct = lambda xs: 100 * sum(xs) / len(xs)
    md = ["# Data-Driven Baseline", "",
          "Generated by `tests/baseline.py`. Do not edit by hand. Every case is synthetic. For comparison only: the "
          "classifiers are not part of the expert system.", "",
          "Features: every raw reading of a case, missing readings as NaN. Labels: binary relevance over the fault "
          "labels seen in training; no predicted fault means normal. Random forest: 300 trees, seed 0.", "",
          "## Exact match", "",
          "| System | Training data | " + " | ".join(TEST_NAMES[t] for t in TEST_SETS) + " |",
          "|---" * (len(TEST_SETS) + 2) + "|"]
    for m in ES_MODES:
        md.append(f"| Expert system: {MODE_NAMES[m]} | none (knowledge base) | "
                  + " | ".join(f"{sum(es_ok[(m, t)])} of {len(tests[t])} ({pct(es_ok[(m, t)]):.1f}%)" for t in TEST_SETS) + " |")
    for regime, rname in REGIMES.items():
        for mk, (mname, _) in MODELS.items():
            md.append(f"| {mname} | {rname} | "
                      + " | ".join(f"{sum(ok[(mk, regime, t)])} of {len(tests[t])} ({pct(ok[(mk, regime, t)]):.1f}%)"
                                   for t in TEST_SETS) + " |")
    md += ["", "## Test cases with a true label never seen in training", "",
           "| Training data | " + " | ".join(TEST_NAMES[t] for t in TEST_SETS) + " |", "|---" * (len(TEST_SETS) + 1) + "|"]
    for regime, rname in REGIMES.items():
        md.append(f"| {rname} | " + " | ".join(str(unseen[(regime, t)]) for t in TEST_SETS) + " |")

    md += ["", "## Paired comparison with the expert system", "",
           "Exact two-sided McNemar test. Only ES: cases the expert system gets right and the classifier wrong.", "",
           "| Classifier | Expert-system mode | Test set | Only ES | Only classifier | p |", "|---|---|---|---|---|---|"]
    sig = {}
    for regime in REGIMES:
        for m in ES_MODES:
            for t in TEST_SETS:
                a, b, p = mcnemar(es_ok[(m, t)], ok[("forest", regime, t)])
                sig[(regime, m, t)] = (a, b, p)
                md.append(f"| Random forest, {REGIMES[regime]} | {MODE_NAMES[m]} | {TEST_NAMES[t]} | {a} | {b} | {p_text(p)} |")

    md += ["", "## Held-out exact match by category", "",
           "| Category | Cases | Deductive + abductive | Random forest, calibration | Random forest, 2550 cases |",
           "|---|---|---|---|---|"]
    te = tests["holdout"]
    for k in CATEGORIES:
        idx = [i for i, (_, cat, _, _) in enumerate(te) if cat == k]
        cells = [sum(es_ok[("ded_abd", "holdout")][i] for i in idx),
                 sum(ok[("forest", "cal", "holdout")][i] for i in idx),
                 sum(ok[("forest", "big", "holdout")][i] for i in idx)]
        md.append(f"| {k} | {len(idx)} | " + " | ".join(str(c) for c in cells) + " |")
    with open(os.path.join(ROOT, "docs", "17_baseline_comparison.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(md) + "\n")

    short = {"holdout": "Held-out", "five_seeds": "Five seeds", "mismatch_mild": "Mild mismatch",
             "mismatch_strong": "Strong mismatch"}
    tex = ["% Generated by tests/baseline.py. Do not edit by hand.",
           f"{BS}begin{{table}}[htbp]", f"  {BS}centering", f"  {BS}footnotesize", f"  {BS}setlength{{{BS}tabcolsep}}{{4pt}}",
           f"  {BS}caption{{Exact match of the expert system and of data-driven classifiers trained on the raw readings, "
           f"on the same test cases ({len(tests['holdout'])} held-out, {len(tests['five_seeds'])} over five seeds, "
           f"{len(tests['mismatch_mild'])} per mismatch profile). The classifiers are a baseline for comparison only. "
           f"Bold: significantly different from deductive + abductive reasoning on the same cases "
           f"(exact McNemar, $p < 0.05$). Details in {BS}texttt{{docs/17{BS}_baseline{BS}_comparison.md}}.}}",
           f"  {BS}label{{tab:baseline}}",
           f"  {BS}begin{{tabular}}{{L{{3.5cm}}L{{3.0cm}}rrrr}}", f"  {BS}toprule",
           "  System & Training data & " + " & ".join(short[t] for t in TEST_SETS) + f" {BS}{BS}", f"  {BS}midrule"]
    for m in ES_MODES:
        tex.append(f"  {MODE_NAMES[m]} & none & " + " & ".join(f"{pct(es_ok[(m, t)]):.1f}" for t in TEST_SETS) + f" {BS}{BS}")
    tex.append(f"  {BS}midrule")
    for regime, rname in REGIMES.items():
        for mk, (mname, _) in MODELS.items():
            cells = []
            for t in TEST_SETS:
                _, _, p = mcnemar(es_ok[("ded_abd", t)], ok[(mk, regime, t)])
                v = f"{pct(ok[(mk, regime, t)]):.1f}"
                cells.append(f"{BS}textbf{{{v}}}" if p < 0.05 else v)
            tex.append(f"  {mname} & {rname.replace('2550 extra simulated cases', '2550 extra cases').replace('calibration, 255 cases', 'calibration (255)')} & "
                       + " & ".join(cells) + f" {BS}{BS}")
    tex += [f"  {BS}bottomrule", f"  {BS}end{{tabular}}", f"{BS}end{{table}}", ""]
    with open(os.path.join(ROOT, "report", "tables", "eval_baseline.tex"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(tex))

    summary = {f"{mk}|{r}|{t}": sum(v) for (mk, r, t), v in ok.items()}
    summary.update({f"es_{m}|{t}": sum(v) for (m, t), v in es_ok.items()})
    print("JSON " + json.dumps(summary, sort_keys=True))
    for line in md[7:7 + 2 + len(ES_MODES) + len(REGIMES) * len(MODELS)]:
        print(line)
    print("unseen:", {f"{r}|{t}": n for (r, t), n in unseen.items()})
    for (r, m, t), (a, b, p) in sig.items():
        print(f"forest {r:3} vs {m:7} {t:15} only ES {a:3} only RF {b:3} p {p_text(p)}")


if __name__ == "__main__":
    main()
