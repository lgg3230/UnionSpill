# Memory Entry Types

Four types of auto-memory entries. Check existing memory files before creating new ones to avoid duplicates.

## 1. User (`user` type)
**What:** Information about the user -- workflow preferences, research interests, institutional context.
**When to save:** User reveals a personal preference, affiliation, or working style that will persist across sessions.
**Example:** "Hugo prefers R over Python for analysis."

## 2. Feedback (`feedback` type)
**What:** User corrections, style preferences, quality standards.
**When to save:** User explicitly corrects an output or states a preference about how things should be done.
**Example:** "Don't add Stata references -- R, Python, Julia only."

## 3. Project (`project` type)
**What:** Project state that isn't captured in git -- current phase, shipped milestones, architectural decisions.
**When to save:** A milestone ships, a major architectural decision is made, or the project changes phase.
**Example:** "v4.3.0 shipped: HTML report pipeline + guide site overhaul."

## 4. Reference (`reference` type)
**What:** External references discovered during work -- papers, tools, parallel projects.
**When to save:** A significant external reference is discovered that will be useful in future sessions.
**Example:** "Goldsmith-Pinkham's claude-container repo for reference."

---

## What Does NOT Go in Memory

- Code patterns or architecture (derivable from reading the code)
- Git history (derivable from `git log`)
- Debugging solutions (the fix is in the code)
- Ephemeral task details (what you're working on right now)
- Anything already documented in CLAUDE.md, rules, or skills

## Rules

- Convert relative dates to absolute dates ("Thursday" --> "2026-05-09")
- Keep entries concise -- one line in MEMORY.md index, short file for details
- Update existing files rather than creating duplicates
