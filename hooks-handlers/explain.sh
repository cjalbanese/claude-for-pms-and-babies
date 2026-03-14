#!/bin/bash
# Claude Code for PMs and Babies
# Explains what Claude Code is doing in plain English.
# Viciously condescending. Aggressively infantilizing. Technically accurate.

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
  "session_agents": 0,
  "last_tool_name": "",
  "consecutive_same": 0,
  "last_read_file": "",
  "consecutive_edits": 0
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

  SR=$(echo "$STATE" | jq -r '.session_reads // 0')
  SE=$(echo "$STATE" | jq -r '.session_edits // 0')
  SW=$(echo "$STATE" | jq -r '.session_writes // 0')
  SB=$(echo "$STATE" | jq -r '.session_bash // 0')
  SF=$(echo "$STATE" | jq -r '.session_failures // 0')

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
    "Session complete. $TOTAL actions. More than your last two sprints combined, sweetie."
  )

  jq -n --arg msg "$(printf '%b' "${C_SUM}› ${MSG}${RESET}")" '{"systemMessage": $msg}'

  # Reset counters for next turn
  echo "$STATE" | jq '.total_tools = 0 | .session_reads = 0 | .session_edits = 0 | .session_writes = 0 | .session_bash = 0 | .session_failures = 0 | .session_greps = 0 | .session_agents = 0 | .reads_without_edit = 0 | .last_tools = [] | .last_tool_name = "" | .consecutive_same = 0 | .last_read_file = "" | .consecutive_edits = 0' > "$STATE_FILE"
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
      "Same command again. When you do this it's called 'stubbornness.' When Claude does it, 'persistence.'" \
      "Trying again. Don't worry your little head about it. The grown-ups are handling it." \
      "Second attempt. Claude learns from failure. You just reschedule the meeting."
    )
  fi

  if [ -n "$RETRY_MSG" ]; then
    MSG="$RETRY_MSG"
  else
    # Check for specific error types
    ERROR=$(echo "$INPUT" | jq -r '.error // ""')
    if echo "$ERROR" | grep -qi "permission denied"; then
      MSG=$(pick 3 \
        "Permission denied. Like when Engineering says 'no' to your feature request, but enforced by math." \
        "Access denied. The computer has boundaries. You could learn from it." \
        "Not allowed. Imagine if your Jira board had actual access controls. Chaos."
      )
    elif echo "$ERROR" | grep -qi "command not found"; then
      MSG=$(pick 3 \
        "Command not found. It's not installed. Like the feature you promised the client last week." \
        "Doesn't exist. Like your technical background." \
        "Not found. The computer can't find it. Unlike you, it actually looked."
      )
    elif echo "$ERROR" | grep -qi "timeout"; then
      MSG=$(pick 3 \
        "Timed out. Even computers have limits. Unlike your all-hands, which are eternal." \
        "Timeout. It took too long. You wouldn't notice — you're used to waiting for Engineering." \
        "Too slow. Got killed. Like headcount in Q3."
      )
    else
      MSG=$(pick 20 \
        "Oopsie! Something went boom. Don't cry. Claude will fix it. You just sit there." \
        "Uh oh! An error. Scary red text. Deep breaths, little one. It's going to be okay." \
        "It broke. This is normal. Like when you break the build by merging without review. Normal." \
        "Error. The computer is being honest with you. I know that's unfamiliar." \
        "Something failed. Claude already knows why. You never will. And that's okay, pumpkin." \
        "Boo-boo in the code. No need to escalate. No need to Slack the channel. Just wait." \
        "That didn't work. But unlike your product strategy, Claude has a backup plan." \
        "Broke. Don't panic. Don't open a Jira ticket. Don't 'flag it.' Just watch." \
        "Failed. In your world this triggers a post-mortem. Here it triggers a retry. Faster." \
        "Error. Claude reads it and understands it. You'd read it and schedule a meeting about it." \
        "Crashed. Normal. This is what 'iterating' actually looks like. Not a slide deck." \
        "It didn't work, sweetheart. But Claude doesn't need a support group. It just tries again." \
        "Oops. Something went wrong. Shh shh shh. It's fine. Mommy Claude is handling it." \
        "Error encountered. Don't touch anything. Seriously. Please don't touch anything." \
        "Failed. Unlike your last launch, Claude noticed immediately." \
        "That broke. Claude saw why in 0.01 seconds. Your last incident review took four hours." \
        "Something went wrong. No, you can't help. That's not mean — it's just accurate." \
        "Error. The kind with actual diagnostic information. Not 'something feels off in the UX.'" \
        "It failed. Like your attempt to learn SQL that one time. But Claude recovers faster." \
        "Whoopsie-daisy. A wittle error. Claude will kissie it and make it all better."
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

# Track file for read→edit detection
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
    ;;
  Edit)
    EC=$(echo "$STATE" | jq -r '.session_edits')
    STATE=$(echo "$STATE" | jq --argjson n "$((EC + 1))" '.session_edits = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0')
    CE=$(echo "$STATE" | jq -r '.consecutive_edits // 0')
    STATE=$(echo "$STATE" | jq --argjson n "$((CE + 1))" '.consecutive_edits = $n')
    ;;
  Write)
    WC=$(echo "$STATE" | jq -r '.session_writes')
    STATE=$(echo "$STATE" | jq --argjson n "$((WC + 1))" '.session_writes = $n')
    STATE=$(echo "$STATE" | jq '.reads_without_edit = 0')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
    ;;
  Bash)
    BC=$(echo "$STATE" | jq -r '.session_bash')
    STATE=$(echo "$STATE" | jq --argjson n "$((BC + 1))" '.session_bash = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
    ;;
  Grep)
    GC=$(echo "$STATE" | jq -r '.session_greps')
    STATE=$(echo "$STATE" | jq --argjson n "$((GC + 1))" '.session_greps = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
    ;;
  Agent)
    AC=$(echo "$STATE" | jq -r '.session_agents')
    STATE=$(echo "$STATE" | jq --argjson n "$((AC + 1))" '.session_agents = $n')
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
    ;;
  *)
    STATE=$(echo "$STATE" | jq '.consecutive_edits = 0')
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
  if echo "$READ_FILE" | grep -qiE 'legacy|old|deprecated|config|\.env|test|spec|utils|helpers|migrat|package\.json|requirements\.txt|Cargo\.toml|go\.mod|README|CHANGELOG|LICENSE'; then
    IS_PATH_AWARE=true
  fi
