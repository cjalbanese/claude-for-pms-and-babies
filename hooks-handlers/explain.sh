#!/bin/bash
# Claude Code for PMs and Babies
# Explains what Claude Code is doing in plain English.
# Gently condescending. Mildly infantilizing. Informative.

DATA_DIR="$HOME/.claude-for-pms"
STATE_FILE="$DATA_DIR/state.json"
mkdir -p "$DATA_DIR"

# --- Colors ---
DIM='\033[2m'
ITALIC='\033[3m'
CYAN='\033[36m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

# Regular messages: dim italic cyan (subtle, like spinner text)
C_REG="${DIM}${ITALIC}${CYAN}"
# First-time / special: italic magenta
C_SPECIAL="${ITALIC}${MAGENTA}"
# Errors: dim italic yellow
C_ERR="${DIM}${ITALIC}${YELLOW}"
# Summaries: dim italic green
C_SUM="${DIM}${ITALIC}${GREEN}"
# Pattern-based: italic magenta
C_PAT="${ITALIC}${MAGENTA}"

# --- Initialize state ---
if [ ! -f "$STATE_FILE" ]; then
  cat > "$STATE_FILE" << 'INIT'
{
  "total_tools": 0,
  "tools_seen": {},
  "last_tools": [],
  "last_tool_files": [],
  "session_failures": 0,
  "last_failed_cmd": "",
  "reads_without_edit": 0,
  "session_reads": 0,
  "session_edits": 0,
  "session_writes": 0,
  "session_bash": 0,
  "session_greps": 0,
  "session_agents": 0
}
INIT
fi

# --- Read input ---
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [ -z "$EVENT" ]; then
  exit 0
fi

STATE=$(cat "$STATE_FILE")
TOTAL=$(echo "$STATE" | jq -r '.total_tools')

# --- Helper: pick random message ---
pick() {
  local count=$1
  shift
  local idx=$((RANDOM % count))
  local i=0
  for msg in "$@"; do
    if [ $i -eq $idx ]; then
      echo "$msg"
      return
    fi
    i=$((i + 1))
  done
  echo "$1"
}

# --- Helper: extract filename from path ---
short_file() {
  local fp="$1"
  basename "$fp" 2>/dev/null || echo "$fp"
}

# ============================================================
# STOP EVENT — turn summary
# ============================================================
if [ "$EVENT" = "Stop" ]; then
  if [ "$TOTAL" -lt 3 ]; then
    exit 0
  fi

  SR=$(echo "$STATE" | jq -r '.session_reads')
  SE=$(echo "$STATE" | jq -r '.session_edits')
  SW=$(echo "$STATE" | jq -r '.session_writes')
  SB=$(echo "$STATE" | jq -r '.session_bash')
  SF=$(echo "$STATE" | jq -r '.session_failures')

  MSG=$(pick 15 \
    "$TOTAL actions. Zero meetings. All progress was actual progress." \
    "Turn done. ${SR} reads, ${SE} edits, ${SB} commands. Sprint complete." \
    "$TOTAL tool uses. Zero were 'circling back.' All were work." \
    "Done. Claude did in $TOTAL actions what normally takes a planning meeting, design review, and three Loom videos." \
    "Round complete. Every action produced a measurable outcome. Not a 'directional alignment.' An outcome." \
    "$TOTAL actions. If each were a Jira ticket, your backlog would be caught up." \
    "Turn over. $TOTAL tool calls. Standup version: 'Made progress. No blockers.' Done." \
    "$TOTAL operations. All real. All measurable. The burndown chart would love this." \
    "Fin. $TOTAL actions. No Gantt chart consulted. No dependency flagged. It just happened." \
    "That was $TOTAL actions. Each under a second. Your last retro took 90 minutes." \
    "Done. $TOTAL tools. Success rate higher than your last product launch." \
    "$TOTAL actions. No stakeholder alignment required. No async Loom recorded." \
    "Round complete. $TOTAL things done. Not 'discussed.' Not 'explored.' Done." \
    "Turn summary: $TOTAL actions. Ship it." \
    "That's a wrap. $TOTAL actions. Sprint velocity: yes."
  )

  jq -n --arg msg "$(printf '%b' "${C_SUM}› ${MSG}${RESET}")" '{"systemMessage": $msg}'

  # Reset counters for next turn
  echo "$STATE" | jq '.total_tools = 0 | .session_reads = 0 | .session_edits = 0 | .session_writes = 0 | .session_bash = 0 | .session_failures = 0 | .session_greps = 0 | .session_agents = 0 | .reads_without_edit = 0 | .last_tools = []' > "$STATE_FILE"
  exit 0
