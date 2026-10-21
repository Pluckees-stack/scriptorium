---
name: create-intent
description: Turn a rough idea for Scriptorium into features/<slug>/intent.md, the first file in the intent → spec → plan flow. Use when Grant describes a new feature, change or problem ("I want…", "players keep asking for…", "we need a way to…") before any spec or code exists, or when he asks for an intent.
---

# Create intent

The intent captures **what Grant wants and why**, in his own terms, once. It
is not a design and not a plan: no screens, no tables, no code. The next stage
(`create-spec`) reads it, so it must stand on its own.

## Steps

1. Read `NOTES.md` and check `features/` for an existing intent on the same
   idea. If one exists, update it rather than starting another.
2. Interview Grant like an analyst. Ask only what you can't answer from the
   repo, a few questions at a time, using `AskUserQuestion` where choices are
   clear. Cover:
   - the problem, and who has it (players, organisers, platform admins);
   - which event types it touches (campaign, tournament, game night, league,
     Open play, WarCastle);
   - what success looks like on the day, at the table;
   - constraints: deadlines (event dates), phones at the table, offline or
     patchy signal, 40+ players at once;
   - what is explicitly out of scope.
3. Draft the file from the template below. Use Grant's words where you can and
   the terms in `glossary.md` (battle, phase, roster, scenario…).
4. Show Grant the draft and ask him to correct anything misread. Iterate.
5. Commit it on the working branch as `features/<slug>/intent.md` (kebab-case
   slug, e.g. `features/battle-photos/intent.md`). Add a one-line entry to
   `NOTES.md` under your own section. Grant accepting it (a merge, or "intent
   agreed") is the gate to `create-spec`.

## Template

```markdown
# <Feature name> — intent

Status: draft | agreed (Grant, <date>)

## Problem
What is wrong or missing today, and for whom. One or two short paragraphs.

## Outcome
What is true once this is done, described from the user's side.

## Who and where
- Users: players / organisers / platform admins
- Event types: campaign / tournament / game night / league / Open play
- Parts of the app touched (tabs, as named in glossary.md)

## Success looks like
Concrete, checkable statements ("an organiser can… in under a minute").

## Constraints
Dates, devices, data, rules of the game, anything fixed.

## Out of scope
What this deliberately does not do.

## Open questions
Anything not yet decided, with who decides.
```

## Rules

- No solutions beyond what Grant himself asked for. Design belongs in the spec.
- Keep it short: one screen is ideal, two at most.
- British English, sentence case.
