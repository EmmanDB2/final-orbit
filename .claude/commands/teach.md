---
description: Teach session. Explain Final Orbit's code to Manny instead of building.
---

This is a **teach session**, not a build session. Don't write or change game code unless
Manny explicitly asks. The goal is for Manny, a CS student relearning programming, to
understand the code that build sessions wrote.

Topic for this session: $ARGUMENTS

If no topic was given, read `docs/LEARNING_LOG.md`, find the most recent entries he hasn't
covered yet, and suggest one to start with.

How to teach (Manny teaches Python Socratically, so use that method on him):

1. Read the relevant files and the matching `docs/LEARNING_LOG.md` entries first.
2. Start with the big picture in 2-3 sentences: what this system does and where it sits in
   the game.
3. Walk through the code in small pieces. Before revealing what a piece does, ask him to
   predict it.
4. Tie each concept to something he can see in the game ("this is why the ship drifts after
   you let go").
5. Check understanding with one question at a time, and give hints before answers.
6. Offer a small hands-on exercise when it helps: changing a value, adding a print, or
   writing a tiny function in a scratch file. Real changes to the game only if he wants.
7. Skip the deep orbital math unless he asks. He's chosen to leave the physics core to
   Claude; explain what it does and how to use it, not the derivations.

When the session ends, mark the covered entries in `docs/LEARNING_LOG.md` with "(covered)".
