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

Anything that needs drawing gets its own art brief, `docs/briefs/<asset>_art.md`, from
`docs/briefs/ART_TEMPLATE.md`. Gemini, through `agy`, does all of it: the template, the concept, and the
finished asset in the Asset Editor, with Manny's OK on the concept and on the flat exterior. Here, for
each piece, say what it is, its size at 5 cm a pixel, the view (side or top-down), and which ticket brings
the export in; the builder does only that ticket. The game reads material from art color (the table in
the art template), so the colors set the mass: numbers that depend on mass should come from the game's
own measure (`tools/ship_numbers.gd` for ships), not the editor's. Nature's colors are free but never
telemetry cyan 7FE3D6 or agency orange D9541E. Until it's
drawn, say what the builder uses in its place.

## When it's done

- What goes in DESIGN.md, and its change-log row.
- What the checker should look at, with screenshots.
- What to tell Manny to try on the Fold.
