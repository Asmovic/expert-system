"""One-command reproduction check for the data centre expert system.

Run from the project folder:

    python tests/reproduce.py            # check datasets and every result
    python tests/reproduce.py --tables   # also regenerate the report tables
    python tests/reproduce.py --baseline # also check the data-driven baseline (needs scikit-learn)

It does five things and prints PASS or FAIL for each:

  1. Regenerates the calibration and held-out datasets from their seeds into
     a temporary folder, and checks that they are byte-identical to the
     files in data/ and to the SHA-256 checksums recorded below, apart
     from the header comment on line 1.
  2. Runs the deductive test suite and checks the exact-match counts.
  3. Runs all four reasoning modes on every split, on the model-mismatch
     splits and on four extra held-out seeds, and checks the counts.
  4. Runs the explanation-fidelity test and checks its counts, and checks
     that at least 40 of the 60 equations are used by the code.
  5. With --tables, regenerates every generated table used by the report.

Python only generates data and compares results. All diagnosis runs in Prolog.
Exit code 0 means everything reproduced.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXPECTED_SHA256 = {
    # SHA-256 of each file after its first line. Line 1 is a header comment that
    # records where the file was written, so it differs for a temporary copy.
    "generated_cases.pl": "639bf254e013f333ccd96757ea3790270c3d0633b1f5a9ab637f248a20fc4608",
    "holdout_cases.pl":   "d9f4847bfdef6313866353d39fd2213c55dfb8b182b55581fea8da52d52ea8cc",
}

# Exact-match counts: split -> mode -> (correct, cases)
EXPECTED_COUNTS = {
    "smoke":       {"deductive": (4, 4),     "ded_abd": (4, 4),     "ded_cbd": (4, 4),     "full": (4, 4)},
    "calibration": {"deductive": (230, 255), "ded_abd": (238, 255), "ded_cbd": (234, 255), "full": (238, 255)},
    "holdout":     {"deductive": (232, 255), "ded_abd": (241, 255), "ded_cbd": (238, 255), "full": (239, 255)},
}

DATASETS = [
    # file name, seed, prefix, split
    ("generated_cases.pl", 20261020, "g", "calibration"),
    ("holdout_cases.pl",   777,      "h", "holdout"),
]


def swipl():
    exe = shutil.which("swipl")
    if exe:
        return exe
    fallback = r"C:\Program Files\swipl\bin\swipl.exe"
    if os.path.exists(fallback):
        return fallback
    sys.exit("swipl not found: install SWI-Prolog 10.0.2 or later and put it on PATH")


def run_prolog(goals, extra_files=()):
    cmd = [swipl(), "-q"]
    for g in goals:
        cmd += ["-g", g]
    cmd += ["-t", "halt", "main.pl", *extra_files]
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=True).stdout


def sha256(path):
    """SHA-256 of the file after its first line (the header comment)."""
    with open(path, "rb") as fh:
        fh.readline()
        return hashlib.sha256(fh.read()).hexdigest()


def check_datasets(results):
    with tempfile.TemporaryDirectory() as tmp:
        for name, seed, prefix, split in DATASETS:
            out = os.path.join(tmp, name)
            subprocess.run([sys.executable, "-I", os.path.join(ROOT, "simulator", "dc_sim.py"),
                            "--seed", str(seed), "--prefix", prefix, "--split", split,
                            "--out", out, "--csv", os.path.join(tmp, name + ".csv"),
                            "--truth", os.path.join(tmp, name + ".json")],
                           cwd=ROOT, capture_output=True, text=True, check=True)
            regenerated = sha256(out)
            on_disk = sha256(os.path.join(ROOT, "data", name))
            ok = regenerated == on_disk == EXPECTED_SHA256[name]
            results.append((f"dataset {name} regenerates byte-identically (seed {seed})", ok,
                            f"regenerated {regenerated[:12]}, on disk {on_disk[:12]}, "
                            f"expected {EXPECTED_SHA256[name][:12]}"))


def check_counts(results):
    goals = [f"sweep_metrics({split})" for split in EXPECTED_COUNTS]
    out = run_prolog(goals, ["tests/metrics.pl", "tests/sensitivity.pl"])
    rows = [json.loads(line[5:]) for line in out.splitlines() if line.startswith("JSON ")]
    i = 0
    for split, modes in EXPECTED_COUNTS.items():
        for mode, (want, n) in modes.items():
            r = rows[i]
            i += 1
            got = round(r["exact"] * r["n"])
            ok = r["mode"] == mode and r["n"] == n and got == want
            results.append((f"{split:11} {mode:9} exact match {want}/{n}", ok, f"got {got}/{r['n']}"))


# Model-mismatch experiment (tests/mismatch.py): split -> mode -> correct of 255.
EXPECTED_MISMATCH = {
    "mismatch_mild":           {"deductive": 206, "ded_abd": 232, "ded_cbd": 220, "full": 230},
    "mismatch_strong":         {"deductive": 67,  "ded_abd": 102, "ded_cbd": 86,  "full": 101},
    "mismatch_strong_rebased": {"deductive": 192, "ded_abd": 212, "ded_cbd": 213, "full": 210},
}


def check_mismatch(results):
    sys.path.insert(0, os.path.join(ROOT, "tests"))
    import mismatch
    os.chdir(ROOT)
    mismatch.generate()
    rows = mismatch.diagnose()
    rows.pop("offsets", None)
    for split, modes in EXPECTED_MISMATCH.items():
        for mode, want in modes.items():
            got = sum(ok for (sp, _, m), (_, ok) in rows.items() if sp == split and m == mode)
            results.append((f"{split:23} {mode:9} exact match {want}/255", got == want, f"got {got}/255"))


# Explanation fidelity (tests/fidelity.pl), held-out split:
# mode -> (fault labels, labels lost when their cited evidence is removed, labels kept in the control).
EXPECTED_FIDELITY = {
    "deductive": (277, 265, 277), "ded_abd": (250, 250, 250),
    "ded_cbd":   (263, 263, 263), "full":    (256, 256, 255),
}


def check_fidelity(results, tables):
    # fidelity.pl loads main.pl itself, because obs/4 must be declared dynamic first.
    with tempfile.TemporaryDirectory() as tmp:
        md = "docs/13_explanation_fidelity.md" if tables else os.path.join(tmp, "f.md").replace(os.sep, "/")
        tex = "report/tables" if tables else tmp.replace(os.sep, "/")
        out = subprocess.run([swipl(), "-q", "-g", f"fidelity_report('{md}', '{tex}')", "-t", "halt",
                              "tests/fidelity.pl"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    rows = {r["mode"]: r for r in (json.loads(line[5:]) for line in out.splitlines() if line.startswith("JSON "))}
    for mode, want in EXPECTED_FIDELITY.items():
        r = rows.get(mode, {})
        got = (r.get("labels"), r.get("necessity"), r.get("control"))
        results.append((f"fidelity    {mode:9} labels, necessity, control {want}", got == want, f"got {got}"))


# Five held-out seeds (tests/seeds.py): mode -> correct of 1275, pooled.
EXPECTED_SEEDS = {"deductive": 1158, "ded_abd": 1193, "ded_cbd": 1172, "full": 1184}


def check_seeds(results):
    out = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "seeds.py")],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    pooled = json.loads(next(line[5:] for line in out.splitlines() if line.startswith("JSON ")))["pooled"]
    for mode, want in EXPECTED_SEEDS.items():
        results.append((f"five seeds  {mode:9} exact match {want}/1275", pooled.get(mode) == want,
                        f"got {pooled.get(mode)}/1275"))


# Data-driven baseline (tests/baseline.py), only with --baseline because it needs
# scikit-learn: key -> exact matches.
EXPECTED_BASELINE = {"tree|big|holdout": 228, "tree|big|five_seeds": 1111, "forest|big|holdout": 209,
                     "forest|cal|holdout": 136, "tree|big|mismatch_mild": 128}


def check_baseline(results):
    # Not run with -I: scikit-learn may be installed in the user site-packages.
    proc = subprocess.run([sys.executable, os.path.join(ROOT, "tests", "baseline.py")],
                          cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        results.append(("baseline    runs (needs scikit-learn)", False, proc.stderr.strip().splitlines()[-1]))
        return
    got = json.loads(next(line[5:] for line in proc.stdout.splitlines() if line.startswith("JSON ")))
    for key, want in EXPECTED_BASELINE.items():
        results.append((f"baseline    {key} exact match {want}", got.get(key) == want, f"got {got.get(key)}"))


def check_equations(results):
    # tests/equation_usage.py always rewrites its table, which only depends on the code.
    out = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "equation_usage.py")],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    r = json.loads(next(line[5:] for line in out.splitlines() if line.startswith("JSON ")))
    ok = r["equations"] == 60 and r["used"] >= 40
    results.append(("equations   60 tagged, at least 40 used by the code", ok,
                    f"got {r['equations']} tagged, {r['used']} used, {r['reasoning']} in the reasoning"))


def regenerate_tables(results):
    run_prolog(["export_latex_tables('report/tables')"], ["tests/export_latex.pl"])
    run_prolog(["export_rules('docs/07_rule_table.md')"], ["tests/export_rules.pl"])
    run_prolog(["evaluation_all('docs/08_evaluation_results.md', 'report/tables')"],
               ["tests/metrics.pl", "tests/metrics_latex.pl"])
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "sensitivity.py"), "--tables-only"],
                   cwd=ROOT, capture_output=True, text=True, check=True)
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "mismatch.py")],
                   cwd=ROOT, capture_output=True, text=True, check=True)
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "param_sensitivity.py")],
                   cwd=ROOT, capture_output=True, text=True, check=True)
    results.append(("report tables regenerated", True, "report/tables and docs/07, docs/08"))


def main():
    results = []
    print("Reproducing the data centre expert system results...\n")
    check_datasets(results)
    check_counts(results)
    check_mismatch(results)
    check_fidelity(results, "--tables" in sys.argv)
    check_seeds(results)
    check_equations(results)
    if "--baseline" in sys.argv:
        check_baseline(results)
    if "--tables" in sys.argv:
        regenerate_tables(results)
    width = max(len(name) for name, _, _ in results)
    for name, ok, detail in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {name:{width}}  {detail}")
    failed = [r for r in results if not r[1]]
    print(f"\n{len(results) - len(failed)} of {len(results)} checks passed.")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
