Create a complete desktop pet spritesheet based on the attached character reference image.
Reference image role: use the attached image to preserve the character's identity, hairstyle, outfit, facial features, colors, and overall vibe. If the reference is half-body, complete it into a consistent full-body character.

Style:
cute chibi 2D sprite, polished desktop pet style, big expressive head, small full body, clean silhouette, crisp antialiased edges.
The character must stay visually consistent across all frames.

Canvas and format:
Create one single vertical spritesheet.
Exact layout: 8 columns × 9 rows.
Target ratio: 1536 × 1872.
Each frame cell corresponds to 192 × 208.
Keep every non-empty sprite centered inside its cell with generous padding.
Every non-empty frame must show the full body, including head, hands, legs, feet, and shoes.
No cropped heads, no missing feet, no half-body frames.

Background:
Use a transparent background if supported.
If native transparency is not supported, use a perfectly flat solid #00ff00 chroma-key background for later background removal.
The background must be uniform, with no shadows, gradients, texture, floor plane, reflections, or lighting variation.
Do not use #00ff00 anywhere on the character.

Rows and actions:
Row 1: idle, 6 frames in columns 1-6, columns 7-8 empty.
Row 2: drag right, 8 frames, character leaning or being pulled toward screen-right.
Row 3: drag left, 8 frames, character leaning or being pulled toward screen-left.
Row 4: wake / greeting, 4 frames in columns 1-4, columns 5-8 empty, waving hello.
Row 5: mouse hover, 5 frames in columns 1-5, columns 6-8 empty, curious or alert reaction.
Row 6: reply error, 8 frames, apologetic, confused, or error reaction.
Row 7: reply done, 6 frames in columns 1-6, columns 7-8 empty, pleased or completed reaction.
Row 8: thinking, 6 frames in columns 1-6, columns 7-8 empty, thoughtful pose such as hand near chin.
Row 9: replying, 6 frames in columns 1-6, columns 7-8 empty, natural speaking or responding gestures.

Animation continuity:
Use subtle pose changes from frame to frame.
Keep the same character design, outfit, proportions, and colors in every frame.
The character should read clearly at small desktop-pet size.

Allowed small effects:
Small non-text motion marks, sparkle marks, question marks, or thought bubbles are allowed only if they do not split the frame detection or obscure the character.
Avoid using letters or readable text.

Strict negatives:
No visible grid lines.
No labels.
No numbers.
No watermarks.
No UI.
No extra characters.
No props that hide the body.
No duplicated limbs.
No malformed hands.
No cropped feet.
No half-body frames.
No shadows outside the character.