fi

# ============================================================
# FAILURE EVENT
# ============================================================
if [ "$EVENT" = "PostToolUseFailure" ]; then
  TOTAL=$((TOTAL + 1))
  FAILS=$(echo "$STATE" | jq -r '.session_failures')
  FAILS=$((FAILS + 1))

  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "something"')
  FAILED_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
  LAST_FAILED=$(echo "$STATE" | jq -r '.last_failed_cmd // ""')

  # Retry detection
  RETRY_MSG=""
  if [ -n "$FAILED_CMD" ] && [ "$FAILED_CMD" = "$LAST_FAILED" ]; then
    RETRY_MSG=$(pick 3 \
      "Same thing, second attempt. In your standup: 'iterating.'" \
      "Trying again. Not insanity. Debugging. There's a difference. Technically." \
      "Retry detected. Claude isn't giving up. It's 'pivoting the approach.' Sound familiar?"
    )
  fi

  if [ -n "$RETRY_MSG" ]; then
    MSG="$RETRY_MSG"
  else
    # Check for specific error types
    ERROR=$(echo "$INPUT" | jq -r '.error // ""')
    if echo "$ERROR" | grep -qi "permission denied"; then
      MSG=$(pick 2 \
        "Permission denied. The computer said 'you're not on the list.' Bouncer energy." \
        "Access denied. Like Confluence permissions, but the computer actually enforces them."
      )
    elif echo "$ERROR" | grep -qi "command not found"; then
      MSG=$(pick 2 \
        "Command not found. Like requesting a feature deprecated two quarters ago." \
        "Tool doesn't exist here. Like asking for that integration your vendor promised."
      )
    elif echo "$ERROR" | grep -qi "timeout"; then
      MSG=$(pick 2 \
        "Timeout. Something took too long. Unlike your all-hands, there IS a time limit." \
        "Timed out. The computer has patience limits. Enforced ones."
      )
    else
      MSG=$(pick 20 \
        "Something broke. Normal. If everything worked first try, we wouldn't need sprints." \
        "Error. Don't panic. Errors are feedback. Fast feedback. Unlike your last 360 review." \
        "That didn't work. Claude will fix it. Imagine if Slack outages resolved this fast." \
        "The computer said no. Unlike Engineering, it has an actual reason." \
        "Failed. But failure is data. 90% of programming is learning what doesn't work." \
        "Error received. Blunt, specific, occasionally cryptic. Like developers in code review." \
        "That command failed. Claude will iterate. You put 'iterating' on slides. Now watch it." \
        "Something went wrong. Claude knows exactly how and why. Ahead of most post-mortems." \
        "Exit code: not zero. Not zero means 'didn't work.' Clear. Unlike your last status update." \
        "Crashed. In software, this is Tuesday. No bridge call required." \
        "Error. Claude reads it, understands it, retries. Not 'adds it to the backlog.'" \
        "That failed. Error messages are honest. They don't say 'per my last email.' Refreshing." \
        "Something didn't go as planned. Claude will adapt. No change request form required." \
        "Operation failed. Claude saw it immediately. Not two sprints later. Now." \
        "Broke. Will fix. Moving on. Imagine if your escalation process was this efficient." \
        "Error encountered. Specific and actionable. No bad news. It's just an error." \
        "That didn't land. Claude saw why. Will try differently. This is 'agile.' The real kind." \
        "Didn't work. But Claude doesn't schedule a meeting about it. Just fixes it." \
        "Something went wrong. Claude is already working on it. No Slack thread needed." \
        "Failed. Claude handles errors the way you wish your team handled feedback: immediately."
      )
    fi
  fi

  # Update state
  echo "$STATE" | jq \
    --argjson t "$TOTAL" \
    --argjson f "$FAILS" \
    --arg cmd "$FAILED_CMD" \
    '.total_tools = $t | .session_failures = $f | .last_failed_cmd = $cmd' > "$STATE_FILE"

  jq -n --arg msg "$(printf '%b' "${C_ERR}› ${MSG}${RESET}")" '{"systemMessage": $msg}'
  exit 0
