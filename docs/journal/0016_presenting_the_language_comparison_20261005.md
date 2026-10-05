# 0016 — Presenting the language comparison

The user requested:

> make this comparision and conclusion into an easy to follow html presentation. use simple diagrams where it makes sense.

Created [a standalone HTML presentation](../comparison.html) from the comparison
recorded in `e96807c`. Eight slides cover the experiment, the common system flow,
each language's strengths and costs, the limits of the architecture, the rough
measurements, and the conclusion.

## Presentation decisions

Use short explanations, consistent colors for the three languages, small code
excerpts, and simple diagrams. The system diagram connects input to gameplay and
then branches to presentation, audio and score persistence. Each language slide
shows its allocation-failure path. The architecture slide retains the user's
earlier question about thirty enemy types: collection convenience does not supply
a content design.

The conclusion stays specific to these implementations: Odin offers the best
balance here, Zig makes failures most explicit, and C is direct but needs more
manual collection code. The measurement slide keeps the benchmark limitations
beside the numbers. Audio remains a shared C implementation.

The file embeds its CSS, JavaScript and the existing gameplay capture. It needs
no server, build step, external fonts or presentation library. Source-document
links work inside the repository; those supporting documents are separate from
the standalone deck. No gameplay or dependency files changed.

Navigation supports buttons, slide selectors, arrow keys, Page Up/Down, Home/End
and Space. Slides have URL fragments, and the page supports full screen and
printing. Without JavaScript, all slides remain readable in order. Narrow screens
stack content and diagrams; printing lays out one slide per landscape page.

## Verification

Checked the local file in an isolated headless Chrome session. All eight slides
were checked at 1440×900, 1280×720, 768×1024, 390×844 and 320×568. Adjusted spacing
for short laptop screens and navigation for narrow phones. All forty layouts
have no horizontal overflow; both desktop sizes fit each slide vertically.

Arrow, Home/End and Space navigation, buttons, slide selectors, URL fragments,
reload and browser Back/Forward behavior passed. Reading with JavaScript disabled
also shows all eight slides. There were no script exceptions or network dependencies.
Inspected desktop and phone captures, and verified an eight-page landscape PDF.
The temporary browser checks, screenshots and PDF are ignored under
`build/presentation`. The README and written comparison now link to the deck.
