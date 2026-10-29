"""Build the files to upload for submission.

    python tests/package_submission.py           # package the current state
    python tests/package_submission.py --check   # run tests/reproduce.py first

Writes to ../Submission (next to the project folder):
    Asogba_259047013_SSG816_Report.pdf    the report, report/main.pdf
    Asogba_259047013_SSG816_Code.zip      every tracked file, including
                                          uncommitted edits to them
    Asogba_259047013_SSG816_EndNote.enlx  the EndNote library

Untracked and ignored files (LaTeX build files, regenerated datasets, the
working EndNote library) are left out; README.md explains how to regenerate
the datasets.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(os.path.dirname(ROOT), "Submission")
STEM = "Asogba_259047013_SSG816"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def main():
    if "--check" in sys.argv:
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tests", "reproduce.py")], cwd=ROOT)
        if r.returncode != 0:
            sys.exit("reproduce.py failed; nothing packaged")

    os.makedirs(OUT, exist_ok=True)
    # A stash commit snapshots uncommitted edits to tracked files without
    # touching the working tree or the branch.
    tree = git("stash", "create") or "HEAD"
    zip_path = os.path.join(OUT, STEM + "_Code.zip")
    git("archive", "--format=zip", "--prefix=dc-expert-system/", "-o", zip_path, tree)

    shutil.copyfile(os.path.join(ROOT, "report", "main.pdf"), os.path.join(OUT, STEM + "_Report.pdf"))
    shutil.copyfile(os.path.join(ROOT, "report", "dc-expert-system.enlx"), os.path.join(OUT, STEM + "_EndNote.enlx"))

    for name in sorted(os.listdir(OUT)):
        size = os.path.getsize(os.path.join(OUT, name))
        print(f"{size / 1e6:6.1f} MB  {os.path.join(OUT, name)}")


if __name__ == "__main__":
    main()
