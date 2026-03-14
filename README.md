# Claude Code for PMs and Babies

Explains what Claude Code is doing in plain English. Viciously condescending. Relentlessly roasting. Technically accurate.

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
› Docker failed. Containers are hard. You said 'just containerize it' in a meeting once. This is what that costs.
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

**350+ unique messages** across:

- **Read/Edit/Write/Bash/Grep/Glob/Agent/WebSearch/WebFetch/ToolSearch** — tool-specific roasts
- **40+ specific commands** — git commit, npm install, pytest, docker, curl, ssh, rm -rf, kubectl, gh, and more
- **Personalized digs** — extracts package names, URLs, branch names, grep patterns, file types, and domains from actual tool input to roast you specifically
- **25+ path-aware triggers** — legacy code, .env, config, tests, migrations, auth, middleware, schema, routes, Dockerfile, CI/CD, .lock files, and more
- **9 file extension roasts** — TypeScript, Python, Go, Rust, Ruby, SQL, shell, JSON, YAML each get targeted commentary
- **Smart first-time Bash** — detects what the first command actually does (git, install, cloud CLI, etc.)
- **Read-then-edit detection** — notices when Claude reads and edits the same file
- **Edit streaks** — calls out 3/5/8/12+ consecutive edits ("Claude is in the zone")
- **Personalized failures** — detects npm, docker, git push, curl, pip, ssh, terraform, and test failures with specific burns
- **HTTP error detection** — 403, 404, 500, rate limits, ECONNREFUSED, ENOENT, syntax errors
- **Time-aware commentary** — roasts you for still watching at 40/60/80/120/150/175 actions
- **Pattern detection** — reads without edits, Grep→Edit, Write→Edit, retries after failure, consecutive read streaks
- **Personalized stop summaries** — analyzes session composition (error-heavy, read-only, search-heavy, edit-heavy, sub-agent usage) for targeted recaps
- **Consecutive-tool suppression** — won't spam the same message 12 times during a search burst
- **15 turn summaries** — end-of-response recaps with actual stats

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main/uninstall.sh | bash
```

## License

MIT
