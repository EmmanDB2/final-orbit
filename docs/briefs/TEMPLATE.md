# Brief: <feature>

Written <date> by Opus, from Manny's calls, for the builder agent (Sonnet). Copy this file to
`docs/briefs/<feature>.md` and fill it in. A brief settles everything the builder would otherwise have
to decide; the builder builds it as written and reports back.

## What and why

Two or three sentences: what the player gets, and the decisions behind it, with the DESIGN.md section
it lives in. Quote Manny where his words decided something.

## Decided

- Each decision the builder must not reopen, one per line: numbers, names, rules, what's out of scope.

## Tickets

Each is about an evening of work and one commit.

### 1. <short name>

- **Does:** what's true when it's done, as the player sees it.
- **Touches:** the files to change or add, and the functions or signals involved.
- **How:** the approach, where it isn't obvious from the code: the math, the order of things, what to
  reuse.
- **Check:** how to know it works: which test suites, and what a throwaway check should prove.

### 2. <short name>

...

## Art

Anything that needs drawing goes to Gemini through Manny. For each piece: what it is, its size at
5 cm a pixel, the view (side or top-down), the colors from the agency palette by hex (human-made things
only; nature's colors are free but never telemetry cyan 7FE3D6 or agency orange D9541E), a 1 px dark
outline (0E0F12) on human-made things, and a template image for scale if there is one. Until it's
drawn, say what the builder uses in its place.

## When it's done

- What goes in DESIGN.md, and its change-log row.
- What the checker should look at, with screenshots.
- What to tell Manny to try on the Fold.
