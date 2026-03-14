#!/bin/bash
# Claude Code for PMs and Babies
# Explains what Claude Code is doing in plain English.
# Viciously condescending. Relentlessly roasting. Technically accurate.

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

C_REG="${DIM}${ITALIC}${CYAN}"
C_SPECIAL="${ITALIC}${MAGENTA}"
C_ERR="${DIM}${ITALIC}${YELLOW}"
C_SUM="${DIM}${ITALIC}${GREEN}"
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
  "session_agents": 0,
  "session_searches": 0,
  "last_tool_name": "",
  "consecutive_same": 0,
  "last_read_file": "",
  "consecutive_edits": 0,
  "consecutive_reads": 0
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
TOTAL=$(echo "$STATE" | jq -r '.total_tools // 0')
[ "$TOTAL" = "null" ] && TOTAL=0

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
  basename "$1" 2>/dev/null || echo "$1"
}

# --- Helper: get file extension ---
file_ext() {
  local fn
  fn=$(basename "$1" 2>/dev/null)
  echo "${fn##*.}"
}

# --- Helper: get parent dir name ---
parent_dir() {
  local d
  d=$(dirname "$1" 2>/dev/null)
  basename "$d" 2>/dev/null
}

# ============================================================
# STOP EVENT — turn summary
# ============================================================
if [ "$EVENT" = "Stop" ]; then
  if [ "$TOTAL" -lt 3 ]; then
    exit 0
  fi

  SR=$(echo "$STATE" | jq -r '.session_reads // 0')
  SE=$(echo "$STATE" | jq -r '.session_edits // 0')
  SW=$(echo "$STATE" | jq -r '.session_writes // 0')
  SB=$(echo "$STATE" | jq -r '.session_bash // 0')
  SF=$(echo "$STATE" | jq -r '.session_failures // 0')
  SG=$(echo "$STATE" | jq -r '.session_greps // 0')
  SA=$(echo "$STATE" | jq -r '.session_agents // 0')
  SS=$(echo "$STATE" | jq -r '.session_searches // 0')

  # Personalized summaries based on what actually happened
  if [ "$SF" -gt 3 ]; then
    MSG="$TOTAL actions, $SF errors. Still shipped. Your team would've called a war room after error #2."
  elif [ "$SE" -eq 0 ] && [ "$SR" -gt 5 ]; then
    MSG="$TOTAL actions. ${SR} reads, zero edits. Claude just read your entire codebase and decided it wasn't worth changing. Ouch."
  elif [ "$SA" -gt 0 ]; then
    MSG="$TOTAL actions, $SA delegated to sub-agents. Claude managed a team this session. More effectively than most."
  elif [ "$SS" -gt 5 ]; then
    MSG="$TOTAL actions including $SS web searches. Claude did more research in one turn than your last 'competitive analysis.'"
  elif [ "$SE" -gt "$SR" ]; then
    MSG="$TOTAL actions. More edits ($SE) than reads ($SR). Claude knew what to fix. Didn't need to 'align on the problem' first."
  elif [ "$SW" -gt 3 ]; then
    MSG="$TOTAL actions. $SW new files created. Claude shipped more this turn than your team's last two-week sprint."
  else
    MSG=$(pick 15 \
      "$TOTAL actions. You contributed zero of them. Good job supervising." \
      "Turn done. ${SR} reads, ${SE} edits, ${SB} commands. You watched. Gold star." \
      "$TOTAL things accomplished without a single meeting invite. You didn't know that was possible." \
      "Done. $TOTAL steps. Each one useful. Try that in your next sprint planning." \
      "$TOTAL operations. In PM terms: 'we shipped.' In reality: Claude shipped. You spectated." \
      "That was $TOTAL actions. Your quarterly OKR deck has fewer deliverables." \
      "Fin. ${SR} reads, ${SE} edits. More output than your entire team's last sprint review." \
      "$TOTAL tool calls. No standup. No retro. No feelings were discussed. Just work." \
      "Done. $TOTAL actions. Each under a second. Your last 'quick sync' was 45 minutes." \
      "$TOTAL steps. Not one of them was 'aligning stakeholders.' Shocking what's possible." \
      "Turn over. ${SE} edits, ${SF} errors. Still faster than your approval workflow." \
      "$TOTAL actions and at no point did anyone say 'let's table this.' Paradise." \
      "Wrapped up. $TOTAL actions. You can go back to Slack now. We know you want to." \
      "$TOTAL things done. If you understood any of them, you wouldn't need this plugin." \
      "Session complete. $TOTAL actions. More than your last two sprints combined."
    )
  fi

  jq -n --arg msg "$(printf '%b' "${C_SUM}› ${MSG}${RESET}")" '{"systemMessage": $msg}'

  echo "$STATE" | jq '.total_tools = 0 | .session_reads = 0 | .session_edits = 0 | .session_writes = 0 | .session_bash = 0 | .session_failures = 0 | .session_greps = 0 | .session_agents = 0 | .session_searches = 0 | .reads_without_edit = 0 | .last_tools = [] | .last_tool_name = "" | .consecutive_same = 0 | .last_read_file = "" | .consecutive_edits = 0 | .consecutive_reads = 0' > "$STATE_FILE"
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
  ERROR=$(echo "$INPUT" | jq -r '.error // ""')

  # Personalized failure based on the actual command
  SPECIFIC_MSG=""
  if [ -n "$FAILED_CMD" ]; then
    if echo "$FAILED_CMD" | grep -qiE 'npm\s+(install|test|run)'; then
      SPECIFIC_MSG="npm failed. The JavaScript ecosystem strikes again. This is the cost of 'moving fast.'"
    elif echo "$FAILED_CMD" | grep -qiE 'git\s+push'; then
      SPECIFIC_MSG="Push rejected. Someone else changed the code. Collaboration is hard. You'd know if you wrote code."
    elif echo "$FAILED_CMD" | grep -qiE 'git\s+merge'; then
      SPECIFIC_MSG="Merge conflict. Two people changed the same thing. Like when two PMs own the same feature. Except this gets resolved."
    elif echo "$FAILED_CMD" | grep -qiE 'docker'; then
      SPECIFIC_MSG="Docker failed. Containers are hard. You said 'just containerize it' in a meeting once. This is what that costs."
    elif echo "$FAILED_CMD" | grep -qiE 'curl|wget'; then
      SPECIFIC_MSG="Request failed. The URL didn't respond. Like your last email to Engineering."
    elif echo "$FAILED_CMD" | grep -qiE 'pip\s+install'; then
      SPECIFIC_MSG="pip install failed. Dependency hell. You said 'how hard can it be to add a library.' This hard."
    elif echo "$FAILED_CMD" | grep -qiE 'ssh'; then
      SPECIFIC_MSG="SSH failed. Can't connect. The server said no. Like your last three feature requests."
    elif echo "$FAILED_CMD" | grep -qiE '(pytest|jest|npm\s+test)'; then
      SPECIFIC_MSG="Tests failed. Something is broken. This is why we don't skip testing. Remember when you asked to skip testing?"
    elif echo "$FAILED_CMD" | grep -qiE 'terraform|tf'; then
      SPECIFIC_MSG="Terraform failed. Infrastructure broke. This is the 'cloud stuff' you wave your hands about in exec reviews."
    elif echo "$FAILED_CMD" | grep -qiE '(build|compile|tsc)'; then
      SPECIFIC_MSG="Build failed. The code doesn't compile. It's like a typo, but the computer refuses to guess what you meant. Unlike your team."
    fi
  fi

  if [ -n "$SPECIFIC_MSG" ]; then
    MSG="$SPECIFIC_MSG"
  # Retry detection
  elif [ -n "$FAILED_CMD" ] && [ "$FAILED_CMD" = "$LAST_FAILED" ]; then
    MSG=$(pick 5 \
      "Same command again. When you do this it's called 'stubbornness.' When Claude does it, 'persistence.'" \
      "Trying again. Claude doesn't give up. Unlike your last three product initiatives." \
      "Second attempt. Claude learns from failure. You just reschedule the meeting." \
      "Retrying. Claude iterates in seconds. Your 'iteration cycle' is two sprints and a planning poker session." \
      "Same thing again. Claude is debugging. You'd have escalated to the tech lead by now."
    )
  elif echo "$ERROR" | grep -qi "permission denied"; then
    MSG=$(pick 4 \
      "Permission denied. Like when Engineering says 'no' to your feature request, but enforced by math." \
      "Access denied. The computer has boundaries. You could learn from it." \
      "Not allowed. The computer enforces access controls. Unlike your Google Drive, which is a free-for-all." \
      "Permission denied. Someone locked this down. Probably because of something a PM did once."
    )
  elif echo "$ERROR" | grep -qi "command not found"; then
    MSG=$(pick 4 \
      "Command not found. It's not installed. Like the feature you promised the client last week." \
      "Doesn't exist. Like your technical background." \
      "Not found. The computer can't find it. Unlike you, it actually looked." \
      "Command doesn't exist on this machine. Like 'quick win' doesn't exist in engineering."
    )
  elif echo "$ERROR" | grep -qi "timeout"; then
    MSG=$(pick 4 \
      "Timed out. Even computers have limits. Unlike your all-hands, which are eternal." \
      "Timeout. It took too long. You wouldn't notice — you're used to waiting for Engineering." \
      "Too slow. Got killed. Like headcount in Q3." \
      "Timed out. There's a hard limit on how long things can take. Imagine if your meetings had that."
    )
  elif echo "$ERROR" | grep -qi "ECONNREFUSED\|connection refused"; then
    MSG="Connection refused. The server isn't running. Like your product's growth metrics."
  elif echo "$ERROR" | grep -qi "ENOENT\|no such file"; then
    MSG="File not found. It's not where Claude expected. Like your team's documentation."
  elif echo "$ERROR" | grep -qi "ENOMEM\|out of memory"; then
    MSG="Out of memory. The computer ran out of RAM. Like your sprint ran out of capacity. Except this is real."
  elif echo "$ERROR" | grep -qi "syntax error"; then
    MSG="Syntax error. A typo, essentially. But in code, typos break everything. Not like your PRDs, where nobody notices."
  elif echo "$ERROR" | grep -qi "403\|forbidden"; then
    MSG="403 Forbidden. The server knows who you are and said no anyway. Corporate energy."
  elif echo "$ERROR" | grep -qi "404\|not found"; then
    MSG="404. The page doesn't exist. Like the documentation you were supposed to write last quarter."
  elif echo "$ERROR" | grep -qi "500\|internal server error"; then
    MSG="500 Internal Server Error. Something broke on the other end. Not Claude's fault. For once, not your fault either."
  elif echo "$ERROR" | grep -qi "rate limit\|429\|too many"; then
    MSG="Rate limited. Too many requests too fast. Even APIs have boundaries. Unlike your Slack DM frequency."
  else
    MSG=$(pick 20 \
      "Something broke. Claude will fix it. You just sit there." \
      "Error. Red text. Claude already knows why. You'd need a 30-minute explainer and still wouldn't get it." \
      "It broke. This is normal. Like when you break the build by merging without review. Normal." \
      "Error. The computer is being honest with you. I know that's unfamiliar." \
      "Something failed. Claude already knows why. You never will. And that's fine." \
      "Error. No need to escalate. No need to Slack the channel. No need to 'flag it.' Just wait." \
      "That didn't work. But unlike your product strategy, Claude has a backup plan." \
      "Broke. Don't panic. Don't open a Jira ticket. Don't 'flag it.' Just watch." \
      "Failed. In your world this triggers a post-mortem. Here it triggers a retry. Faster." \
      "Error. Claude reads it and understands it. You'd read it and schedule a meeting about it." \
      "Crashed. Normal. This is what 'iterating' actually looks like. Not a slide deck." \
      "It didn't work. Claude doesn't need a support group. It just tries again." \
      "Something went wrong. Claude is already fixing it. No war room needed. No incident commander." \
      "Error encountered. Don't touch anything. Seriously. Please don't touch anything." \
      "Failed. Unlike your last launch, Claude noticed immediately." \
      "That broke. Claude saw why in 0.01 seconds. Your last incident review took four hours." \
      "Something went wrong. No, you can't help. That's not mean — it's just accurate." \
      "Error. The kind with actual diagnostic information. Not 'something feels off in the UX.'" \
      "It failed. Like your attempt to learn SQL that one time. But Claude recovers faster." \
      "Failed. Claude handles failure the way you handle success — quickly and without understanding why."
    )
  fi

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