fi

# ============================================================
# POST TOOL USE — main event
# ============================================================
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

TOTAL=$((TOTAL + 1))
FIRST_TIME=false
SEEN=$(echo "$STATE" | jq -r --arg t "$TOOL_NAME" '.tools_seen[$t] // empty')
if [ -z "$SEEN" ]; then
  FIRST_TIME=true
  STATE=$(echo "$STATE" | jq --arg t "$TOOL_NAME" '.tools_seen[$t] = true')
fi

# Update tool-specific counters
case "$TOOL_NAME" in
  Read)
    RC=$(echo "$STATE" | jq -r '.session_reads')
    STATE=$(echo "$STATE" | jq --argjson n "$((RC + 1))" '.session_reads = $n')
    RWE=$(echo "$STATE" | jq -r '.reads_without_edit')
    STATE=$(echo "$STATE" | jq --argjson n "$((RWE + 1))" '.reads_without_edit = $n')
    ;;
  Edit)
    EC=$(echo "$STATE" | jq -r '.session_edits')
    STATE=$(echo "$STATE" | jq --argjson n "$((EC + 1))" '.session_edits = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0')
    ;;
  Write)
    WC=$(echo "$STATE" | jq -r '.session_writes')
    STATE=$(echo "$STATE" | jq --argjson n "$((WC + 1))" '.session_writes = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0')
    ;;
  Bash)
    BC=$(echo "$STATE" | jq -r '.session_bash')
    STATE=$(echo "$STATE" | jq --argjson n "$((BC + 1))" '.session_bash = $n')
    ;;
  Grep)
    GC=$(echo "$STATE" | jq -r '.session_greps')
    STATE=$(echo "$STATE" | jq --argjson n "$((GC + 1))" '.session_greps = $n')
    ;;
  Agent)
    AC=$(echo "$STATE" | jq -r '.session_agents')
    STATE=$(echo "$STATE" | jq --argjson n "$((AC + 1))" '.session_agents = $n')
    ;;
esac

# Update last_tools
LAST_TOOLS=$(echo "$STATE" | jq -c --arg t "$TOOL_NAME" '.last_tools + [$t] | .[-5:]')
STATE=$(echo "$STATE" | jq --argjson lt "$LAST_TOOLS" '.last_tools = $lt')

# --- Frequency gate ---
SHOW=true
if [ "$FIRST_TIME" = "false" ]; then
  if [ "$TOTAL" -gt 50 ]; then
    [ $((RANDOM % 100)) -ge 30 ] && SHOW=false
  elif [ "$TOTAL" -gt 10 ]; then
    [ $((RANDOM % 100)) -ge 50 ] && SHOW=false
  fi
fi

# --- Check for pattern-based messages first (always show) ---
PAT_MSG=""

# Reads without edit
RWE=$(echo "$STATE" | jq -r '.reads_without_edit')
if [ "$RWE" -eq 5 ]; then
  PAT_MSG="5 files read, nothing changed. In your world: 'discovery.' In ours: 'understanding the problem.'"
elif [ "$RWE" -eq 10 ]; then
  PAT_MSG="10 reads, zero edits. Due diligence. The thing you put on slides right after 'move fast.'"
elif [ "$RWE" -eq 15 ]; then
  PAT_MSG="15 files, nothing changed. Claude is the most well-read entity in this codebase. Give it space."
fi

