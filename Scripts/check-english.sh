#!/bin/zsh
# English-artifacts gate (public repo), run before every push: no Cyrillic in
# tracked files or in the messages of commits about to be pushed. Russian is
# fine in LOCAL working docs — untracked files stay invisible to this gate,
# and unpushed work only matters once it is about to go out. Unicode-aware on
# purpose — byte-interpreted Cyrillic ranges under BSD/git grep
# false-positive on em-dashes and arrows; python3 matches the real Cyrillic block.
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0

git ls-files -z | python3 -c '
import sys, re
pat = re.compile("[\\u0400-\\u04FF]")
bad = 0
for raw in sys.stdin.buffer.read().split(b"\0"):
    if not raw:
        continue
    path = raw.decode()
    try:
        with open(path, encoding="utf-8") as fh:
            for i, line in enumerate(fh, 1):
                if pat.search(line):
                    print(f"{path}:{i}: {line.strip()[:120]}")
                    bad += 1
    except (UnicodeDecodeError, OSError):
        continue
sys.exit(1 if bad else 0)
' || FAIL=1

if git rev-parse --verify --quiet origin/main >/dev/null; then
    git log origin/main..HEAD --format='commit %h%n%s%n%b' | python3 -c '
import sys, re
pat = re.compile("[\\u0400-\\u04FF]")
bad = 0
cur = ""
for line in sys.stdin:
    if line.startswith("commit "):
        cur = line.split()[1]
        continue
    if pat.search(line):
        print(f"commit {cur}: {line.strip()[:120]}")
        bad += 1
sys.exit(1 if bad else 0)
' || FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
    echo "PASS: no Cyrillic in tracked files or outgoing commit messages"
else
    echo "FAIL: Cyrillic in the outgoing set — translate it (owner quotes: English, marked 'translated') or keep it local (untracked/unpushed) before pushing" >&2
fi
exit $FAIL
