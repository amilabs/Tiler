# Clamshell spike (task 0.2)

Measures whether public power assertions hold a lid-closed MacBook awake on
macOS 26 (the no-root path for the "keep awake with lid closed" session option).

```sh
cd openspec/changes/add-power-control/spike
swift clamshell_spike.swift selftest   # tooling sanity, no lid action needed
swift clamshell_spike.swift battery    # on battery: close lid ~2 min, reopen
swift clamshell_spike.swift ac         # on AC:      close lid ~2 min, reopen

sudo pmset -a disablesleep 1           # root fallback path, on battery:
swift clamshell_spike.swift fallback   #   close lid ~2 min, reopen
sudo pmset -a disablesleep 0           #   ALWAYS restore afterwards
```

Each run writes `spike-<phase>-<time>.log` with a `VERDICT:` line
(STAYED AWAKE / SLEPT / AMBIGUOUS / TOO-SHORT / NOT-RUN), the heartbeat gaps,
`pmset -g assertions` proof, and a `pmset -g log` sleep/wake excerpt.
Keep the Mac on a hard surface, not in a bag. Results are protocoled in
`../design.md`; spike logs are transient evidence (gitignored).
