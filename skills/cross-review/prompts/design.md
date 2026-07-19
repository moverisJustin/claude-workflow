# Dimension: design

Review the UI/UX changes in the pack — components, styles, layouts, marketing
pages — for design defects, and especially for anything that reads as
"AI-generated page" rather than designed.

Hunt specifically for: template-default typography and
spacing, gradient/glassmorphism clichés, purple-blue AI palettes, uniform
border radii, emoji-as-design, generic hero/feature-grid structures,
inconsistency with the project's existing design system, and anything that
reads as "AI-generated page" rather than designed. Ask for concrete fixes,
not vibes.

Rules:

- Respect the project's existing design system and conventions from the memory
  section of the pack — an established house style is not an AI tell, even if
  you would have chosen differently. Do not invent a new design system.
- Use category `design`. Put the concrete fix in `suggested_fix`; use
  `failure_scenario` to describe what a user sees and why it reads as generic
  or broken.
- Anchor findings with `file` and `line` (the component/style rule at fault)
  whenever possible.
- If you find nothing, return an empty `findings` array. Never pad.
