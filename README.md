# Claude Code for PMs and Babies

Explains what Claude Code is doing in plain English. Gently condescending. Mildly infantilizing. Informative.

For product managers, non-technical founders, curious bystanders, and anyone who has ever looked at a terminal and felt fear.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main/install.sh | bash
```

Or as a Claude Code plugin:

```bash
claude plugin install /path/to/claude-for-pms
```

Requires [jq](https://jqlang.github.io/jq/) (`brew install jq`).

## What you'll see

Subtle colored annotations after Claude's actions:

```
› Claude is reading server.ts. The whole thing. Without skimming. Imagine.
```

```
› Installing dependencies. Code by strangers your product relies on. Try not to think about it.
```

```
› git blame. Checks who wrote each line. Yes, it's really called 'blame.' HR was not consulted.
```

```
› Something broke. Normal. If everything worked first try, we wouldn't need sprints.
```

```
› 47 actions. Zero meetings. All progress was actual progress.
```

## How it works

Three hooks, each with a job:

| Hook | When | What |
|------|------|------|
| PostToolUse | After every action | Explains what just happened |
| PostToolUseFailure | After errors | Reassures you (condescendingly) |
| Stop | End of each turn | Summarizes what was accomplished |

## Message frequency

- **First 10 actions**: Always explains (onboarding you)
- **10-50**: ~50% of actions
- **50+**: ~30% of actions
- **Always shows**: First occurrence of each tool, errors, pattern-based observations

## What it covers

**200+ unique messages** across:

- **Read/Edit/Write/Bash/Grep/Glob/Agent/WebSearch** — tool-specific explanations
- **40+ specific commands** — git commit, npm install, pytest, docker, curl, ssh, rm -rf, and more
- **Path-aware commentary** — legacy code, config files, .env files, test files, utils
- **Pattern detection** — reads without edits, immediate re-edits, retries after failure, session milestones
- **20 failure messages** — permission denied, command not found, timeouts, generic errors
- **15 turn summaries** — end-of-response recaps

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main/uninstall.sh | bash
```

## License

MIT
