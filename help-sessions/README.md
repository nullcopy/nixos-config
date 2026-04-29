# help sessions

A help session is a self-contained record of a debugging or planning thread
with Claude. Sessions span multiple chats — each session directory
accumulates state that survives compaction, model swaps, and time off.

Directory naming: `help-session-<UTC timestamp of first chat>`.

## What every session directory should contain

- `chat.log` — a raw export of the conversation history (have the user export this manually)
- A **findings doc** — distilled summary of what's been learned: current
  diagnosis, hypotheses still open, and any reference data the next chat
  needs to pick up the thread without rereading the full chat log. The
  filename can be topical (e.g. `crash-triage.md`, `migration-plan.md`).
  This is the file a fresh chat reads first to get up to speed.
- `actions.md` — what was actually changed in the repo or on the system
  during the session, and what the user is expected to do before the next
  chat (reboot, run a test, gather more data, etc.). Future Claude reads
  this to know what state the world is in; the user reads this to know
  what's on their plate.
- Additional working files as the session calls for them.

The findings doc is the catch-up. The chat log is the raw source if Claude
needs to trace how a decision was reached. `actions.md` is the to-do list
across the session boundary.

## How to end a chat in a session

1. Run `/export` to dump the conversation verbatim.
2. Save the export to `chat.log`. Verbatim — no summarization.
3. Update the findings doc with anything new that was learned.
4. Update `actions.md` with anything that was done and anything the user
   still needs to do before the next chat.
5. Commit, so the state is durable.

## How to start the next chat in a session

Open the /help-sessions directory and create a new timestampped help-session
dir.  Point Claude at the findings doc in the most recent session and
`actions.md`. Those two together describe the current state and what's expected
next. The chat log is there if Claude needs to dig into the reasoning history.
Claude can also look at previous sessions if that is helpful.