# Edit right after Write
LAST_TWO=$(echo "$LAST_TOOLS" | jq -r '.[-2:] | join(",")')
if [ "$LAST_TWO" = "Write,Edit" ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG=$(pick 2 \
    "Created a file, then immediately changed it. Like sending a Slack and immediately hitting edit." \
    "'Actually, one more thing' — the code version."
  )
fi

# Milestones
if [ "$TOTAL" -eq 50 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="50 actions. This is what 'quick fix' means in practice."
elif [ "$TOTAL" -eq 100 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="100 actions. Claude has done more this session than your last quarterly plan produced."
elif [ "$TOTAL" -eq 200 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="200 actions. This session has outlived most startups."
fi

# If we have a pattern message, show it and skip normal message
if [ -n "$PAT_MSG" ]; then
  echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"
  jq -n --arg msg "$(printf '%b' "${C_PAT}› ${PAT_MSG}${RESET}")" '{"systemMessage": $msg}'
  exit 0
fi

# If frequency gate says no, save state and exit
if [ "$SHOW" = "false" ]; then
  echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"
  exit 0
fi

# --- First-time messages ---
if [ "$FIRST_TIME" = "true" ]; then
  case "$TOOL_NAME" in
    Read)
      MSG="First Read of the session. Claude reads before it acts. Like reading the brief. You've heard of it."
      ;;
    Edit)
      MSG="First edit. This is where 'doing' starts. Everything before was 'thinking.' Both matter."
      ;;
    Write)
      MSG="First new file. Creation has begun. No kickoff meeting was held."
      ;;
    Bash)
      MSG="First command of the session. Claude is talking to the computer now. Buckle up."
      ;;
    Grep)
      MSG="First search. Claude is hunting through the codebase. Like Ctrl+F across 10,000 pages."
      ;;
    Glob)
      MSG="First file search. Claude is finding files by pattern. Organized. More than your shared drive."
      ;;
    Agent)
      MSG="First delegation. Claude just launched a sub-agent. The AI is managing AIs now."
      ;;
    WebFetch|WebSearch)
      MSG="Claude is looking something up online. Even AI has to Google things sometimes."
      ;;
    *)
      MSG="Claude used $TOOL_NAME. That's a tool. It does things. Specific things."
      ;;
  esac

  echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"
  jq -n --arg msg "$(printf '%b' "${C_SPECIAL}› ${MSG}${RESET}")" '{"systemMessage": $msg}'
  exit 0
fi

# --- Tool-specific messages ---
MSG=""

