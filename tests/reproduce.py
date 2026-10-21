"""One-command reproduction check for the data centre expert system.

Run from the project folder:

    python tests/reproduce.py            # check datasets and every result
    python tests/reproduce.py --tables   # also regenerate the report tables

It does four things and prints PASS or FAIL for each:

  1. Regenerates the calibration and held-out datasets from their seeds into
     a temporary folder, and checks that they are byte-identical to the
     files in data/ and to the SHA-256 checksums recorded below, apart
     from the header comment on line 1.
  2. Runs the deductive test suite and checks the exact-match counts.
  3. Runs all four reasoning modes on every split and checks the counts.
  4. With --tables, regenerates every generated table used by the report.

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


def regenerate_tables(results):
    run_prolog(["export_latex_tables('report/tables')"], ["tests/export_latex.pl"])
    run_prolog(["export_rules('docs/07_rule_table.md')"], ["tests/export_rules.pl"])
    run_prolog(["evaluation_all('docs/08_evaluation_results.md', 'report/tables')"],
               ["tests/metrics.pl", "tests/metrics_latex.pl"])
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tests", "sensitivity.py"), "--tables-only"],
                   cwd=ROOT, capture_output=True, text=True, check=True)
    results.append(("report tables regenerated", True, "report/tables and docs/07, docs/08"))


def main():
    results = []
    print("Reproducing the data centre expert system results...\n")
    check_datasets(results)
    check_counts(results)
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