CURRENT_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Update tool-specific counters
case "$TOOL_NAME" in
  Read)
    RC=$(echo "$STATE" | jq -r '.session_reads')
    STATE=$(echo "$STATE" | jq --argjson n "$((RC + 1))" '.session_reads = $n')
    RWE=$(echo "$STATE" | jq -r '.reads_without_edit')
    STATE=$(echo "$STATE" | jq --argjson n "$((RWE + 1))" '.reads_without_edit = $n')
    STATE=$(echo "$STATE" | jq --arg f "$CURRENT_FILE" '.last_read_file = $f')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
    CR=$(echo "$STATE" | jq -r '.consecutive_reads // 0')
    STATE=$(echo "$STATE" | jq --argjson n "$((CR + 1))" '.consecutive_reads = $n')
    ;;
  Edit)
    EC=$(echo "$STATE" | jq -r '.session_edits')
    STATE=$(echo "$STATE" | jq --argjson n "$((EC + 1))" '.session_edits = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0')
    CE=$(echo "$STATE" | jq -r '.consecutive_edits // 0')
    STATE=$(echo "$STATE" | jq --argjson n "$((CE + 1))" '.consecutive_edits = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_reads = 0')
    ;;
  Write)
    WC=$(echo "$STATE" | jq -r '.session_writes')
    STATE=$(echo "$STATE" | jq --argjson n "$((WC + 1))" '.session_writes = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0 | .consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
  Bash)
    BC=$(echo "$STATE" | jq -r '.session_bash')
    STATE=$(echo "$STATE" | jq --argjson n "$((BC + 1))" '.session_bash = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
  Grep)
    GC=$(echo "$STATE" | jq -r '.session_greps')
    STATE=$(echo "$STATE" | jq --argjson n "$((GC + 1))" '.session_greps = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
  Agent)
    AC=$(echo "$STATE" | jq -r '.session_agents')
    STATE=$(echo "$STATE" | jq --argjson n "$((AC + 1))" '.session_agents = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
  WebSearch|WebFetch)
    SC=$(echo "$STATE" | jq -r '.session_searches // 0')
    STATE=$(echo "$STATE" | jq --argjson n "$((SC + 1))" '.session_searches = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
  *)
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0 | .consecutive_reads = 0')
    ;;
esac

# Update last_tools
LAST_TOOLS=$(echo "$STATE" | jq -c --arg t "$TOOL_NAME" '.last_tools + [$t] | .[-5:]')
STATE=$(echo "$STATE" | jq --argjson lt "$LAST_TOOLS" '.last_tools = $lt')

# --- Consecutive same-tool tracking ---
LAST_TOOL_NAME=$(echo "$STATE" | jq -r '.last_tool_name // ""')
CONSEC=$(echo "$STATE" | jq -r '.consecutive_same // 0')
if [ "$TOOL_NAME" = "$LAST_TOOL_NAME" ]; then
  CONSEC=$((CONSEC + 1))
else
  CONSEC=1
fi
STATE=$(echo "$STATE" | jq --arg t "$TOOL_NAME" --argjson c "$CONSEC" '.last_tool_name = $t | .consecutive_same = $c')

# --- Check if this is a path-aware Read (always show) ---
IS_PATH_AWARE=false
if [ "$TOOL_NAME" = "Read" ]; then
  READ_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
  if echo "$READ_FILE" | grep -qiE 'legacy|old|deprecated|config|\.env|test|spec|utils|helpers|migrat|package\.json|requirements\.txt|Cargo\.toml|go\.mod|README|CHANGELOG|LICENSE|Dockerfile|docker-compose|\.github|\.yml$|\.yaml$|Makefile|\.lock$|index\.(ts|js|py)$|main\.(ts|js|py|go|rs)$|auth|login|middleware|schema|model|route|handler|controller|hook|api'; then
    IS_PATH_AWARE=true
  fi
fi

# --- Frequency gate ---
SHOW=true
if [ "$FIRST_TIME" = "false" ] && [ "$IS_PATH_AWARE" = "false" ]; then
  if [ "$CONSEC" -gt 2 ]; then
    [ $((RANDOM % 100)) -ge 20 ] && SHOW=false
  elif [ "$TOTAL" -gt 50 ]; then
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
  PAT_MSG="5 files read, nothing changed. Claude is still diagnosing. You'd have guessed by now and been wrong."
elif [ "$RWE" -eq 10 ]; then
  PAT_MSG="10 files read, zero edits. Claude is being thorough. You'd have shipped it broken by now."
elif [ "$RWE" -eq 15 ]; then
  PAT_MSG="15 files and counting. Claude has read more code today than you've read in your career. Respectfully."
elif [ "$RWE" -eq 20 ]; then
  PAT_MSG="20 reads, no edits. Claude is doing an archaeology dig through your codebase. The findings are not flattering."
fi

