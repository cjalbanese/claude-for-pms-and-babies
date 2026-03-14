# Claude Code for PMs and Babies

Explains what Claude Code is doing in plain English. Viciously condescending. Aggressively infantilizing. Technically accurate.

For dumb baby product managers, non-technical founders, curious bystanders, and anyone who has ever looked at a terminal and felt fear.

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
› First command: git. Version control. It tracks every change, unlike your meeting notes, which track nothing.
```

```
› .env file. Passwords and secrets live here. If you commit this to GitHub, you'll be on the news. The bad kind.
```

```
› Opened routes.ts, found the issue, fixed it. What you'd call an 'epic' Claude calls 'Tuesday afternoon.'
```

```
› Three edits in a row. Claude is in flow state. You don't know what that is because Slack exists.
```

```
› Oopsie! Something went boom. Don't cry. Claude will fix it. You just sit there.
```

```
› 47 actions. You contributed zero of them. Good job supervising.
```

## How it works

Three hooks, each with a job:

| Hook | When | What |
|------|------|------|
| PostToolUse | After every action | Explains what just happened |
| PostToolUseFailure | After errors | Talks down to you (lovingly) |
| Stop | End of each turn | Summarizes what was accomplished |

## Message frequency

- **First 10 actions**: Always explains (onboarding you)
- **10-50**: ~50% of actions
- **50+**: ~30% of actions
- **3+ consecutive same tool**: ~20% (avoids the "12 web searches, 12 messages" problem)
- **Always shows**: First occurrence of each tool, errors, path-aware commentary, pattern observations

## What it covers

**250+ unique messages** across:

- **Read/Edit/Write/Bash/Grep/Glob/Agent/WebSearch/WebFetch/ToolSearch** — tool-specific explanations
- **40+ specific commands** — git commit, npm install, pytest, docker, curl, ssh, rm -rf, gcloud, and more
- **Smart first-time Bash** — detects what the first command actually does (git, install, cloud CLI, etc.)
- **Path-aware commentary** — legacy code, config files, .env, tests, utils, migrations, package.json, README
- **Read-then-edit detection** — notices when Claude reads and edits the same file
- **Edit streaks** — calls out 3/5/8+ consecutive edits ("Claude is in the zone")
- **Time-aware commentary** — rewards you for still watching at 60/80/120/150 actions
- **Pattern detection** — reads without edits, Write→Edit, retries after failure, session milestones
- **Consecutive-tool suppression** — won't spam the same message 12 times during a search burst
- **20 failure messages** — permission denied, command not found, timeouts, retries, generic errors
- **15 turn summaries** — end-of-response recaps with actual stats

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main/uninstall.sh | bash
```

## License

MIT
