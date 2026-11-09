# Side-view pilot: Gemini prompt

Attach both images from this folder: `side_view_reference.png` (the pilot's look, the colors, and the size next to the lander) and `side_view_layout_template.png` (the sheet to fill). Then paste the prompt below.

If the whole sheet comes back inconsistent, ask for one row at a time: add "Draw only row N" at the end, and attach the same two images.

---

Create a pixel-art sprite sheet of an astronaut seen from the SIDE, in profile, facing RIGHT, for a 2D sci-fi game.

The first attached image shows the same astronaut seen from above, top-down. Keep the identical suit design, colors, and proportions, but draw it from the side:

- A 1970s NASA-style spacesuit: off-white suit (#E8E4DA) shaded with light gray (#A9ADB3) and mid gray (#6B7079), with darker gray joints, gloves, and boots (#3D4148, #23262B).
- A boxy life-support backpack on the back, off-white with gray panels.
- An orange shoulder patch (#D9541E) and a small blue patch (#2F5D8C).
- A round helmet with a reflective GOLD visor on the front (#D4A23A, highlight #F2D27A, shading #9C6B1E).
- Every shape has a 1-pixel near-black outline (#0E0F12).

Pixel-art rules:

- True pixel art on a crisp, uniform pixel grid: every pixel is a clean square block of the same size.
- No anti-aliasing, blur, gradients, glow, soft shadows, or noise.
- Use only these colors: #0E0F12, #23262B, #3D4148, #6B7079, #A9ADB3, #E8E4DA, #D9541E, #F28A3A, #7A2E12, #2F5D8C, #6FA3C8, #5A3E12, #9C6B1E, #D4A23A, #F2D27A, and for flames only #FFF3C4, #FFB347, #E8501F.
- At native size the astronaut is about 40 pixels tall from helmet top to boot sole, and about 22 pixels wide including the backpack, drawn at a large whole-number zoom. The small off-white box beside the lander in the first image is that size.

Layout: follow the second attached image. It's a grid of equal square cells, one frame per cell, with the empty dark-purple areas left empty. In every cell, the boots stand on the lower white line and the helmet top reaches the upper line, the astronaut is centered left to right, and the astronaut is the same size in every frame. The background is flat solid magenta (#FF00FF) everywhere: no ground, shadows, text, labels, numbers, grid lines, or borders in the result.

Rows, top to bottom:

1. Idle, 4 frames: standing relaxed, breathing subtly (the backpack rises one pixel and settles).
2. Walk, 8 frames: one full walk cycle, slightly heavy, bouncy low-gravity steps.
3. Jump, 6 frames: crouch, push off, rising, peak with legs tucked, falling, landing crouch.
4. Climb, 4 frames: climbing a ladder, seen from the side, with hands and feet alternating on rungs. Don't draw the ladder.
5. Use terminal, 3 frames: reaching forward with the near arm at chest height, pressing, pulling back.
6. Jetpack hover, 4 frames: legs dangling, with small flames (#FFF3C4, #FFB347, #E8501F) firing downward from the bottom of the backpack, flickering between frames.