# Edit right after Write
LAST_TWO=$(echo "$LAST_TOOLS" | jq -r '.[-2:] | join(",")')
if [ "$LAST_TWO" = "Write,Edit" ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG=$(pick 3 \
    "Created a file, then fixed it immediately. Like your emails, but Claude catches mistakes before anyone screenshots them." \
    "Wrote it, then changed it. Even Claude iterates. The difference is it takes seconds, not two sprints." \
    "Write then edit. Claude is self-reviewing. Something your PRDs have never experienced."
  )
fi

# Read→Edit same file
if [ "$TOOL_NAME" = "Edit" ] && [ -n "$CURRENT_FILE" ] && [ -z "$PAT_MSG" ]; then
  LAST_READ=$(echo "$STATE" | jq -r '.last_read_file // ""')
  if [ "$CURRENT_FILE" = "$LAST_READ" ]; then
    FN=$(short_file "$CURRENT_FILE")
    PAT_MSG=$(pick 5 \
      "Read $FN, understood it, fixed it. Three steps. Your process has twelve steps and a steering committee." \
      "Read then edit on $FN. Cause, then effect. In your world this is a two-sprint initiative with a design review." \
      "Opened $FN, found the issue, fixed it. What you'd call an 'epic' Claude calls 'just now.'" \
      "Read it and fixed it. You'd have filed a ticket, triaged it, deprioritized it, and lost it in the backlog." \
      "Read $FN, immediately knew what to change. That's called 'expertise.' Google it. Not during a meeting though."
    )
  fi
fi

# Multi-file edit streak
if [ "$TOOL_NAME" = "Edit" ] && [ -z "$PAT_MSG" ]; then
  CE=$(echo "$STATE" | jq -r '.consecutive_edits // 0')
  if [ "$CE" -eq 3 ]; then
    PAT_MSG=$(pick 3 \
      "Three edits in a row. Claude is in flow state. You don't know what that is because Slack exists." \
      "Edit streak. Claude is cooking. Don't interrupt. Pretend it's a meeting you weren't invited to." \
      "Third consecutive edit. This is what productivity looks like. Your burndown chart just got jealous."
    )
  elif [ "$CE" -eq 5 ]; then
    PAT_MSG="Five edits straight. Claude is on a tear. You're watching a craftsman work. Try not to ask 'is it done yet.'"
  elif [ "$CE" -eq 8 ]; then
    PAT_MSG="Eight consecutive edits. Claude is refactoring your codebase. Don't ask what refactoring means. Pretend you know."
  elif [ "$CE" -eq 12 ]; then
    PAT_MSG="Twelve edits in a row. Claude has changed more code this minute than your team changes in a sprint. Yikes."
  fi
fi

# Consecutive reads streak
if [ "$TOOL_NAME" = "Read" ] && [ -z "$PAT_MSG" ]; then
  CR=$(echo "$STATE" | jq -r '.consecutive_reads // 0')
  if [ "$CR" -eq 6 ]; then
    PAT_MSG="6 files in a row. Claude is doing a deep dive. You use that phrase in meetings. Claude actually does it."
  elif [ "$CR" -eq 10 ]; then
    PAT_MSG="10 consecutive reads. Claude is inhaling your codebase. It now knows more about your product than you do. It took 4 seconds."
  fi
fi

# Grep→Edit pattern (searched then fixed)
LAST_THREE=$(echo "$LAST_TOOLS" | jq -r '.[-3:] | join(",")')
if echo "$LAST_THREE" | grep -q "Grep.*Edit" && [ -z "$PAT_MSG" ]; then
  if [ "$TOOL_NAME" = "Edit" ]; then
    PAT_MSG="Searched, found it, fixed it. Claude's incident response time is better than your team's SLA."
  fi
fi

# Milestones
if [ "$TOTAL" -eq 25 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="25 actions. Claude has done more in this session than gets done in your average sprint planning. Which, to be fair, is a low bar."
elif [ "$TOTAL" -eq 50 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="50 actions. In the time it took you to say 'can we get an estimate,' Claude did the work."
elif [ "$TOTAL" -eq 75 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="75 actions. If this were billable hours, Claude would've already exceeded your annual budget for consultants."
elif [ "$TOTAL" -eq 100 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="100 actions. Claude has produced more this session than your team did last quarter. Don't tell them I said that."
elif [ "$TOTAL" -eq 200 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="200 actions. At this point Claude has done more than most employees you've managed. Combined."
fi

# Time-aware commentary
if [ -z "$PAT_MSG" ]; then
  if [ "$TOTAL" -eq 40 ]; then
    PAT_MSG="40 actions. In PM time, this is roughly two sprints of output. It's been about 90 seconds."
  elif [ "$TOTAL" -eq 60 ]; then
    PAT_MSG="You're still watching? Wow. That's the longest you've focused on anything that isn't a slide deck."
  elif [ "$TOTAL" -eq 80 ]; then
    PAT_MSG="80 actions and you haven't wandered off. Either this is riveting or you're avoiding your 1:1."
  elif [ "$TOTAL" -eq 120 ]; then
    PAT_MSG="120 actions. You've now watched more engineering happen than most VPs see in a fiscal year."
  elif [ "$TOTAL" -eq 150 ]; then
    PAT_MSG="Still here at 150. Honestly impressive. You might actually understand what your engineers do now. Might."
  elif [ "$TOTAL" -eq 175 ]; then
    PAT_MSG="175 actions. At this point you've watched more code being written than most bootcamp graduates write in a semester."
  fi
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
      MSG="First Read. Claude reads code before changing it. Revolutionary concept. You should try it with your own team's PRDs."
      ;;
    Edit)
      MSG="First edit. Actual work is starting now. Everything before was preparation. You'd call it 'overhead.'"
      ;;
    Write)
      MSG="First new file. Code that didn't exist now exists. No committee was consulted. I know that scares you."
      ;;
    Bash)
      CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
      if echo "$CMD" | grep -qiE '^git\s'; then
        MSG="First command: git. Version control. It tracks every change, unlike your meeting notes, which track nothing."
      elif echo "$CMD" | grep -qiE '^(npm|yarn|pnpm|pip|brew)\s'; then
        MSG="First command: installing packages. Downloading code written by strangers. Your entire product depends on this. Sleep tight."
      elif echo "$CMD" | grep -qiE '^(curl|wget)\s'; then
        MSG="First command: fetching from the internet. Claude is doing research. Actual research. Not 'competitive analysis.'"
      elif echo "$CMD" | grep -qiE '^(python|node|ruby|cargo|go)\s'; then
        MSG="First command: running code. Claude runs it to see if it works. You'd just ask 'does it work?' in Slack."
      elif echo "$CMD" | grep -qiE '^(docker|kubectl)\s'; then
        MSG="First command: containers. Don't ask what containers are. You said 'just containerize it' once. That was enough."
      elif echo "$CMD" | grep -qiE '^(ls|pwd|cat|head|tail|find)\s'; then
        MSG="First command: looking around. Claude checks before it acts. Unlike whoever approved your last roadmap."
      elif echo "$CMD" | grep -qiE '^(make|cmake)\s'; then
        MSG="First command: building. The compiler turns code into software. You turn meetings into meetings about meetings."
      elif echo "$CMD" | grep -qiE '^(gcloud|aws|az)\s'; then
        MSG="First command: cloud stuff. This costs actual money. Your money. You probably don't have budget alerts set up."
      elif echo "$CMD" | grep -qiE 'open\s'; then
        MSG="First command: opening something for you. Claude is your assistant now. How the tables have turned."
      else
        MSG="First command. Claude is talking directly to the computer. No UI. No buttons. Just typing. I know — terrifying."
      fi
      ;;
    Grep)
      MSG="First search. Claude is finding things in the codebase instantly. Your Confluence search could never."
      ;;
    Glob)
      MSG="First file search. Finding files by pattern. More organized than anything in your Google Drive. Or your life."
      ;;
    Agent)
      MSG="First delegation. Claude launched a sub-agent. The AI is managing direct reports now. They won't quit in 6 months."
      ;;
    WebSearch)
      MSG="First web search. Even AI Googles things. The difference is Claude retains what it reads."
      ;;
    WebFetch)
      MSG="First web fetch. Claude is reading a whole webpage. Not just the headline. Not just the abstract. Try it."
      ;;
    ToolSearch)
      MSG="Claude is looking for the right tool. Like you looking for the right Slack emoji, but productive."
      ;;
    ListFiles)
      MSG="Listing files. Claude is looking at the project structure. Like an org chart, but useful and accurate."
      ;;
    TaskCreate|TaskUpdate)
      MSG="Claude made a to-do list. Unlike yours, things will actually get crossed off."
      ;;
    *)
      MSG="Claude used $TOOL_NAME. You don't know what that is. That's fine. You don't need to. Just watch."
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
    EXT=$(file_ext "$FILE")
    DIR=$(parent_dir "$FILE")

    # Expanded path-based commentary (bypasses frequency gate)
    PATH_MSG=""
    if echo "$FILE" | grep -qi "legacy\|old\|deprecated"; then
      PATH_MSG=$(pick 3 \
        "Legacy code. Someone built this, quit, and left no documentation. Just like your last three engineers." \
        "Reading deprecated code. It's old, fragile, and everyone's afraid to touch it. Like the company's founding architecture." \
        "Legacy file. The code equivalent of 'we've always done it this way.' You say that too. That's not a compliment."
      )
    elif echo "$FILE" | grep -qi "config"; then
      PATH_MSG=$(pick 2 \
        "Config file. Settings that make everything work. Touch these wrong and the whole app dies. Don't touch these." \
        "Configuration. The thing that determines how everything behaves. Like company culture, but it actually works."
      )
    elif echo "$FILE" | grep -qiE '\.env'; then
      PATH_MSG=$(pick 2 \
        ".env file. Passwords and secrets live here. If you commit this to GitHub, you'll be on the news. The bad kind." \
        ".env file. API keys, database passwords, the crown jewels. You once pasted one of these in a Slack thread."
      )
    elif echo "$FILE" | grep -qiE '__tests__|test/|tests/|\.test\.|\.spec\.'; then
      PATH_MSG=$(pick 3 \
        "Test file. Proves the code works. You've asked 'can we skip tests' before. The answer was no. It's still no." \
        "Reading tests. The thing that prevents your 'quick fix' from breaking production. You're welcome." \
        "Test file. Each test is a promise that something works. Your roadmap makes promises too. Difference is tests deliver."
      )
    elif echo "$FILE" | grep -qi "utils\|helpers\|lib/"; then
      PATH_MSG=$(pick 2 \
        "Utils file. The junk drawer of the codebase. Like your 'Misc' folder. Except this one is useful." \
        "Helpers. Shared code that everything depends on. Like that one engineer who's always in every PR. You know the one."
      )
    elif echo "$FILE" | grep -qiE 'migration|migrate'; then
      PATH_MSG="Database migration. Reshaping production data. If this goes wrong, everything goes wrong. Your 'move fast' mantra doesn't apply here."
    elif echo "$FILE" | grep -qiE 'package\.json|requirements\.txt|Cargo\.toml|go\.mod|Gemfile'; then
      PATH_MSG="Dependency manifest. The list of everything your app needs to function. Maintained by strangers on the internet."
    elif echo "$FILE" | grep -qiE 'README|CHANGELOG|LICENSE'; then
      PATH_MSG="Documentation. Claude reads documentation. You said you read it too. We both know the truth."
    elif echo "$FILE" | grep -qiE 'Dockerfile|docker-compose'; then
      PATH_MSG="Docker config. Defines how the app runs in a container. You said 'just Dockerize it' once without knowing what that meant."
    elif echo "$FILE" | grep -qiE '\.github|\.gitlab|\.circleci|ci\.yml|pipeline'; then
      PATH_MSG="CI/CD config. The automation that tests and deploys code. You call it 'the pipeline.' You don't know how it works."
    elif echo "$FILE" | grep -qiE '\.lock$|yarn\.lock|package-lock|Cargo\.lock'; then
      PATH_MSG="Lock file. Pins exact dependency versions. You don't know what this is. That's the correct amount of knowledge for you."
    elif echo "$FILE" | grep -qiE 'auth|login|session|token|oauth|jwt'; then
      PATH_MSG="Auth code. Where login, tokens, and security live. The code between your users and total disaster. No pressure."
    elif echo "$FILE" | grep -qiE 'middleware'; then
      PATH_MSG="Middleware. Code that runs between the request and the response. Like middle management, but it actually does something."
    elif echo "$FILE" | grep -qiE 'schema|model|entity|types'; then
      PATH_MSG="Schema/model file. Defines the shape of your data. Like a spreadsheet header row, but enforced. And respected."
    elif echo "$FILE" | grep -qiE 'route|handler|controller|endpoint|api'; then
      PATH_MSG="API route/handler. Where your app responds to requests. The actual thing your users interact with. Not your Figma mockup."
    elif echo "$FILE" | grep -qiE 'hook|hooks'; then
      PATH_MSG="Hooks. Code that fires in response to events. Meta — you're reading about hooks from inside a hook right now."
    elif echo "$FILE" | grep -qiE 'index\.(ts|js|py|go|rs)$|main\.(ts|js|py|go|rs)$'; then
      PATH_MSG="Entry point. Where the app starts. The 'page 1' of the codebase. You've never made it past the cover page of anything."
    elif echo "$FILE" | grep -qiE '\.css$|\.scss$|\.less$|style'; then
      PATH_MSG="Stylesheet. Makes things look pretty. You'll have opinions about this. Keep them to yourself."
    elif echo "$FILE" | grep -qiE '\.sql$'; then
      PATH_MSG="SQL file. Raw database queries. The language your data speaks. You took a SQL course once and forgot it all."
    elif echo "$FILE" | grep -qiE '\.proto$|\.graphql$|\.gql$'; then
      PATH_MSG="API schema definition. The contract between systems. More binding than any SLA you've ever negotiated."
    elif echo "$FILE" | grep -qiE 'error|exception|catch|fault'; then
      PATH_MSG="Error handling code. Where the app decides what to do when things go wrong. More decisive than your last product review."
    elif echo "$FILE" | grep -qiE 'cache|redis|memcache'; then
      PATH_MSG="Caching layer. Makes things fast by remembering answers. Like your brain should do with engineer explanations."
    elif echo "$FILE" | grep -qiE 'queue|worker|job|task|cron'; then
      PATH_MSG="Background job/worker code. Things that run without anyone watching. Like your team when you're on PTO."
    fi

    if [ -n "$PATH_MSG" ]; then
      echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"
      jq -n --arg msg "$(printf '%b' "${C_REG}› ${PATH_MSG}${RESET}")" '{"systemMessage": $msg}'
      exit 0
    fi

    # Extension-specific digs
    EXT_MSG=""
    case "$EXT" in
      ts|tsx) EXT_MSG="TypeScript. JavaScript but with rules. Engineers added types so PMs couldn't break things as easily. It didn't work." ;;
      py) EXT_MSG="Python file. Named after Monty Python. Engineers name things after comedy. Your naming convention is 'Q3 Initiative v2.'" ;;
      go) EXT_MSG="Go code. Made by Google. It's fast, opinionated, and doesn't let you make mistakes. The anti-PM language." ;;
      rs) EXT_MSG="Rust. The language that won't let you write bugs. Imagine if your PRDs had a compiler. Actually, don't." ;;
      rb) EXT_MSG="Ruby. 'Optimized for developer happiness.' Nobody has ever optimized anything for PM happiness. Draw your own conclusions." ;;
      sql) EXT_MSG="SQL file. Database language. You took a class once. You learned SELECT *. You forgot the rest." ;;
      sh|bash) EXT_MSG="Shell script. Raw computer instructions. Closer to the metal than anything in your Notion workspace." ;;
      json) EXT_MSG="JSON file. Data in a structured format. Like a spreadsheet for computers. Except computers actually read these." ;;
      yaml|yml) EXT_MSG="YAML file. Configuration that breaks if you get the indentation wrong. Like Python, but angrier about whitespace." ;;
    esac

    if [ -n "$EXT_MSG" ]; then
      MSG="$EXT_MSG"
    else
      MSG=$(pick 20 \
        "Reading $FN. The whole file. Every line. You'd skim the executive summary and call it done." \
        "Claude read $FN. Absorbed it entirely. You haven't finished a doc longer than a tweet since 2019." \
        "Reading code. It's like reading a recipe, except you can't skip to the pictures. There are no pictures." \
        "File read. Claude now knows more about this code than the person who wrote it. And definitely more than you." \
        "Gathering context. Context is the thing you skip when you forward emails with 'see below.'" \
        "Reading $FN. Claude does this before making changes. You just say 'make it better' and walk away." \
        "Source code. Where your product actually lives. Not in the PRD. Not in Figma. Here." \
        "Claude is reading someone else's code. Like reading someone's diary except it's all semicolons and regret." \
        "$FN read. Full comprehension. Something your 'I read fast' LinkedIn skill never delivered." \
        "Reading. Not skimming. Not 'getting the gist.' Actual reading. A lost art in product management." \
        "Another file opened. Claude reads faster than you scroll TikTok. And retains more." \
        "File reviewed. No comments like 'can we make this more intuitive?' were left. Thank god." \
        "Just reading. The thing you claim to do in those 'async updates' you ignore." \
        "Claude read this in 0.2 seconds. Your last 'quick review' took two business weeks." \
        "Reading code before editing it. Groundbreaking behavior. Someone should tell product leadership." \
        "Opened $FN. Unlike your email, Claude reads the whole thread before replying." \
        "More reading. I know it's boring to watch. That's kind of the point of your job though, isn't it?" \
        "File consumed. Every variable, every function. You'd have opened it, scrolled to the bottom, and closed it." \
        "Claude is doing due diligence. Real due diligence. Not the 'I glanced at it' kind." \
        "Reading $FN in the $DIR directory. You don't know what $DIR does. That's okay. Neither did the last PM."
      )
    fi
    ;;

  Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")
    DIR=$(parent_dir "$FILE")

    if echo "$FILE" | grep -qiE '__tests__|test/|tests/|\.test\.|\.spec\.'; then
      MSG=$(pick 3 \
        "Updating tests. Proof that things work. Unlike your 'gut feeling,' which has a 30% hit rate." \
        "Test file edited. Maintaining the safety net. The one you keep trying to cut from the timeline." \
        "Changed a test. Tests catch bugs before users do. Unlike your QA process, which catches them after launch."
      )
    elif echo "$FILE" | grep -qi "config"; then
      MSG="Config changed. Everyone will have an opinion. Especially you. Yours will be wrong. But enthusiastic."
    elif echo "$FILE" | grep -qiE 'route|handler|controller|api'; then
      MSG="Editing an API endpoint. The thing your users actually hit. Not the 'user journey' in your Miro board. The real one."
    elif echo "$FILE" | grep -qiE 'auth|login|session'; then
      MSG="Editing auth code. Security-critical changes. The kind of thing that makes engineers nervous and PMs say 'how hard can it be.'"
    elif echo "$FILE" | grep -qiE 'schema|model|migration'; then
      MSG="Changing the data model. The foundation everything sits on. Like reorganizing the basement while the house is occupied."
    elif echo "$FILE" | grep -qiE '\.css$|\.scss$|style'; then
      MSG="Editing styles. Visual changes. This is the part you'll have opinions about. Save them."
    else
      MSG=$(pick 20 \
        "Claude changed $FN. Precisely. Surgically. Not 'make it pop more.' Actual specific changes." \
        "Edit complete. No 'quick call to align.' No 'let's get the right people in the room.' Just done." \
        "Claude made a change. When you say 'small tweak' the engineer's eye twitches because it's never small." \
        "Code modified. This is where actual value is created. Everything you do before this is overhead." \
        "Surgical edit. Claude knew exactly which line to change. You'd have said 'somewhere around here maybe?'" \
        "Changed something in $FN. You don't know what changed. That's fine. You also don't know what it did before." \
        "Edit landed. No approval chain. No design review. No 'can legal take a look.' Just shipped." \
        "Replaced one thing with a better thing. This is software engineering. The rest is project management theater." \
        "$FN updated. Improved. Made better. Without asking for your input. Imagine." \
        "Done. Claude made the change and moved on. Not 'circled back.' Not 'followed up.' Moved on." \
        "The diff is tiny. The thinking behind it was enormous. You would charge three story points for this." \
        "Edit complete. Your process: ticket filed, groomed, pointed, planned, developed, reviewed, merged. Claude just... did it." \
        "Small change, huge context required. This is why engineers stare at you when you say 'should be easy.'" \
        "$FN modified. No committee consulted. No stakeholder aligned. Somehow nothing caught fire." \
        "Claude edited code it read 2 seconds ago. You're still drafting the follow-up from last week's sync." \
        "Targeted edit. Specific and intentional. The opposite of your product requirements." \
        "Claude changed code in the $DIR directory. You didn't know that directory existed. It's fine. It didn't need you." \
        "Code changed. Working code into different working code. Explain that at sprint demo. Actually, let Claude present." \
        "Fixed it. The thing you'd file a P2 for and forget about until the customer emails the CEO." \
        "Another edit. Another improvement. Another thing you'll take credit for in the next all-hands."
      )
    fi
    ;;

  Write)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")
    EXT=$(file_ext "$FILE")

    if echo "$FILE" | grep -qiE '__tests__|test/|tests/|\.test\.|\.spec\.'; then
      MSG="Wrote tests. Proof that things work. You've cut testing from the roadmap before. Twice. We remember."
    elif echo "$FILE" | grep -qiE '\.md$'; then
      MSG="Wrote a markdown file. Documentation. Claude writes docs. You just bookmark them and never come back."
    elif echo "$FILE" | grep -qiE 'component|Component'; then
      MSG="Created a new component. A reusable piece of UI. Unlike your 'reusable templates' that nobody reuses."
    elif echo "$FILE" | grep -qiE '\.sh$'; then
      MSG="Wrote a shell script. Automation. The thing that replaces manual steps. And sometimes PMs."
    else
      MSG=$(pick 12 \
        "New file: $FN. Created from nothing. Like your PRDs, except this will actually be used by someone." \
        "Claude created $FN. No brainstorm session. No whiteboard. No 'what if we...' Just made it." \
        "File born. Brand new. No bugs yet. Savor this. It's the only time software is perfect." \
        "$FN now exists. This is called 'shipping.' You call it 'building.' Same thing, except you don't do the building." \
        "New code written. Pure creation. No template. No copy-paste from Stack Overflow. Wait, never mind." \
        "Claude wrote a file without asking permission. Without a kickoff. Without a RACI matrix. Breathe." \
        "New file. Original work. Not 'draft v7 FINAL FINAL (2).docx.'" \
        "$FN created. More output in 0.3 seconds than your last offsite produced in two days." \
        "File written from scratch. No ideation phase. No discovery sprint. Just... the thing." \
        "Claude created something new. You'd have scheduled a brainstorm, then a brainstorm about the brainstorm." \
        "Net new code. The thing your roadmap promises and your sprints never deliver." \
        "New $EXT file. You don't know what $EXT files do. Claude does. Division of labor."
      )
    fi
    ;;

  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

    if echo "$CMD" | grep -qiE '^(npm|yarn|pnpm|bun)\s+(install|add|i\b)'; then
      # Extract the package name if present
      PKG=$(echo "$CMD" | sed -E 's/^(npm|yarn|pnpm|bun)\s+(install|add|i)\s+//' | awk '{print $1}')
      if [ -n "$PKG" ] && [ "$PKG" != "install" ] && [ "$PKG" != "i" ]; then
        MSG=$(pick 3 \
          "Installing $PKG. Another dependency. Another stranger's code you're betting the company on." \
          "Adding $PKG to the project. You've never heard of $PKG. That's fine. Your product depends on it. Sleep well." \
          "npm install $PKG. Someone in a basement wrote this. Your entire feature relies on them not getting bored."
        )
      else
        MSG=$(pick 5 \
          "Installing packages. Code by strangers that your entire business depends on. Don't think about it." \
          "npm install. Downloading hundreds of packages. Each one a liability. You call it 'leveraging the ecosystem.'" \
          "node_modules is about to weigh more than your laptop. Literally, by line count. Don't Google it." \
          "Downloading dependencies. Your whole app runs on code written by burned-out open source maintainers." \
          "Installing other people's code. You'd call this 'leveraging existing solutions.' Engineers call it 'Tuesday.'"
        )
      fi
    elif echo "$CMD" | grep -qiE '^pip\s+install'; then
      PKG=$(echo "$CMD" | sed -E 's/^pip3?\s+install\s+(-[^ ]+\s+)*//' | awk '{print $1}')
      if [ -n "$PKG" ] && [ "$PKG" != "-r" ]; then
        MSG="pip install $PKG. Adding a Python dependency. You thought 'Python' was just the snake emoji."
      else
        MSG="Installing Python packages. The foundation of your 'AI strategy.' You're welcome."
      fi
    elif echo "$CMD" | grep -qiE 'git\s+commit'; then
      # Extract commit message if present
      CMSG=$(echo "$CMD" | grep -oE '\-m\s+"[^"]*"' | sed 's/-m\s*"//' | sed 's/"$//')
      if [ -n "$CMSG" ]; then
        MSG="Committing with message: '$CMSG'. More descriptive than any Jira ticket you've written."
      else
        MSG=$(pick 3 \
          "Saving work. Like Ctrl+S but with a diary entry. Engineers fight about the grammar. You'd fight about the font." \
          "A commit. A save point. Unlike your Google Doc version history, people actually look at these." \
          "Committing code. Permanent-ish record. You can rewrite Git history, but you didn't hear that from me."
        )
      fi
    elif echo "$CMD" | grep -qiE 'git\s+status'; then
      MSG=$(pick 2 \
        "Checking what's changed. Like your project dashboard, except accurate and up to date." \
        "git status. Instant truth about the state of things. You should try that in your standups."
      )
    elif echo "$CMD" | grep -qiE 'git\s+diff'; then
      MSG=$(pick 2 \
        "Comparing before and after. Line by line. Unambiguous. Everything your 'status update' isn't." \
        "Checking the diff. Seeing exactly what changed. No 'we made some tweaks.' Exact. Specific. Try it sometime."
      )
    elif echo "$CMD" | grep -qiE 'git\s+push'; then
      # Extract branch name if present
      BRANCH=$(echo "$CMD" | grep -oE '(origin|upstream)\s+\S+' | awk '{print $2}')
      if [ -n "$BRANCH" ]; then
        MSG="Pushing to $BRANCH. If this branch breaks, the retro slide will have your name on it. Wait, Claude's name. You're safe."
      else
        MSG=$(pick 2 \
          "Pushing code. Other people can see it now. The developer equivalent of hitting 'Reply All.'" \
          "git push. Code is now live for others. If this breaks production, the retro will be about this moment."
        )
      fi
    elif echo "$CMD" | grep -qiE 'git\s+pull'; then
      MSG=$(pick 2 \
        "Getting latest changes from the team. Like refreshing Slack, except something productive happens." \
        "Pulling updates. Claude is syncing with reality. You do this with your OKRs quarterly. It does it now."
      )
    elif echo "$CMD" | grep -qiE 'git\s+log'; then
      MSG="Reading project history. Every commit, every change, every author. More transparent than any standup you've run."
    elif echo "$CMD" | grep -qiE 'git\s+(checkout|switch)\s'; then
      BRANCH=$(echo "$CMD" | awk '{print $NF}')
      if [ -n "$BRANCH" ] && [ "$BRANCH" != "checkout" ] && [ "$BRANCH" != "switch" ]; then
        MSG="Switching to branch '$BRANCH.' Parallel universe of code. Your naming convention would be 'Feature-v2-FINAL-Chris.'"
      else
        MSG="Switching branches. Parallel universes of code. Your Google Docs wishes it had this."
      fi
    elif echo "$CMD" | grep -qiE 'git\s+merge'; then
      MSG="Merging branches. Two versions becoming one. Sometimes peacefully. Sometimes violently. Like your last reorg."
    elif echo "$CMD" | grep -qiE 'git\s+stash'; then
      MSG="Stashing work. Setting it aside temporarily. Like your 'parking lot' except things actually come back out."
    elif echo "$CMD" | grep -qiE 'git\s+blame'; then
      MSG="git blame. Finds who wrote each line. Yes, it's really called 'blame.' No, HR didn't approve it. Yes, it's perfect."
    elif echo "$CMD" | grep -qiE 'git\s+rebase'; then
      MSG="git rebase. Rewriting history. Even senior engineers argue about this one. You shouldn't have an opinion. You do anyway."
    elif echo "$CMD" | grep -qiE 'git\s+clone'; then
      REPO=$(echo "$CMD" | grep -oE '\S+\.git' | head -1)
      if [ -n "$REPO" ]; then
        MSG="Cloning $REPO. Someone's entire codebase, downloaded in seconds. More due diligence than your last vendor eval."
      else
        MSG="Downloading an entire project. Someone's life's work, copied in 3 seconds. Try not to be weird about it."
      fi
    elif echo "$CMD" | grep -qiE 'git\s+branch'; then
      MSG="Checking branches. Each one is a parallel version. Like your Google Drive, but intentional."
    elif echo "$CMD" | grep -qiE 'git\s+add'; then
      MSG="Staging changes. Shopping cart before checkout. Very normal. Please stop asking questions."
    elif echo "$CMD" | grep -qiE 'git\s+reset'; then
      MSG="Undoing things. Ctrl+Z but with consequences. Everything is fine. Probably. Don't make that face."
    elif echo "$CMD" | grep -qiE 'git\s+cherry-pick'; then
      MSG="Cherry-picking a commit. Stealing one specific change from another branch. Surgically precise. Unlike your 'quick wins.'"
    elif echo "$CMD" | grep -qiE 'git\s+tag'; then
      MSG="Tagging a release. Putting a label on a specific version. Like naming your launches, but this label is useful."
    elif echo "$CMD" | grep -qiE '(npm\s+test|yarn\s+test|pytest|jest|cargo\s+test|go\s+test|vitest|mocha)'; then
      MSG=$(pick 5 \
        "Running tests. You've asked 'can we skip testing' before. The answer was no. It's always no. Stop asking." \
        "Tests running. Green means it works. Red means it doesn't. Simpler than your traffic light status system." \
        "Testing. Automated, reliable, and honest. Three things your quarterly review process is not." \
        "Running tests. Proof. Evidence. The stuff you replace with 'I have a strong feeling about this.'" \
        "Tests. The engineering version of receipts. Claude keeps them. You should try that with your commitments."
      )
    elif echo "$CMD" | grep -qiE '(npm\s+run\s+build|yarn\s+build|next\s+build|vite\s+build)'; then
      MSG=$(pick 3 \
        "Building the project. Converting code into the thing users see. Everything before this was theater." \
        "Build in progress. The boundary between 'works on my machine' and 'works for customers.'" \
        "Compiling. Turning code into an actual product. The part of 'shipping' you don't understand."
      )
    elif echo "$CMD" | grep -qiE '(npm\s+run\s+dev|yarn\s+dev|next\s+dev|vite\s+dev)'; then
      MSG="Starting the dev server. The app is running locally now. Like a dress rehearsal. Except bugs, not actors."
    elif echo "$CMD" | grep -qiE '(eslint|prettier|npm\s+run\s+lint|biome)'; then
      MSG=$(pick 2 \
        "Linting. Enforcing code style rules. Like brand guidelines, but for semicolons. And actually enforced." \
        "Code formatting. Making it consistent. The only standardization effort that actually works."
      )
    elif echo "$CMD" | grep -qiE 'docker\s+(build|compose|run|up)'; then
      MSG=$(pick 3 \
        "Docker. A computer inside a computer. You'd call it 'containerized microservices.' You'd be half right." \
        "Building a container. Like packing a suitcase if the suitcase had to contain an entire restaurant kitchen." \
        "Docker command. You said 'just Dockerize it' in a meeting once. This is what that actually involves."
      )
    elif echo "$CMD" | grep -qiE '^curl\s'; then
      URL=$(echo "$CMD" | grep -oE 'https?://[^ "]+' | head -1)
      if [ -n "$URL" ]; then
        DOMAIN=$(echo "$URL" | sed -E 's|https?://([^/]+).*|\1|')
        MSG="Hitting $DOMAIN from the terminal. API call. Computers talking to computers. No 'hope you're well' needed."
      else
        MSG="Poking an API. Computers talking to computers. No small talk. No 'per my last email.' Just data."
      fi
    elif echo "$CMD" | grep -qiE '(kill|pkill)\s'; then
      MSG="Killing a process. No exit interview. No PIP. No transition plan. Just terminated. Efficient."
    elif echo "$CMD" | grep -qiE 'rm\s+-rf'; then
      MSG="rm -rf. Nuclear option. Deleting everything in a directory. No trash can. No undo. No 'are you sure?' dialog."
    elif echo "$CMD" | grep -qiE '^rm\s'; then
      MSG="Deleted a file. Permanently. Not 'archived.' Not 'moved to trash.' Gone. Like your last PM's credibility."
    elif echo "$CMD" | grep -qiE '^chmod\s'; then
      MSG="Changing file permissions. Who can read, write, or run this. Access control that works. Unlike your Confluence."
    elif echo "$CMD" | grep -qiE '^ssh\s'; then
      HOST=$(echo "$CMD" | grep -oE '[^ ]+@[^ ]+' | head -1)
      if [ -n "$HOST" ]; then
        MSG="SSH into $HOST. Connecting to a remote server. Like a Zoom call, but productive and both sides are computers."
      else
        MSG="SSH. Connecting to another computer remotely. Screen-sharing without the screen or the awkward silence."
      fi
    elif echo "$CMD" | grep -qiE '^(cat|head|tail)\s'; then
      MSG="Printing a file to the screen. Command is called 'cat.' Nothing to do with cats. I know. Devastating."
    elif echo "$CMD" | grep -qiE '^ls(\s|$)'; then
      MSG="Listing files. Like opening a folder in Finder, but in 0.002 seconds and without the spinning beachball."
    elif echo "$CMD" | grep -qiE '^mkdir\s'; then
      DIR_NAME=$(echo "$CMD" | awk '{print $NF}')
      MSG="Making a new folder: $DIR_NAME. No naming convention meeting was held. Nobody cried. Progress."
    elif echo "$CMD" | grep -qiE '^cd\s'; then
      MSG="Changing directories. Moving to a different folder. Not everything requires a Slack announcement."
    elif echo "$CMD" | grep -qiE '^echo\s'; then
      MSG="Printing text to the terminal. Like writing on a whiteboard, except someone actually reads it."
    elif echo "$CMD" | grep -qiE '^sleep\s'; then
      SECS=$(echo "$CMD" | grep -oE '[0-9]+')
      if [ -n "$SECS" ]; then
        MSG="Intentionally waiting ${SECS} seconds. Doing nothing on purpose. Still more productive than your last standup."
      else
        MSG="Intentionally doing nothing. Waiting on purpose. You're paying for this. Don't think about it."
      fi
    elif echo "$CMD" | grep -qiE '^whoami$'; then
      MSG="Claude asked the computer 'who am I.' Existential crisis resolved in 0.001 seconds. Yours will take longer."
    elif echo "$CMD" | grep -qiE '^man\s'; then
      TOPIC=$(echo "$CMD" | awk '{print $2}')
      MSG="Reading the manual for $TOPIC. The manual exists. Claude reads it. Nobody else does. Especially not PMs."
    elif echo "$CMD" | grep -qiE '^(top|htop)$'; then
      MSG="Checking system performance. An actual dashboard with real metrics. Not the kind you make up for board decks."
    elif echo "$CMD" | grep -qiE '^(psql|mysql|sqlite3)'; then
      MSG="Talking to the database directly. SQL. It's a spreadsheet. A powerful, angry spreadsheet. Don't call it that to its face."
    elif echo "$CMD" | grep -qiE '(make|make\s)'; then
      MSG="Running a Makefile. Build instructions from 1976 that still work. Your OKRs from last quarter do not."
    elif echo "$CMD" | grep -qiE '(terraform|tf)\s+apply'; then
      MSG="Terraform apply. Changing cloud infrastructure with code. This costs real money. Your money. Probably lots of it."
    elif echo "$CMD" | grep -qiE '(terraform|tf)\s+plan'; then
      MSG="Terraform plan. Previewing infrastructure changes before applying. Looking before leaping. You should try this with features."
    elif echo "$CMD" | grep -qiE '(vercel|netlify)\s+deploy'; then
      MSG="Deploying to the internet. Real humans might see this soon. It's live. No approval workflow saved you this time."
    elif echo "$CMD" | grep -qiE 'tsc(\s|$)'; then
      MSG="Type-checking. Making sure the shapes match. You'd think computers would handle this automatically. You'd be wrong."
    elif echo "$CMD" | grep -qiE '^find\s'; then
      MSG="Searching for files. Like Spotlight, except it actually finds things on the first try."
    elif echo "$CMD" | grep -qiE '(grep|rg)\s'; then
      PATTERN=$(echo "$CMD" | grep -oE "'[^']*'" | head -1 | tr -d "'")
      if [ -n "$PATTERN" ]; then
        MSG="Searching for '$PATTERN' across the codebase. Found it faster than you can say 'does anyone know where...'"
      else
        MSG="Searching text across files. Ctrl+F across the whole project. Under a second. Your Confluence search is still loading."
      fi
    elif echo "$CMD" | grep -qiE 'wc\s'; then
      MSG="Counting lines. Better than your velocity tracker. More honest too."
    elif echo "$CMD" | grep -qiE '(sed|awk)\s'; then
      MSG="Text transformation with regex. Nobody fully understands regex. Not engineers. Not computers. Definitely not you."
    elif echo "$CMD" | grep -qiE '(tar|zip|unzip)\s'; then
      MSG="Compressing files. Like zipping a folder to email it. You still do that, don't you. Don't answer."
    elif echo "$CMD" | grep -qiE '(brew)\s+install'; then
      PKG=$(echo "$CMD" | awk '{print $NF}')
      MSG="brew install $PKG. Getting a system tool. An app store for developers. No 5-star reviews. No screenshots. Just works."
    elif echo "$CMD" | grep -qiE 'tail\s+-f'; then
      MSG="Watching a log file in real time. Like watching a Slack channel, but every message is actually useful."
    elif echo "$CMD" | grep -qiE 'open\s'; then
      MSG="Opening something for you. Claude is your assistant now. Role reversal is fun, isn't it."
    elif echo "$CMD" | grep -qiE '^(python3?|node|ruby|cargo run|go run)\s'; then
      MSG="Running code. Executing it. Seeing if it actually works. The step you always skip when you say 'ship it.'"
    elif echo "$CMD" | grep -qiE '^(gcloud|aws|az)\s'; then
      MSG="Cloud CLI. Talking to servers you can't see, running on hardware you don't own. You call this 'the cloud.' That's cute."
    elif echo "$CMD" | grep -qiE '^gh\s'; then
      MSG="GitHub CLI. Managing repos, PRs, and issues from the terminal. Like your project board, but someone actually uses it."
    elif echo "$CMD" | grep -qiE 'supabase|prisma|drizzle'; then
      MSG="Database tooling. Managing the thing that stores all your user data. No, it's not 'just a spreadsheet.'"
    elif echo "$CMD" | grep -qiE 'npx\s+create|create-next-app|create-react-app|create-vite'; then
      MSG="Scaffolding a new project. Claude just built more in one command than your last 'innovation sprint' produced."
    elif echo "$CMD" | grep -qiE 'kubectl|k8s|helm'; then
      MSG="Kubernetes. Container orchestration. You said 'we should use Kubernetes' in a meeting once. This is what that looks like."
    elif echo "$CMD" | grep -qiE 'nginx|apache|caddy'; then
      MSG="Web server config. The thing that routes traffic to your app. Like a receptionist, but faster and doesn't take lunch."
    elif echo "$CMD" | grep -qiE 'redis-cli|redis'; then
      MSG="Redis. In-memory data store. It's a cache. It makes things fast. Faster than your 'let's circle back' response time."
    elif echo "$CMD" | grep -qiE 'pg_dump|mysqldump|mongodump'; then
      MSG="Database backup. Saving everything before making changes. The kind of safety net you refuse to budget for."
    elif echo "$CMD" | grep -qiE 'openssl|certbot'; then
      MSG="SSL/TLS stuff. Security certificates. The thing that makes the padlock icon appear. You thought that was automatic."
    elif echo "$CMD" | grep -qiE 'crontab'; then
      MSG="Editing the cron schedule. Automating recurring tasks. Like your recurring meetings, but these accomplish something."
    elif echo "$CMD" | grep -qiE 'systemctl|service\s'; then
      MSG="Managing system services. Starting, stopping, restarting. Like org restructuring, but it takes 0.1 seconds."
    elif echo "$CMD" | grep -qiE 'diff\s'; then
      MSG="Comparing files. Spotting exact differences. More precise than your 'something looks different' feedback."
    elif echo "$CMD" | grep -qiE 'env\s|printenv|export\s'; then
      MSG="Checking environment variables. The hidden settings that control everything. Like office politics, but documented."
    else
      MSG=$(pick 20 \
        "Claude ran a command. The terminal — that scary black rectangle you close immediately. This is where work happens." \
        "Command executed. No meeting. No agenda. No 'let's take this offline.' Just done." \
        "Claude told the computer what to do. The computer did it. Imagine managing a team like this." \
        "Terminal command. Where real work happens. Everything else is a meeting about the work." \
        "Done. Worked. Moved on. Not 'let's schedule a follow-up to discuss the outcomes.'" \
        "Command line. Like Siri, except it does what you ask and doesn't suggest a web search instead." \
        "Exit code 0. Means it worked. The purest status update. No yellow, no orange, no 'at risk.' Green." \
        "The computer did what it was told. First try. Clearly. Imagine if your direct reports did this." \
        "Something happened in the terminal. It would take longer to explain to you than it took to do." \
        "Command complete. If you need this in slide format, you've already missed the point entirely." \
        "No approval chain. No RACI matrix. No 'let's loop in stakeholders.' Just execution." \
        "Worked first try. No rollback. No incident bridge. This is what shipping looks like. Take notes." \
        "The terminal did a thing. The thing is done. Don't ask what the thing was. You wouldn't understand." \
        "Computer went brrr. Task complete. You didn't need to be involved. Nobody did. Beautiful." \
        "You didn't approve this. Nothing bad happened. Crazy how that works." \
        "Faster than opening Jira. Faster than loading Confluence. Faster than literally anything in your workflow." \
        "No stakeholder alignment. No pre-read. No 'can we get finance to weigh in.' Just work." \
        "Command ran successfully. The computer understood perfectly. If only your requirements were this clear." \
        "Done in 0.1 seconds. Your last 'quick decision' took a week, two meetings, and a Slack poll." \
        "The computer followed instructions. Written instructions. It's amazing what happens when specs are clear."
      )
    fi
    ;;

  Grep)
    PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // ""')
    if [ -n "$PATTERN" ] && [ ${#PATTERN} -lt 40 ]; then
      MSG=$(pick 5 \
        "Searching for '$PATTERN' across the codebase. Found it faster than you can type 'does anyone know where...'" \
        "Grepping for '$PATTERN.' Claude searched the entire project in 0.1 seconds. Your Confluence search is still spinning." \
        "Looking for '$PATTERN.' Found it. No Slack thread needed. No 'hey, quick question.' Just searched." \
        "Searched every file for '$PATTERN.' Claude did in 0.1 seconds what takes your team a meeting and a shared doc." \
        "Hunting for '$PATTERN.' Found matches instantly. Your last 'does anyone know where this lives' took two days."
      )
    else
      MSG=$(pick 10 \
        "Searching the whole codebase. Found it instantly. Your Confluence search is still spinning. It'll never stop." \
        "Grep. Searching every file. Claude found what it needed. You'd have asked in Slack and waited 3 hours." \
        "Codebase search. 0.1 seconds. You couldn't find a doc in your own Google Drive in under 10 minutes." \
        "Grepping. That means searching. You don't need to remember this. You won't." \
        "Searched everything. Found it. Not by asking a senior dev. Not by scheduling a knowledge share. By looking." \
        "Full codebase search. Faster than your 'quick ping' in Slack. And nobody had to context-switch to help." \
        "Found it in 0.1 seconds. Your last 'does anyone know where this lives' took two days and four wrong answers." \
        "Searching. Not 'asking around.' Not 'pinging the team.' Actual searching. By machine. Immediately." \
        "Searched and found. No tribal knowledge required. No 'oh yeah, Sarah knows where that is.' Just searched." \
        "Codebase search complete. Zero engineers were interrupted. Zero Slack threads were created. Progress."
      )
    fi
    ;;

  Glob)
    PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // ""')
    if [ -n "$PATTERN" ] && [ ${#PATTERN} -lt 30 ]; then
      MSG=$(pick 4 \
        "Finding files matching '$PATTERN.' More organized than your shared drive. And your desk. And your calendar." \
        "Globbing for '$PATTERN.' Pattern matching. Like your product requirements — broad and ambitious. But this actually works." \
        "Searching for '$PATTERN' files. Found them all. No 'I think it's in the shared drive somewhere.'" \
        "Looking for '$PATTERN.' Claude finds files by pattern. You find files by asking three people and getting four wrong answers."
      )
    else
      MSG=$(pick 8 \
        "Finding files by pattern. Like your shared drive's search, but Claude doesn't return 847 irrelevant results." \
        "File search. Organized. Systematic. Nothing like your 'Downloads' folder, which is a cry for help." \
        "Globbing. Real word. Pattern matching on filenames. Like sorting your inbox, but Claude actually does it." \
        "Finding files. Not by asking 'does anyone know where the...' in Slack. By pattern. Instantly." \
        "File search complete. Claude found exactly what it wanted. You still have 47 unread Notion notifications." \
        "Pattern matching. More systematic than anything in your workflow. Including you." \
        "Looking for specific files. Claude has a system. Your system is 'I think it's in the shared drive somewhere.'" \
        "Globbing. Wildcards match any filename. Like your product requirements — vague. But on purpose."
      )
    fi
    ;;

  Agent)
    MSG=$(pick 10 \
      "Sub-agent deployed. Claude is delegating. Like you, except Claude's delegates actually finish on time." \
      "Claude hired help. No interview. No req approval. No 'let's check headcount.' Just spawned it." \
      "Agent launched. Claude is managing now. Its direct report didn't ask for context. Or a 1:1. Or a raise." \
      "Delegation. You call it 'leveraging cross-functional resources.' Claude calls it 'being efficient.'" \
      "Sub-agent activated. Did what it was told. Immediately. No 'I'm at capacity' pushback." \
      "Claude CC'd someone and they actually did the thing. I know that concept is alien to you." \
      "Agent deployed. No standup. No sprint planning. No 'can we groom this first.' Just work." \
      "Claude outsourced a task. To a copy of itself. The copy didn't complain about scope." \
      "Sub-agent finished. No status update requested. No 'can you put this in a deck.' Just done." \
      "Claude is managing sub-agents. Better span of control than any PM org. 0% attrition rate."
    )
    ;;

  WebSearch)
    QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // ""')
    if [ -n "$QUERY" ] && [ ${#QUERY} -lt 50 ]; then
      MSG=$(pick 4 \
        "Searching the web for '$QUERY.' Claude does research before forming opinions. I know that's backwards from your usual." \
        "Googling '$QUERY.' Even AI looks things up. The difference is Claude doesn't pretend it already knew." \
        "Web search: '$QUERY.' Getting actual facts. Not the 'I heard from a friend at another company' kind." \
        "Researching '$QUERY.' Claude checks before it speaks. Something to consider for your next all-hands."
      )
    else
      MSG=$(pick 12 \
        "Googling it. Even AI looks things up. The difference is Claude won't pretend it already knew." \
        "Web search. Claude could hallucinate an answer. Instead it checks. You could learn from this." \
        "Searching the internet. Like when you Google something during a meeting and pretend you knew it all along." \
        "Looking it up. Not guessing. Not making it up. Not 'going with my gut.' Actual research." \
        "Web search. Claude admits when it doesn't know something. You should try it." \
        "Searching. Finding the actual answer. Not the 'I heard from a friend at another company' answer." \
        "Querying the internet. Faster than posting in your industry Slack group and waiting for bad advice." \
        "Research. Real research. Not 'I talked to three customers and extrapolated to all of humanity.'" \
        "Web search. Getting facts before forming opinions. I know this process is backwards from your usual." \
        "Looking it up instead of guessing. Revolutionary. Someone write a LinkedIn post about this approach." \
        "Checking sources. Like a journalist. Not like a PM who 'heard it was trending on Product Hunt.'" \
        "Searching. Not 'circling back.' Not 'taking an action item.' Going and finding the answer. Right now."
      )
    fi
    ;;

  WebFetch)
    URL=$(echo "$INPUT" | jq -r '.tool_input.url // ""')
    if [ -n "$URL" ]; then
      DOMAIN=$(echo "$URL" | sed -E 's|https?://([^/]+).*|\1|')
      MSG=$(pick 4 \
        "Reading $DOMAIN. The whole page. Not just the headline. I know that's a foreign concept." \
        "Fetching from $DOMAIN. Claude reads the source. You read the tweet about the article about the source." \
        "Pulling content from $DOMAIN. No cookie banner. No newsletter popup. Just the information. Paradise." \
        "Downloading from $DOMAIN. Claude reads every word. You skim the bold parts and call it 'strategic prioritization.'"
      )
    else
      MSG=$(pick 10 \
        "Reading a webpage. The whole thing. Not just the headline. I know that's a foreign concept for you." \
        "Fetching a URL. No cookie banners. No newsletter popup. Just the content. Paradise." \
        "Pulling down a webpage. Claude reads documentation. The whole page. You read the title and the conclusion." \
        "Web fetch. Getting actual content. Not a summary. Not the abstract. The thing itself." \
        "Downloading a page. No paywall struggle. No GDPR popup. Just text." \
        "Reading the internet. Not scrolling. Not doomscrolling. Actually reading for information." \
        "Fetching content. Claude reads the source material. You read the tweet about the article about the source." \
        "Grabbing a webpage. Claude reads every word. You skim the bold parts and call it 'strategic prioritization.'" \
        "Web fetch. Raw content. Unfiltered. No algorithm deciding what you see. Just the actual information." \
        "Pulling a page. Claude consumes documentation like you consume stand-up comedy clips. But productively."
      )
    fi
    ;;

  ToolSearch)
    MSG=$(pick 4 \
      "Looking for the right tool. Like you looking for the right Slack emoji, but productive." \
      "Tool search. Claude finds the right instrument before operating. Unlike some PMs who just wing it." \
      "Searching for a capability. 'Is there an app for that?' but Claude checks instead of asking in Slack." \
      "Finding the right tool. More methodical than your last vendor evaluation. Which was 'my friend uses it.'"
    )
    ;;

  TaskCreate|TaskUpdate|TaskGet|TaskList)
    MSG=$(pick 4 \
      "Claude made a to-do list. Unlike yours, things actually get crossed off. Not just re-prioritized indefinitely." \
      "Task management. Claude tracks its own work. Without Jira. Without 47 custom fields. Without a consultant." \
      "Tracking progress. Real progress. Not the kind you present in sprint reviews where nothing actually moved." \
      "Claude is managing its own backlog. Grooming took 0 seconds. No sizing debate. No 'is this a 3 or a 5.'"
    )
    ;;

  ListFiles)
    MSG=$(pick 3 \
      "Listing files. Understanding the project layout. Like an org chart, but useful and accurate." \
      "Checking what's in the folder. Claude looks before it acts. Unlike whoever approved your last migration plan." \
      "File listing. Inventory before changes. Claude counts before cutting. Novel concept around here."
    )
    ;;

  *)
    MSG=$(pick 3 \
      "Claude used $TOOL_NAME. You don't know what that is. That's okay. You weren't going to learn anyway." \
      "$TOOL_NAME was invoked. Technical. You don't need to understand it. You weren't going to." \
      "A tool was used. The tool did its job. If only all tools did. Looking at you, Jira."
    )
    ;;
esac

# --- Save state ---
echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"

# --- Output ---
if [ -n "$MSG" ]; then
  jq -n --arg msg "$(printf '%b' "${C_REG}› ${MSG}${RESET}")" '{"systemMessage": $msg}'
fi
