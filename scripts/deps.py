"""Fetch exact development dependencies without altering existing checkouts."""
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
for name, dep in json.loads((root / "deps-lock.json").read_text()).items():
    dest = root / ".deps" / name
    if not dest.exists():
        subprocess.run(["git", "clone", "--no-checkout", dep["url"], str(dest)], check=True)
        subprocess.run(["git", "-C", str(dest), "checkout", "--detach", dep["commit"]], check=True)
    actual = subprocess.check_output(["git", "-C", str(dest), "rev-parse", "HEAD"], text=True).strip()
    if actual != dep["commit"]:
        raise SystemExit(f"{dest}: expected {dep['commit']}, found {actual}")
    dirty = subprocess.check_output(["git", "-C", str(dest), "status", "--porcelain"], text=True)
    if dirty:
        raise SystemExit(f"{dest}: dependency has local changes")
