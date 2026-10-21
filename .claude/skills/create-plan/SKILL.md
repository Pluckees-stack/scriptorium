---
name: create-plan
description: Write features/<slug>/plan.md, a reviewable implementation plan for Scriptorium made from an agreed intent.md and spec.md, before any code is written — the third file in the intent → spec → plan flow. Use when Grant has agreed a spec and asks for a plan, or says "plan it".
---

# Create plan

The plan says **how the spec will be built**: which parts of the code change,
in what order, what could go wrong and how we'll prove it works. Write it
before touching code, while only reading the codebase.

## Steps

1. Read `features/<slug>/intent.md` and `spec.md`. If the spec isn't agreed,
   stop and ask.
2. Explore without editing (plan mode if available): find the sections of
   `index.html` (HTML, CSS and JS) the change touches, the Supabase tables,
   policies and functions involved, and tests in `tests/`.
3. Draft the plan from the template below.
4. Challenge it yourself before showing Grant: what could break, which step is
   riskiest, which alternatives were rejected and why. Write the answers in.
5. Test: could someone who hasn't seen this conversation implement from the
   plan alone? If not, add what's missing.
6. Show Grant. Iterate until agreed, then commit as `features/<slug>/plan.md`.
7. During the build, if the work departs from the plan, update `plan.md` in
   the same commit. The PR description links all three files and is reviewed
   against the plan.

## Template

```markdown
# <Feature name> — plan

Status: draft | agreed (Grant, <date>) | built (PR <link>)
Intent: ./intent.md · Spec: ./spec.md

## Approach
A short paragraph on the chosen approach.

## Changes
- `index.html`: which sections (by function, element id or CSS block) and what
  changes in each.
- `migrations/NNN_<name>.sql`: tables, columns, RLS policies (Grant runs it;
  add it to migrations/README.md as not yet run). Or "no migration".
- `seeds/`, `tests/`, `glossary.md`, `scriptorium-documentation.md` as needed.

## Order of work
Numbered steps, each small enough for one commit, each leaving the app
working. Migration first if there is one.

## Risks
What could break (other event types, realtime, RLS, phones, existing data),
the riskiest step, and how each is guarded.

## Alternatives rejected
Option, and why not.

## Proof
How each acceptance criterion in the spec is shown to hold: tests to add or
run, and browser checks (which screen, which role, phone and desktop width).

## PR
One PR or several, whether it needs a migration (so Grant must merge), and
what to add to NOTES.md.
```

## Rules

- Keep everything in `index.html`; never plan a split into modules.
- One piece of work per session: if the plan is bigger, split it into PRs and
  say so.
- Reuse the CLAUDE.md UI components named in the spec.