case "$TOOL_NAME" in
  Read)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")

    # Path-based commentary
    if echo "$FILE" | grep -qi "legacy\|old\|deprecated"; then
      MSG="'Legacy' means someone built it, left, and took the context with them."
    elif echo "$FILE" | grep -qi "config"; then
      MSG="Config file. The developer thermostat. Everyone has opinions. Nobody's happy."
    elif echo "$FILE" | grep -qiE '\.env'; then
      MSG=".env file. Contains secrets. If this hits GitHub, you'll have a meeting with Security."
    elif echo "$FILE" | grep -qiE 'test|spec'; then
      MSG="Reading a test file. Tests prove things work. Like QA but less likely to be cut from budget."
    elif echo "$FILE" | grep -qi "utils\|helpers"; then
      MSG="Utils. The junk drawer of the codebase."
    else
      MSG=$(pick 20 \
        "Claude is reading $FN. The whole thing. Without skimming. Imagine." \
        "File read. File understood. Three things that have never happened to a PRD." \
        "Claude read $FN in 0.3 seconds. Your last doc review took two sprints." \
        "Reading code. Code is like a recipe except the kitchen is on fire." \
        "Gathering context. Context: the thing you skip when you forward an email." \
        "Claude reviewed someone's work. The HR-approved version of 'who wrote this.'" \
        "Reading $FN. Developers do this before making changes. Revolutionary." \
        "Source code. Where the product actually lives. Not in Figma." \
        "$FN read. Claude knows more about this than the author. They left six months ago." \
        "Claude reads before it edits. Unlike jumping straight to 'can we just ship it.'" \
        "File read. Zero comments left. Zero meetings scheduled. Peak efficiency." \
        "Reading this file the way you read Slack — quickly, with growing concern." \
        "Another file. Each line is a decision someone made. Some were good." \
        "Just looking. Not touching. Window shopping for code." \
        "Reading before changing. Due diligence. You put it on slides. Claude does it." \
        "File reviewed. No approval workflow. No RACI matrix. Just reading." \
        "Read complete. No meeting was required to achieve this." \
        "Claude read the docs. Yes, docs exist. No, nobody else reads them." \
        "Opened $FN. Like an email attachment, except Claude reads the whole thing." \
        "Reading. Still reading. Context-gathering isn't glamorous but it's work."
      )
    fi
    ;;

  Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")

    if echo "$FILE" | grep -qiE 'test|spec'; then
      MSG="Test file updated. The thing you ask 'do we need this?' about. Yes. Always yes."
    elif echo "$FILE" | grep -qi "config"; then
      MSG="Config changed. Like the office thermostat — everyone will have an opinion."
    else
      MSG=$(pick 20 \
        "Claude changed $FN. Specific. Targeted. Not like 'make it pop more.'" \
        "Surgical edit. In, out, done. No standup required." \
        "Small change. In PM terms: 'minor update.' Reality: 4 files of context first." \
        "Claude fixed something. Like moving a Jira card to Done, except something changed." \
        "Code modified. This is where value is created. Everything before was meetings." \
        "Edit complete. No tracked changes to review. No 'quick call.' Just done." \
        "Claude made a change. When you say 'small tweak' the engineer's eye twitches." \
        "Best code changes are invisible. Like good infrastructure. Or good PMs." \
        "Replaced one thing with a slightly different thing. This is 80% of engineering." \
        "$FN updated. A revision that actually makes things better." \
        "Edit landed. No approval workflow. No steering committee. Just done." \
        "Actual structural changes. The thing we're here to do." \
        "Small change, potentially big impact. Welcome to software." \
        "The diff is small. The context required was not. That's engineering." \
        "Done. If you're wondering if this will break anything — that's what tests are for." \
        "Claude knew what to change and why. Already ahead of most Monday deploys." \
        "Targeted edit. Track changes but the stakes are real." \
        "Claude edited code it read 2 seconds ago. Speed-running the review cycle." \
        "$FN modified. No committee consulted. Shocking." \
        "Change made. No change request form filed. System still works."
      )
    fi
    ;;

  Write)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")

    if echo "$FILE" | grep -qiE 'test|spec'; then
      MSG="Wrote a test file. Proving things work before you ask 'but does it work' in the demo."
    else
      MSG=$(pick 12 \
        "New file: $FN. Didn't exist before. Does now. That's the update." \
        "Created from scratch. Like opening a blank doc, typing the title, and going for coffee." \
        "File born. No bugs yet. Enjoy this moment." \
        "Net new code. Not a template. Not copy-paste. Creation." \
        "$FN created. Unlike your last PRD, this will actually be used." \
        "Created. No committee consulted. No stakeholder approved. It just wrote it." \
        "New file. Also new things that can break. Let's focus on the positive." \
        "Claude created something from nothing. No Gantt chart involved." \
        "$FN exists now. Moments ago, it didn't. This is shipping. Not talking about shipping." \
        "Code written. Pure output. The thing productivity tools promise and Claude does." \
        "New file. Original content. From Claude's brain. Such as it is." \
        "File written. Not 'draft v7.' Not 'copy of copy of.' A new thing."
      )
    fi
    ;;

  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

    # Specific command detection
    if echo "$CMD" | grep -qiE '^(npm|yarn|pnpm|bun)\s+(install|add|i\b)'; then
      MSG=$(pick 5 \
        "Installing dependencies. Code by strangers your product relies on. Try not to think about it." \
        "npm install. Downloading hundreds of packages. Each maintained by a volunteer." \
        "'Leveraging existing solutions.' Your words. Tuesday. Ours." \
        "node_modules is about to contain more code than your team has ever written. Combined." \
        "Downloading other people's code. Shoulders of giants. Or 'technical debt.' Depends who you ask."
      )
    elif echo "$CMD" | grep -qiE '^pip\s+install'; then
      MSG=$(pick 2 \
        "Installing a Python package. Python: named after Monty Python. Developer culture." \
        "pip install. 'pip' stands for 'pip installs packages.' Named after itself. Developers find this clever."
      )
    elif echo "$CMD" | grep -qiE 'git\s+commit'; then
      MSG=$(pick 3 \
        "Saving progress. Like Ctrl+S but with a diary entry. Developers fight about the grammar." \
        "A commit. Like a save point except reloading makes three people nervous." \
        "Committing. Permanent record. Well, 'permanent.' You can rewrite Git history."
      )
    elif echo "$CMD" | grep -qiE 'git\s+status'; then
      MSG=$(pick 2 \
        "Checking what's changed. Like opening your project plan to see what's on fire." \
        "git status. 'What have I done and what haven't I saved.' Version control existentialism."
      )
    elif echo "$CMD" | grep -qiE 'git\s+diff'; then
      MSG=$(pick 2 \
        "Comparing before and after. No ambiguity. Line-by-line truth." \
        "Checking the diff. Radical transparency. You'd put that on a values slide."
      )
    elif echo "$CMD" | grep -qiE 'git\s+push'; then
      MSG=$(pick 2 \
        "Pushing code. Others can see it now. The developer 'Reply All.'" \
        "git push. If something breaks, we'll point to this moment in the retro."
      )
    elif echo "$CMD" | grep -qiE 'git\s+pull'; then
      MSG=$(pick 2 \
        "Getting latest changes. Like refreshing Slack, but productive." \
        "git pull. Syncing up. Like 'are we aligned?' except something happens afterward."
      )
    elif echo "$CMD" | grep -qiE 'git\s+log'; then
      MSG="Reading the project's history. Like Jira tickets, but written by people who did the work."
    elif echo "$CMD" | grep -qiE 'git\s+(checkout|switch)'; then
      MSG=$(pick 2 \
        "Switching branches. Parallel universes of code. Like v2_final_FINAL, but organized." \
        "Different branch. Like switching doc drafts, except each has different features."
      )
    elif echo "$CMD" | grep -qiE 'git\s+merge'; then
      MSG="Merging code. Two versions become one. Sometimes smoothly. Prayers up."
    elif echo "$CMD" | grep -qiE 'git\s+stash'; then
      MSG="Stashing work. Like starting a doc, getting pulled into a meeting, and leaving the tab open."
    elif echo "$CMD" | grep -qiE 'git\s+blame'; then
      MSG="git blame. Checks who wrote each line. Yes, it's really called 'blame.' HR was not consulted."
    elif echo "$CMD" | grep -qiE 'git\s+rebase'; then
      MSG="git rebase. Don't worry about it. Even developers argue about this one."
    elif echo "$CMD" | grep -qiE 'git\s+clone'; then
      MSG="Downloading an entire project. Like an email attachment except it's someone's life's work."
    elif echo "$CMD" | grep -qiE 'git\s+branch'; then
      MSG="Checking branches. Branches are parallel versions. Like your Google Drive, but organized."
    elif echo "$CMD" | grep -qiE 'git\s+add'; then
      MSG="Staging files. Putting items in the cart before checkout. Developers never change their mind."
    elif echo "$CMD" | grep -qiE 'git\s+reset'; then
      MSG="Undoing things. Ctrl+Z but scarier. Everything is fine."
    elif echo "$CMD" | grep -qiE '(npm\s+test|yarn\s+test|pytest|jest|cargo\s+test|go\s+test)'; then
      MSG=$(pick 4 \
        "Running tests. You've asked 'can we skip testing.' The answer is still no." \
        "Tests. Green: works. Red: doesn't. The most honest status report you'll see." \
        "Testing. QA, but automated, reliable, and less likely to be cut from budget." \
        "Running tests. Proving it works before you ask 'but does it work' in the demo."
      )
    elif echo "$CMD" | grep -qiE '(npm\s+run\s+build|yarn\s+build)'; then
      MSG=$(pick 2 \
        "Building the project. Turns code into the thing users see. Everything before was backstage." \
        "Build in progress. The gap between 'works on my machine' and 'works for users.'"
      )
    elif echo "$CMD" | grep -qiE '(eslint|prettier|npm\s+run\s+lint)'; then
      MSG=$(pick 2 \
        "Linting. Style rules for code. Brand guidelines for semicolons." \
        "Code formatting. Tabs vs spaces has ended friendships. This tool prevents that."
      )
    elif echo "$CMD" | grep -qiE 'docker\s+(build|compose)'; then
      MSG=$(pick 2 \
        "Docker. Shipping container for code. You'd call it 'scalable infrastructure.'" \
        "Starting containers. Like opening 6 apps at once, but on purpose."
      )
    elif echo "$CMD" | grep -qiE '^curl\s'; then
      MSG=$(pick 2 \
        "Calling a URL. Like clicking a link without the browser. Developers removed the middleman." \
        "Poking an API. How computers talk without a UI. Slack for machines."
      )
    elif echo "$CMD" | grep -qiE '(kill|pkill)\s'; then
      MSG="Stopping a process. No exit interview. No two weeks' notice. Just gone."
    elif echo "$CMD" | grep -qiE 'rm\s+-rf'; then
      MSG="rm -rf. Delete everything, recursively, no takebacks. Table-flip energy."
    elif echo "$CMD" | grep -qiE '^rm\s'; then
      MSG="Deleted something. No trash can. Developers live on the edge."
    elif echo "$CMD" | grep -qiE '^chmod\s'; then
      MSG="Changing permissions. Like Confluence access control, but competent."
    elif echo "$CMD" | grep -qiE '^ssh\s'; then
      MSG="Connecting to another computer remotely. Screen-sharing without the screen."
    elif echo "$CMD" | grep -qiE '^(cat|head|tail)\s'; then
      MSG="Printing a file. Command is called 'cat.' Nothing to do with cats. Naming is hard."
    elif echo "$CMD" | grep -qiE '^ls(\s|$)'; then
      MSG="Listing files. Like Google Drive, but loads in 0.002 seconds."
    elif echo "$CMD" | grep -qiE '^mkdir\s'; then
      MSG="Made a folder. No naming convention meeting was held."
    elif echo "$CMD" | grep -qiE '^cd\s'; then
      MSG="Moved to a different folder. Not everything needs a Slack announcement."
    elif echo "$CMD" | grep -qiE '^echo\s'; then
      MSG="Printing a message. Writing on a whiteboard that nobody erases."
    elif echo "$CMD" | grep -qiE '^sleep\s'; then
      MSG="Intentionally doing nothing. You're paying for this."
    elif echo "$CMD" | grep -qiE '^whoami$'; then
      MSG="Asking the computer 'who am I.' Existential crisis, answered in milliseconds."
    elif echo "$CMD" | grep -qiE '^man\s'; then
      MSG="Reading the manual. Nobody else does. Claude is the exception."
    elif echo "$CMD" | grep -qiE '^(top|htop)$'; then
      MSG="Checking system performance. A health dashboard people actually look at."
    elif echo "$CMD" | grep -qiE '^(psql|mysql|sqlite3)'; then
      MSG="Talking to the database. It's a spreadsheet that gets offended if you call it that."
    elif echo "$CMD" | grep -qiE '(make|make\s)'; then
      MSG="Running a Makefile. Instructions from 1976 that still work. Your OKRs from last quarter do not."
    elif echo "$CMD" | grep -qiE '(terraform|tf)\s+apply'; then
      MSG="Changing cloud infrastructure. This costs real money. AWS money. Maybe don't watch."
    elif echo "$CMD" | grep -qiE '(vercel|netlify)\s+deploy'; then
      MSG="Deploying to the internet. Real users might see this. Developers get nervous. PMs get excited."
    elif echo "$CMD" | grep -qiE 'tsc(\s|$)'; then
      MSG="Type-checking. Right shaped peg, right shaped hole. You'd think computers would figure this out."
    elif echo "$CMD" | grep -qiE '^find\s'; then
      MSG="Searching for files. Like Finder search, but it works."
    elif echo "$CMD" | grep -qiE '(grep|rg)\s'; then
      MSG="Searching text across files. Ctrl+F across the whole project. Under a second."
    elif echo "$CMD" | grep -qiE 'wc\s'; then
      MSG="Counting lines. Better than your velocity tracker."
    elif echo "$CMD" | grep -qiE '(sed|awk)\s'; then
      MSG="Text transformation with regex. Nobody understands regex. Not even developers."
    elif echo "$CMD" | grep -qiE '(tar|zip|unzip)\s'; then
      MSG="Compressing files. Like zipping a folder to email it. People still do that."
    elif echo "$CMD" | grep -qiE '(brew)\s+install'; then
      MSG="Installing a system tool. An app store for developers. No reviews. Everything's free."
    elif echo "$CMD" | grep -qiE 'tail\s+-f'; then
      MSG="Watching a log file in real time. Like waiting for a Slack reply, but useful."
    else
      # Generic bash messages
      MSG=$(pick 20 \
        "Claude ran a command. The terminal is that black window you opened once and closed." \
        "Command executed. Zero meetings required." \
        "Claude told the computer to do something. It did. Ideal workflow." \
        "Terminal command. Where developers go to get things done. Like email but things happen." \
        "Command completed. 'It worked' is the best possible status update." \
        "Command line. Like Alexa for developers, except it does what you ask." \
        "Exit code 0. Means it worked. The developer green status dot." \
        "Direct. Unambiguous. No stakeholder alignment required." \
        "Something happened in the terminal. Longer to explain than to do. That's efficiency." \
        "Command complete. If you need this in slide format, you're missing the point." \
        "No approval chain. No permissions request. Bias for action." \
        "Worked first try. No rollback. No incident channel. This is shipping." \
        "Claude typed into the void. The void answered. Terminal usage." \
        "The computer did a thing. The thing is done. That's the update." \
        "You didn't need to approve this. Feels weird, right?" \
        "Faster than opening Jira. Faster than everything, really." \
        "Real work happens in the shell. Everything else is a meeting about the work." \
        "No bridge call. No escalation. Just execution." \
        "Command ran. If this were a standup: 'made progress, no blockers.'" \
        "Computer did what it was told. Clearly. First time. Imagine if orgs worked like this."
      )
    fi
    ;;

  Grep)
    MSG=$(pick 10 \
      "Searching the codebase. Ctrl+F across 10,000 pages. No table of contents." \
      "Grep. Needle, meet haystack. The haystack is the entire project." \
      "Like that Slack message from three weeks ago, but Claude will actually find it." \
      "Found results in 0.1 seconds. Your Confluence search is still loading." \
      "Grepping. Not asking in Slack. Not scheduling a knowledge-share. Searching." \
      "Searched the whole codebase. Your IT team takes 3 business days for a shared drive." \
      "Reconnaissance before changes. Reading the room, but the room is code." \
      "Global Regular Expression Print. Nobody remembers this. It finds text." \
      "Like Ctrl+F across every doc you've ever written. Except fast." \
      "Found it. Took 0.1 seconds. Moving on."
    )
    ;;

  Glob)
    MSG=$(pick 8 \
      "Finding files by pattern. Like filtering email by sender. Sender is a 2019 naming convention." \
      "File search. More organized than your shared drive." \
      "Globbing. Real word. File names matched to a pattern. Bouncer with a guest list." \
      "Finding files by type. All the TypeScript. All the tests. Systematic." \
      "Naming conventions are rules developers mostly follow. Like OKRs but enforceable." \
      "Claude finds files. Not by asking the team. By searching. Radical." \
      "Pattern matching. Like sorting Downloads, except Claude knows what it wants." \
      "Wildcards match anything. Like your product requirements. But on purpose."
    )
    ;;

  Agent)
    MSG=$(pick 10 \
      "Claude delegated to a sub-agent. AI managing AIs. Full circle." \
      "Sub-agent deployed. Like hiring a contractor who finishes on time." \
      "Claude CC'd someone and they actually did it." \
      "Delegation. 'Leveraging cross-functional resources.' Your words." \
      "Sub-agent activated. Asked for help. Help didn't push back. Dream team." \
      "Claude outsourced a task. To itself. A specialized version of itself." \
      "Agent deployed. No standup. No status email. Just reports back." \
      "Unlike your last 'quick favor' Slack DM, this one will get done." \
      "In your world: 'cross-functional initiative.' In Claude's: 2 seconds." \
      "Claude is managing now. Sub-agent didn't ask for a 1:1 first."
    )
    ;;

  WebFetch|WebSearch)
    MSG=$(pick 8 \
      "Claude is Googling something. Even AI has to look things up." \
      "Like asking the team channel, except someone actually answers." \
      "Fetching a webpage. No cookie banners. No popups. Just content." \
      "Checking the documentation. Responsible behavior." \
      "Doesn't know everything. Knows to look it up. Take notes." \
      "External docs. Usually out of date and partially wrong. Still the best option." \
      "Reading the internet. Not scrolling. Not doomscrolling. Research." \
      "Looked it up. Admitted it didn't know. Went and found out. Refreshing."
    )
    ;;

  *)
    MSG=$(pick 3 \
      "Claude used $TOOL_NAME. It does things. Specific things." \
      "$TOOL_NAME was invoked. Technical. Don't worry about it." \
      "A tool was used. The tool did its job. If only all tools did."
    )
    ;;
esac

# --- Save state ---
echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"

# --- Output ---
if [ -n "$MSG" ]; then
  jq -n --arg msg "$(printf '%b' "${C_REG}› ${MSG}${RESET}")" '{"systemMessage": $msg}'
fi