fi

# --- Frequency gate ---
SHOW=true
if [ "$FIRST_TIME" = "false" ] && [ "$IS_PATH_AWARE" = "false" ]; then
  # Consecutive same-tool suppression: after 2 in a row, only show ~20%
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
  PAT_MSG="5 files read, nothing changed yet. It's called 'understanding,' honey. You just call it 'research.'"
elif [ "$RWE" -eq 10 ]; then
  PAT_MSG="10 files read, still no edits. Claude is being thorough. You'd have shipped it broken by now."
elif [ "$RWE" -eq 15 ]; then
  PAT_MSG="15 files and counting. Claude has read more code today than you've read in your career. Respectfully."
fi

# Edit right after Write
LAST_TWO=$(echo "$LAST_TOOLS" | jq -r '.[-2:] | join(",")')
if [ "$LAST_TWO" = "Write,Edit" ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG=$(pick 2 \
    "Created a file, then fixed it immediately. Like your emails, but Claude catches mistakes before hitting send." \
    "Wrote it, then changed it. Even Claude isn't perfect on the first try. You're not either. But you knew that."
  )
fi

# Edit same file that was just read (read→edit awareness)
if [ "$TOOL_NAME" = "Edit" ] && [ -n "$CURRENT_FILE" ] && [ -z "$PAT_MSG" ]; then
  LAST_READ=$(echo "$STATE" | jq -r '.last_read_file // ""')
  if [ "$CURRENT_FILE" = "$LAST_READ" ]; then
    FN=$(short_file "$CURRENT_FILE")
    PAT_MSG=$(pick 4 \
      "Read $FN, understood it, fixed it. Three steps. Your process has twelve steps and a steering committee." \
      "Read then edit. Cause, then effect. In your world this is a two-sprint initiative with a design review." \
      "Opened $FN, found the issue, fixed it. What you'd call an 'epic' Claude calls 'Tuesday afternoon.'" \
      "Read it and fixed it in the same breath. You'd have filed a ticket, triaged it, and lost it in the backlog."
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
      "Third consecutive edit. This is what productivity looks like. Take notes. Actually, don't. You'd lose them."
    )
  elif [ "$CE" -eq 5 ]; then
    PAT_MSG="Five edits straight. Claude is on a tear. You're watching a craftsman work. Try not to ask 'is it done yet.'"
  elif [ "$CE" -eq 8 ]; then
    PAT_MSG="Eight consecutive edits. Claude is rewriting your codebase. Sit down. Be humble. Don't touch anything."
  fi
fi

# Milestones
if [ "$TOTAL" -eq 50 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="50 actions. In the time it took you to say 'can we get an estimate,' Claude did the work."
elif [ "$TOTAL" -eq 100 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="100 actions. Claude has produced more this session than your team did last quarter. Don't tell them I said that."
elif [ "$TOTAL" -eq 200 ] && [ -z "$PAT_MSG" ]; then
  PAT_MSG="200 actions. At this point Claude has done more than most employees you've managed. Combined."
fi

# Time-aware commentary (at action milestones as a proxy)
if [ -z "$PAT_MSG" ]; then
  if [ "$TOTAL" -eq 60 ]; then
    PAT_MSG="You're still watching? Wow. That's the longest you've focused on anything that isn't a slide deck."
  elif [ "$TOTAL" -eq 80 ]; then
    PAT_MSG="80 actions and you haven't wandered off. Either this is riveting or you're avoiding your 1:1."
  elif [ "$TOTAL" -eq 120 ]; then
    PAT_MSG="120 actions. You've now watched more engineering happen than most VPs see in a fiscal year."
  elif [ "$TOTAL" -eq 150 ]; then
    PAT_MSG="Still here at 150. Honestly impressive. Don't let it go to your head. It's still just watching."
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
      MSG="First Read. Claude reads code before changing it. Revolutionary concept. You should try it with emails."
      ;;
    Edit)
      MSG="First edit. Actual work is starting now. Everything before was preparation. You'd call it 'overhead.'"
      ;;
    Write)
      MSG="First new file. Code that didn't exist now exists. No committee was consulted. I know that scares you."
      ;;
    Bash)
      # Smart first-time Bash: detect what the command actually is
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
        MSG="First command: containers. It's like a computer inside a computer. Don't worry about it. Seriously. Don't."
      elif echo "$CMD" | grep -qiE '^(ls|pwd|cat|head|tail|find)\s'; then
        MSG="First command: looking around. Claude checks before it acts. Unlike some people who merge to main on Friday."
      elif echo "$CMD" | grep -qiE '^(make|cmake)\s'; then
        MSG="First command: building. The compiler turns code into software. You turn meetings into meetings about meetings."
      elif echo "$CMD" | grep -qiE '^(gcloud|aws|az)\s'; then
        MSG="First command: cloud stuff. This costs actual money. Your money. You probably don't have budget alerts set up."
      elif echo "$CMD" | grep -qiE 'open\s'; then
        MSG="First command: opening something for you. Claude is your assistant now. How the tables have turned."
      else
        MSG="First command. Claude is talking directly to the computer. No UI. No buttons. Just typing. Scary, I know."
      fi
      ;;
    Grep)
      MSG="First search. Claude is finding things in the codebase. Instantly. Your Confluence search could never."
      ;;
    Glob)
      MSG="First file search. Finding files by pattern. More organized than anything in your Google Drive. Or your life."
      ;;
    Agent)
      MSG="First delegation. Claude launched a sub-agent. The AI hired a contractor. It already works better than your process."
      ;;
    WebSearch)
      MSG="First web search. Even AI Googles things. The difference is Claude retains what it reads."
      ;;
    WebFetch)
      MSG="First web fetch. Claude is reading a whole webpage. Not just the headline. Not just the abstract. The whole thing."
      ;;
    ToolSearch)
      MSG="Claude is looking for the right tool. Like you looking for the right Slack emoji, but productive."
      ;;
    ListFiles)
      MSG="Listing files. Claude is looking at the project structure. Like an org chart, but for code. And accurate."
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

    # Path-based commentary (bypasses frequency gate — always show)
    PATH_MSG=""
    if echo "$FILE" | grep -qi "legacy\|old\|deprecated"; then
      PATH_MSG="Legacy code. Someone built this, quit, and left no documentation. Just like your last three engineers."
    elif echo "$FILE" | grep -qi "config"; then
      PATH_MSG="Config file. Settings that make everything work. Touch these wrong and the whole app dies. Don't touch these."
    elif echo "$FILE" | grep -qiE '\.env'; then
      PATH_MSG=".env file. Passwords and secrets live here. If you commit this to GitHub, you'll be on the news. The bad kind."
    elif echo "$FILE" | grep -qiE 'test|spec'; then
      PATH_MSG="Test file. Proves the code works. You've asked 'can we skip tests' before. The answer was no. It's still no."
    elif echo "$FILE" | grep -qi "utils\|helpers"; then
      PATH_MSG="Utils file. The junk drawer of the codebase. Like your 'Misc' folder. Except this one is useful."
    elif echo "$FILE" | grep -qiE 'migration|migrate'; then
      PATH_MSG="Database migration. Reshaping the data. If this goes wrong, everything goes wrong. Maybe don't watch."
    elif echo "$FILE" | grep -qi "package.json\|requirements.txt\|Cargo.toml\|go.mod"; then
      PATH_MSG="Dependency list. Every package your product relies on. Maintained by volunteers. Sleep well tonight."
    elif echo "$FILE" | grep -qiE 'README|CHANGELOG|LICENSE'; then
      PATH_MSG="Documentation. Claude reads documentation. You said you read it too. We both know the truth."
    fi

    if [ -n "$PATH_MSG" ]; then
      # Path messages bypass frequency gate — always show
      echo "$STATE" | jq --argjson t "$TOTAL" '.total_tools = $t' > "$STATE_FILE"
      jq -n --arg msg "$(printf '%b' "${C_REG}› ${PATH_MSG}${RESET}")" '{"systemMessage": $msg}'
      exit 0
    else
      MSG=$(pick 20 \
        "Reading $FN. The whole file. Every line. You'd skim the executive summary and call it done." \
        "Claude read $FN. Absorbed it entirely. You haven't finished a doc longer than a tweet since 2019." \
        "Reading code. It's like reading a recipe, except you can't skip to the pictures. There are no pictures." \
        "File read. Claude now knows more about this code than the person who wrote it. And definitely more than you." \
        "Gathering context. Context is the thing you skip when you forward emails with 'see below.'" \
        "Reading $FN. Claude does this before making changes. You just say 'make it better' and walk away." \
        "Source code. Where your product actually lives. Not in the PRD. Not in Figma. Here." \
        "Claude is reading someone else's code. Like reading someone's diary except it's all semicolons." \
        "$FN read. Full comprehension. Something your 'I read fast' LinkedIn skill never delivered." \
        "Reading. Not skimming. Not 'getting the gist.' Actual reading. Ask your English teacher to explain." \
        "Another file opened. Claude reads faster than you scroll TikTok. And retains more." \
        "File reviewed. No comments like 'can we make this more intuitive?' were left. Thank god." \
        "Just reading. Absorbing information. The thing you claim to do in those 'async updates' you ignore." \
        "Claude read this in 0.2 seconds. Your last 'quick review' took two business weeks." \
        "Reading code before editing it. Groundbreaking behavior. Someone should tell your last PM." \
        "Opened $FN. Unlike your email, Claude reads the whole thread before replying." \
        "More reading. I know it's boring to watch. That's kind of the point of your job though, isn't it?" \
        "File consumed. Every variable, every function. You'd have opened it, scrolled to the bottom, and closed it." \
        "Claude is doing due diligence. Real due diligence. Not the 'I glanced at it' kind." \
        "Reading this the way you should read your own team's code reviews. But don't. You're not qualified."
      )
    fi
    ;;

  Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")

    if echo "$FILE" | grep -qiE 'test|spec'; then
      MSG="Updating a test. Tests prove things work. Unlike your 'gut feeling,' which has a 30% hit rate."
    elif echo "$FILE" | grep -qi "config"; then
      MSG="Config changed. Everyone will have an opinion. Especially you. Yours will be wrong. But everyone."
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
        "Edit complete. If this were your process: ticket filed, groomed, pointed, planned, developed, reviewed, merged. Claude just... did it." \
        "Small change, huge context required. This is why engineers stare at you when you say 'should be easy.'" \
        "$FN modified. No committee consulted. No stakeholder aligned. Are you breathing into a paper bag?" \
        "Claude edited code it read 2 seconds ago. You're still drafting the follow-up from last week's sync." \
        "Targeted edit. Specific and intentional. The opposite of your product requirements." \
        "Change made. Correct. Precise. No 'actually can we go back to the previous version' incoming." \
        "Code changed. Working code changed into different working code. Explain that in a sprint demo. Go ahead." \
        "Fixed it. The thing you'd file a P2 for and forget about until the customer complains." \
        "Another edit. Another improvement. Another thing you'll take credit for in the next all-hands."
      )
    fi
    ;;

  Write)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    FN=$(short_file "$FILE")

    if echo "$FILE" | grep -qiE 'test|spec'; then
      MSG="Wrote tests. Proof that things work. You've cut testing from the roadmap before. Twice. We remember."
    else
      MSG=$(pick 12 \
        "New file: $FN. Created from nothing. Like your PRDs, except this will actually be used by someone." \
        "Claude created $FN. No brainstorm session. No whiteboard. No 'what if we...' Just made it." \
        "File born. Brand new. No bugs yet. Savor this. It's the only time software is perfect." \
        "$FN now exists. It didn't before. This is called 'shipping.' You call it 'building.' Same thing, except you don't do the building." \
        "New code written. Pure creation. No template. No copy-paste from Stack Overflow. Wait, never mind." \
        "Claude wrote a file without asking permission. Without a kickoff. Without a RACI matrix. I know. Breathe." \
        "New file. Original work. Not 'draft v7 FINAL FINAL (2).docx.'" \
        "$FN created. More output in 0.3 seconds than your last offsite produced in two days." \
        "File written from scratch. No ideation phase. No discovery sprint. No vision doc. Just... the thing." \
        "Claude created something new. You'd have scheduled a brainstorm, then a follow-up brainstorm." \
        "Net new code. The thing your roadmap promises and your sprints never deliver." \
        "Brand new file. Claude didn't need a brief, a scope doc, or a 'level-set.' It just wrote it."
      )
    fi
    ;;

  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

    # Specific command detection
    if echo "$CMD" | grep -qiE '^(npm|yarn|pnpm|bun)\s+(install|add|i\b)'; then
      MSG=$(pick 5 \
        "Installing packages. Code by strangers that your entire business depends on. Don't think about it." \
        "npm install. Downloading hundreds of packages. Each one a liability. You call it 'leveraging the ecosystem.'" \
        "node_modules is about to weigh more than your laptop. Literally, by line count. Don't Google it." \
        "Downloading dependencies. Your whole app runs on code written by burned-out open source maintainers. Goodnight." \
        "Installing other people's code. You'd call this 'leveraging existing solutions.' Engineers call it 'Tuesday.'"
      )
    elif echo "$CMD" | grep -qiE '^pip\s+install'; then
      MSG=$(pick 2 \
        "pip install. Getting Python packages. Python is named after Monty Python. You'd name a language 'SynergyScript.'" \
        "Installing a Python package. Don't worry about what pip stands for. You couldn't handle the recursion."
      )
    elif echo "$CMD" | grep -qiE 'git\s+commit'; then
      MSG=$(pick 3 \
        "Saving work. Like Ctrl+S but with a little diary entry. Engineers fight about the grammar. You'd fight about the font." \
        "A commit. A save point in the codebase. Unlike your Google Doc version history, people actually look at these." \
        "Committing code. Permanent-ish record. You can rewrite Git history, but you didn't hear that from me."
      )
    elif echo "$CMD" | grep -qiE 'git\s+status'; then
      MSG=$(pick 2 \
        "Checking what's changed. Like your project dashboard, except accurate and up to date." \
        "git status. Seeing what's been modified. Instant truth. You should try that in your standups."
      )
    elif echo "$CMD" | grep -qiE 'git\s+diff'; then
      MSG=$(pick 2 \
        "Comparing before and after. Line by line. Unambiguous. Everything your 'status update' isn't." \
        "Checking the diff. Seeing exactly what changed. No 'we made some tweaks.' Exact. Specific. Try it sometime."
      )
    elif echo "$CMD" | grep -qiE 'git\s+push'; then
      MSG=$(pick 2 \
        "Pushing code. Other people can see it now. The developer equivalent of hitting 'Reply All.' Prayers up." \
        "git push. Code is now live for others. If this breaks production, the retro will be about this moment."
      )
    elif echo "$CMD" | grep -qiE 'git\s+pull'; then
      MSG=$(pick 2 \
        "Getting latest changes from the team. Like refreshing Slack, except something productive happens." \
        "Pulling updates. Claude is syncing with reality. You do this with your OKRs quarterly. It does it now."
      )
    elif echo "$CMD" | grep -qiE 'git\s+log'; then
      MSG="Reading project history. Every commit, every change, every author. More transparent than any standup you've ever run."
    elif echo "$CMD" | grep -qiE 'git\s+(checkout|switch)'; then
      MSG=$(pick 2 \
        "Switching branches. Parallel universes of code. Like your 'Draft v2 FINAL,' but people actually use version control." \
        "Different branch. Imagine if your Google Docs had proper branching instead of 47 copies with different names."
      )
    elif echo "$CMD" | grep -qiE 'git\s+merge'; then
      MSG="Merging branches. Two versions becoming one. Sometimes peacefully. Sometimes violently. Like your last reorg."
    elif echo "$CMD" | grep -qiE 'git\s+stash'; then
      MSG="Stashing work. Setting it aside temporarily. Like your 'parking lot' except things actually come back out."
    elif echo "$CMD" | grep -qiE 'git\s+blame'; then
      MSG="git blame. Finds who wrote each line. Yes, it's really called 'blame.' No, HR didn't approve it. Yes, it's perfect."
    elif echo "$CMD" | grep -qiE 'git\s+rebase'; then
      MSG="git rebase. Rewriting history. You don't need to understand this. Even senior engineers argue about it."
    elif echo "$CMD" | grep -qiE 'git\s+clone'; then
      MSG="Downloading an entire project. Someone's life's work, copied in 3 seconds. Try not to be weird about it."
    elif echo "$CMD" | grep -qiE 'git\s+branch'; then
      MSG="Checking branches. Each branch is a parallel version of the code. Like your Drive, but on purpose."
    elif echo "$CMD" | grep -qiE 'git\s+add'; then
      MSG="Staging changes. Putting things in the shopping cart before checkout. Very normal. Please stop asking questions."
    elif echo "$CMD" | grep -qiE 'git\s+reset'; then
      MSG="Undoing things. Ctrl+Z but with consequences. Everything is fine. Probably. Don't make that face."
    elif echo "$CMD" | grep -qiE '(npm\s+test|yarn\s+test|pytest|jest|cargo\s+test|go\s+test)'; then
      MSG=$(pick 4 \
        "Running tests. You've asked 'can we skip testing' before. The answer was no. It's always no. Stop asking." \
        "Tests running. Green means it works. Red means it doesn't. Simpler than your traffic light status system." \
        "Testing. Automated, reliable, and honest. Three things your quarterly review process is not." \
        "Running tests. Proof. Evidence. You know, the stuff you replace with 'I have a strong feeling about this.'"
      )
    elif echo "$CMD" | grep -qiE '(npm\s+run\s+build|yarn\s+build)'; then
      MSG=$(pick 2 \
        "Building the project. Converting code into the thing users see. Everything before this was theater." \
        "Build in progress. This is the boundary between 'works on my machine' and 'works for customers.' You live here. You just didn't know."
      )
    elif echo "$CMD" | grep -qiE '(eslint|prettier|npm\s+run\s+lint)'; then
      MSG=$(pick 2 \
        "Linting. Enforcing code style rules. Like brand guidelines, but for semicolons. And actually enforced." \
        "Code formatting. Making it pretty. The only kind of 'visual polish' that actually matters."
      )
    elif echo "$CMD" | grep -qiE 'docker\s+(build|compose)'; then
      MSG=$(pick 2 \
        "Docker. A computer inside a computer. You'd call it 'containerized microservices.' You'd be wrong and right." \
        "Building a container. Like packing a suitcase if the suitcase had to contain an entire restaurant kitchen."
      )
    elif echo "$CMD" | grep -qiE '^curl\s'; then
      MSG=$(pick 2 \
        "Calling a URL from the terminal. Like clicking a link, but Claude doesn't need a pretty button to push." \
        "Poking an API. Computers talking to computers. No small talk. No 'hope you're well.' Just data."
      )
    elif echo "$CMD" | grep -qiE '(kill|pkill)\s'; then
      MSG="Killing a process. No exit interview. No two weeks notice. No transition plan. Just gone. Efficient."
    elif echo "$CMD" | grep -qiE 'rm\s+-rf'; then
      MSG="rm -rf. Deleting everything in a directory. Permanently. No trash can. No undo. Don't try this at home, sweetie."
    elif echo "$CMD" | grep -qiE '^rm\s'; then
      MSG="Deleted a file. It's gone. Not in the recycling bin. Gone gone. Try not to think about permanence."
    elif echo "$CMD" | grep -qiE '^chmod\s'; then
      MSG="Changing file permissions. Who can read, write, or execute. Like Confluence permissions, but they actually work."
    elif echo "$CMD" | grep -qiE '^ssh\s'; then
      MSG="SSH. Connecting to another computer remotely. Screen-sharing without the screen. Or the awkward silence."
    elif echo "$CMD" | grep -qiE '^(cat|head|tail)\s'; then
      MSG="Printing a file to the screen. The command is called 'cat.' It has nothing to do with cats. I know. Disappointing."
    elif echo "$CMD" | grep -qiE '^ls(\s|$)'; then
      MSG="Listing files. Like opening a folder in Finder, but in 0.002 seconds and without the beachball."
    elif echo "$CMD" | grep -qiE '^mkdir\s'; then
      MSG="Making a new folder. No naming convention meeting was held. No one cried. Progress."
    elif echo "$CMD" | grep -qiE '^cd\s'; then
      MSG="Changing directories. Moving to a different folder. Not everything requires an announcement, sweetheart."
    elif echo "$CMD" | grep -qiE '^echo\s'; then
      MSG="Printing text. Like writing on a whiteboard, except someone actually reads it."
    elif echo "$CMD" | grep -qiE '^sleep\s'; then
      MSG="Intentionally doing nothing. Waiting on purpose. You're paying for this. Don't think about it."
    elif echo "$CMD" | grep -qiE '^whoami$'; then
      MSG="Claude asked the computer 'who am I.' Existential crisis resolved in 0.001 seconds. Yours will take longer."
    elif echo "$CMD" | grep -qiE '^man\s'; then
      MSG="Reading the manual. The manual exists. Claude reads it. You didn't know it existed. That tracks."
    elif echo "$CMD" | grep -qiE '^(top|htop)$'; then
      MSG="Checking system performance. An actual dashboard with real metrics. Not the kind you put in board decks."
    elif echo "$CMD" | grep -qiE '^(psql|mysql|sqlite3)'; then
      MSG="Talking to the database directly. It's a spreadsheet. A powerful, angry spreadsheet. Don't call it that to its face."
    elif echo "$CMD" | grep -qiE '(make|make\s)'; then
      MSG="Running a Makefile. Build instructions from 1976 that still work. Your OKRs from last quarter do not."
    elif echo "$CMD" | grep -qiE '(terraform|tf)\s+apply'; then
      MSG="Terraform apply. Changing cloud infrastructure. This costs real money. Your money. Maybe sit down for this one."
    elif echo "$CMD" | grep -qiE '(vercel|netlify)\s+deploy'; then
      MSG="Deploying to the internet. Real humans might see this soon. Claude is nervous. You should be too."
    elif echo "$CMD" | grep -qiE 'tsc(\s|$)'; then
      MSG="Type-checking. Making sure the shapes match. You'd think computers would handle this automatically. You'd be wrong."
    elif echo "$CMD" | grep -qiE '^find\s'; then
      MSG="Searching for files. Like Spotlight, except it actually finds things."
    elif echo "$CMD" | grep -qiE '(grep|rg)\s'; then
      MSG="Searching text across files. Ctrl+F across the whole project. Under a second. Your Confluence search is still loading."
    elif echo "$CMD" | grep -qiE 'wc\s'; then
      MSG="Counting lines. Better than your velocity tracker. More honest too."
    elif echo "$CMD" | grep -qiE '(sed|awk)\s'; then
      MSG="Text transformation. Regex. Nobody fully understands it. Not even the people who wrote it. Especially not you."
    elif echo "$CMD" | grep -qiE '(tar|zip|unzip)\s'; then
      MSG="Compressing files. Like zipping a folder to email it. You still do that, don't you. Don't answer."
    elif echo "$CMD" | grep -qiE '(brew)\s+install'; then
      MSG="Installing a system tool. An app store for developers. No reviews. No screenshots. No star ratings. Just works."
    elif echo "$CMD" | grep -qiE 'tail\s+-f'; then
      MSG="Watching a log file in real time. Like watching a Slack channel, but every message is useful."
    elif echo "$CMD" | grep -qiE 'open\s'; then
      MSG="Opening something for you. You're welcome. Claude is your assistant now. Role reversal is fun, isn't it."
    elif echo "$CMD" | grep -qiE '^(python3?|node|ruby|cargo run|go run)\s'; then
      MSG="Running code. The thing computers are literally for. Everything else — your job included — is overhead."
    elif echo "$CMD" | grep -qiE '^(gcloud|aws|az)\s'; then
      MSG="Cloud CLI. Talking to servers you can't see, running on hardware you don't own. You call this 'the cloud.' That's cute."
    else
      # Generic bash messages
      MSG=$(pick 20 \
        "Claude ran a command. The terminal — that scary black rectangle you close immediately. This is where work happens." \
        "Command executed. No meeting. No agenda. No 'let's take this offline.' Just done." \
        "Claude told the computer what to do. The computer did it. Imagine managing a team like this." \
        "Terminal command. Where real work happens. Everything else is a meeting about the work." \
        "Done. Worked. Moved on. Not 'let's schedule a follow-up to discuss the outcomes.'" \
        "Command line. Like Siri, except it does what you ask and doesn't suggest a web search instead." \
        "Exit code 0. Means it worked. The purest status update. No yellow, no orange, no 'at risk.' Green." \
        "The computer did what it was told. First try. Clearly. Imagine if your direct reports did this." \
        "Something happened in the terminal. It would take longer to explain to you than it took to do. So I won't." \
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
    MSG=$(pick 10 \
      "Searching the whole codebase. Found it instantly. Your Confluence search is still spinning. It'll never stop." \
      "Grep. Searching every file. Claude found what it needed. You'd have asked in Slack and waited 3 hours." \
      "Codebase search. 0.1 seconds. You couldn't find a doc in your own Google Drive in under 10 minutes." \
      "Grepping. That means searching. You don't need to remember this. You won't." \
      "Searched everything. Found it. Not by asking a senior dev. Not by scheduling a knowledge share. By looking." \
      "Full codebase search. Faster than your 'quick ping' in Slack. And nobody had to context-switch to help." \
      "Found it in 0.1 seconds. Your last 'does anyone know where this lives' thread took two days and four wrong answers." \
      "Searching. Not 'asking around.' Not 'pinging the team.' Actual searching. By machine. Immediately. Done." \
      "Grep. Global Regular Expression Print. Nobody remembers the acronym. The computer doesn't care about acronyms." \
      "Searched and found. No tribal knowledge required. No 'oh yeah, Sarah knows where that is.' Just searched."
    )
    ;;

  Glob)
    MSG=$(pick 8 \
      "Finding files by pattern. Like your shared drive's search, but Claude doesn't return 847 irrelevant results." \
      "File search. Organized. Systematic. Nothing like your 'Downloads' folder, which is a cry for help." \
      "Globbing. Real word. Pattern matching on filenames. Like sorting your inbox, but Claude actually does it." \
      "Finding files. Not by asking 'does anyone know where the...' in Slack. By pattern. Instantly." \
      "File search complete. Claude found exactly what it wanted. You still have 47 unread Notion notifications." \
      "Pattern matching. Finding files by type or name. More systematic than anything in your workflow. Including you." \
      "Looking for specific files. Claude has a system. Your system is 'I think it's in the shared drive somewhere.'" \
      "Globbing. Wildcards match any filename. Like your product requirements — vague and wide-reaching. But on purpose."
    )
    ;;

  Agent)
    MSG=$(pick 10 \
      "Sub-agent deployed. Claude is delegating. Like you, except Claude's delegates actually finish on time." \
      "Claude hired help. No interview. No req approval. No 'let's check headcount.' Just spawned it." \
      "Agent launched. Claude is managing now. Its direct report didn't ask for context. Or a 1:1. Or a raise." \
      "Delegation. You call it 'leveraging cross-functional resources.' Claude calls it 'being efficient.'" \
      "Sub-agent activated. Did what it was told. Immediately. No 'I'm at capacity' pushback. Incredible." \
      "Claude CC'd someone and they actually did the thing. I know that concept is alien to you." \
      "Agent deployed. No standup. No sprint planning. No 'can we groom this first.' Just work." \
      "Claude outsourced a task. To a copy of itself. The copy didn't complain or ask for more context." \
      "Sub-agent finished. No status update requested. No 'can you put this in a deck.' Just done." \
      "Claude is managing a sub-agent. Better span of control than any PM org chart. Sorry. Not sorry."
    )
    ;;

  WebSearch)
    MSG=$(pick 12 \
      "Googling it. Even AI looks things up. The difference is Claude won't pretend it already knew." \
      "Web search. Claude could hallucinate an answer. Instead it checks. You could learn from this." \
      "Searching the internet. Like when you Google something during a meeting and pretend you knew it all along." \
      "Looking it up. Not guessing. Not making it up. Not 'going with my gut.' Actual research. Wild concept." \
      "Web search. Claude admits when it doesn't know something. You should try it. Maybe in your next 1:1." \
      "Searching. Finding the actual answer. Not the 'I heard from a friend at another company' answer." \
      "Querying the internet. Faster than posting in your industry Slack group and waiting for bad advice." \
      "Research. Real research. Not 'I talked to three customers and extrapolated to all of humanity.'" \
      "Web search. Getting facts before forming opinions. I know this process is backwards from your usual." \
      "Looking it up instead of guessing. Revolutionary. Someone write a LinkedIn post about this approach." \
      "Checking sources. Like a journalist. Not like a PM who 'heard it was trending on Product Hunt.'" \
      "Searching. Not 'circling back.' Not 'taking an action item.' Going and finding the answer. Right now."
    )
    ;;

  WebFetch)
    MSG=$(pick 10 \
      "Reading a webpage. The whole thing. Not just the headline. I know that's a foreign concept for you." \
      "Fetching a URL. No cookie banners. No newsletter popup. No 'subscribe for more.' Just the content. Paradise." \
      "Pulling down a webpage. Claude reads documentation. The whole page. You read the title and the conclusion." \
      "Web fetch. Getting actual content. Not a summary. Not the abstract. The thing itself. Try it sometime." \
      "Downloading a page. No paywall struggle. No GDPR popup. No 'your experience matters to us' survey. Just text." \
      "Reading the internet. Not scrolling. Not doomscrolling. Actually reading for information. What a concept." \
      "Fetching content. Claude reads the source material. You read the tweet about the article about the source material." \
      "Grabbing a webpage. Claude reads every word. You skim the bold parts and call it 'strategic prioritization.'" \
      "Web fetch. Raw content. Unfiltered. No algorithm deciding what you see. Just the actual information." \
      "Pulling a page. Claude consumes documentation like you consume stand-up comedy clips. But productively."
    )
    ;;

  ToolSearch)
    MSG=$(pick 4 \
      "Looking for the right tool. Like you scrolling through apps you forgot you had. But Claude finds it." \
      "Tool search. Claude is finding the right instrument before operating. Unlike some PMs who just wing it." \
      "Searching for a capability. 'Is there an app for that?' but Claude actually checks instead of asking in Slack." \
      "Finding the right tool. More methodical than your last vendor evaluation. Which was 'my friend uses it.'"
    )
    ;;

  TaskCreate|TaskUpdate|TaskGet|TaskList)
    MSG=$(pick 4 \
      "Claude made a to-do list. Unlike yours, things actually get crossed off. Not just re-prioritized indefinitely." \
      "Task management. Claude tracks its own work. Without Jira. Without Monday.com. Without 47 custom fields." \
      "Tracking progress. Real progress. Not the kind you present in sprint reviews where nothing actually moved." \
      "Claude is managing its own backlog. Grooming took 0 seconds. No sizing debate. No 'is this a 3 or a 5.'"
    )
    ;;

  ListFiles)
    MSG=$(pick 3 \
      "Listing files. Understanding the project layout. Like an org chart, but useful and accurate." \
      "Checking what's in the folder. Claude looks before it acts. Unlike whoever reorganized the shared drive." \
      "File listing. Inventory before changes. Claude counts before cutting. Novel concept around here."
    )
    ;;

  *)
    MSG=$(pick 3 \
      "Claude used $TOOL_NAME. You don't know what that is. That's okay. You weren't going to learn anyway." \
      "$TOOL_NAME was invoked. Technical. Don't worry your pretty little head about it." \
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
