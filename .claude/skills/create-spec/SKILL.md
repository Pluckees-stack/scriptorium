---
name: create-spec
description: Write features/<slug>/spec.md from an agreed intent.md — the second file in the intent → spec → plan flow, combining requirements and design for Scriptorium. Use when Grant has agreed an intent and asks for a spec or design, or says "spec it".
---

# Create spec

The spec says **what will be built**: behaviour, screens, data and rules,
precise enough that a plan can be made from it. Claude writes it; Grant
reviews it. It must conform to the project's own rules and flag where they
clash.

## Steps

1. Read `features/<slug>/intent.md`. If it isn't marked agreed, stop and ask.
2. Read the house rules it must obey: `CLAUDE.md` (single file, UI components,
   no explainer text, accessibility, Supabase anon key with RLS),
   `glossary.md`, and the relevant parts of `scriptorium-documentation.md`,
   `index.html` and `migrations/` to see what already exists.
3. Draft the spec from the template below. For every UI element, name the
   existing component from CLAUDE.md it will use. For every piece of data,
   say which table it lives in and who can read and write it.
4. Flag concerns plainly in their own section: clashes between the intent
   and house rules, new components that seem needed, security or RLS risks,
   anything that would need a migration, places where explanatory text seems
   needed (ask, don't add it).
5. Carry forward every open question from the intent: answered, or still open
   with who decides.
6. Show Grant the spec. Resolve flagged concerns with him before planning.
7. Commit as `features/<slug>/spec.md` next to the intent, and update the
   intent's status line if anything changed. Grant agreeing the spec is the
   gate to `create-plan`.

## Template

```markdown
# <Feature name> — spec

Status: draft | agreed (Grant, <date>)
Intent: ./intent.md

## Summary
Two or three sentences: what gets built.

## User stories
- As an organiser, I can … so that …
- As a player, I can … so that …

## Behaviour
Numbered rules, including edge cases: empty states, permissions, a player
in two events, phones vs desktop, realtime updates, what happens on error.

## Interface
Per screen or tab: where it sits, what it shows, and the controls, each named
by its CLAUDE.md component (`button.act`, `.scope-switch`, `.toggle-switch`,
`details.admin-section`, …). Exact UI text in sentence case, glossary terms.
Keyboard and ARIA notes.

## Data
Tables and columns added or changed, RLS policies (who reads, who writes),
views or functions. Say "no migration" if none.

## Acceptance criteria
Checkable statements that prove the spec is met. These become the plan's
proof.

## Concerns
Clashes with house rules, new components requested, risks. Each with a
suggested resolution.

## Open questions
Carried from the intent or new, with who decides.
```

## Rules

- No implementation detail (function names, step order): that is the plan.
- Never propose exposing the service role key or bypassing RLS.
- Don't invent new button, switch, chip, tab, menu or stepper classes; if
  none fits, propose a modifier and list it under Concerns.
