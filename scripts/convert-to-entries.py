#!/usr/bin/env python3
"""Convert a WORKLOG-style mdgraph vault to one file per entry.

Refuses to run on a dirty vault, backs up before touching anything, verifies the
entry count round-trips, and leaves the WORKLOG in place unless --remove-log is
passed AND verification passed.

    python3 convert-to-entries.py <vault> [--apply] [--remove-log]

Without --apply it prints what it would do and writes nothing.
"""
import argparse, os, re, subprocess, sys, tarfile, time
from pathlib import Path

HEAD = re.compile(r'(?m)^## (\d{4}-\d{2}-\d{2})\s+[—-]\s+(.+?)\s*$')

def slugify(t, taken):
    s = re.sub(r'[^a-z0-9]+', '-', t.lower()).strip('-')[:60].rstrip('-') or "entry"
    base, n = s, 2
    while s in taken:
        s = f"{base}-{n}"; n += 1
    taken.add(s); return s

def git(vault, *a):
    return subprocess.run(["git", "-C", str(vault), *a],
                          capture_output=True, text=True).stdout.strip()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vault"); ap.add_argument("--apply", action="store_true")
    ap.add_argument("--remove-log", action="store_true")
    a = ap.parse_args()
    v = Path(a.vault).resolve()
    if not v.is_dir(): sys.exit(f"not a directory: {v}")

    logs = sorted(v.glob("WORKLOG*.md"))
    if not logs: sys.exit("no WORKLOG*.md here — already converted, or not a vault")

    # 1. refuse on a dirty vault: another session may have uncommitted entries
    dirty = git(v, "status", "--porcelain")
    if dirty:
        sys.exit("REFUSING: vault has uncommitted changes. Another session may be "
                 "mid-write. Commit or coordinate first.\n" + dirty)

    # 2. parse
    taken, plan = set(), []
    for log in logs:
        text = log.read_text(encoding="utf8", errors="replace")
        marks = list(HEAD.finditer(text))
        for i, m in enumerate(marks):
            body = text[m.end():marks[i+1].start() if i+1 < len(marks) else len(text)]
            plan.append((slugify(m.group(2), taken), m.group(1), m.group(2), body.strip("\n")))
    # every '## ' line the pattern did not claim: a template, a stray heading, a
    # mid-entry subsection. Silence here would be a lost entry nobody notices.
    skipped = []
    for log in logs:
        for line in log.read_text(encoding="utf8", errors="replace").splitlines():
            if line.startswith("## ") and not HEAD.match(line):
                skipped.append(f"{log.name}: {line[:70]}")
    print(f"  {len(logs)} log(s) -> {len(plan)} entries")
    if skipped:
        print(f"  {len(skipped)} '## ' line(s) NOT converted — check each is a template, not an entry:")
        for x in skipped: print(f"    ! {x}")
    if not a.apply:
        for s, d, desc, _ in plan[:5]: print(f"    {s}.md  ({d})  {desc[:60]}")
        print(f"    ... dry run, nothing written. Re-run with --apply")
        return

    # 3. BACK UP: a commit plus a tarball outside the vault
    stamp = time.strftime("%Y%m%d-%H%M%S")
    bdir = Path.home() / "backups" / "mdgraph-preconvert"; bdir.mkdir(parents=True, exist_ok=True)
    tar = bdir / f"{v.name}-{stamp}.tar.gz"
    with tarfile.open(tar, "w:gz") as t:
        t.add(v, arcname=v.name, filter=lambda ti: None if "/.git/" in ti.name else ti)
    print(f"  backup: {tar} ({tar.stat().st_size//1024} KB)")
    head = git(v, "rev-parse", "HEAD")
    print(f"  vault HEAD before: {head}")

    # 4. write entries
    for s, d, desc, body in plan:
        f = v / f"{s}.md"
        if f.exists(): sys.exit(f"REFUSING: {f} already exists")
        f.write_text(f"---\ndescription: {desc}\ndate: {d}\n---\n\n{body}\n", encoding="utf8")

    # 5. verify before removing anything
    written = sum(1 for s, _, _, _ in plan if (v / f"{s}.md").is_file())
    print(f"  verify: {written}/{len(plan)} entry files present")
    if written != len(plan):
        sys.exit("VERIFY FAILED — logs left untouched, backup at " + str(tar))

    if a.remove_log:
        for log in logs: log.unlink()
        print(f"  removed {len(logs)} log file(s) — recover from {tar} or git {head}")
    else:
        print("  logs kept. Re-run with --remove-log once you have eyeballed the entries.")

if __name__ == "__main__":
    main()
