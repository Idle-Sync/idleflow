# Design handbook

Read by `idleflow:designer` before it designs and by `idleflow:review-design` before it reviews. The numbers, pairings and checklists it refers to are in `procedures/design-data.md`.

A screen is designed when someone who has never seen it can tell in two seconds what it is for and what to do first, and would recognise it again tomorrow. Correct, accessible and consistent is the floor; distinct is the goal.

## 1. Decide the direction before any pixel

Write four lines before choosing a single token:

1. **Who and when.** The person using it and the moment they are in (a nurse between patients, a developer reading logs at 2 a.m., a parent comparing prices on a phone).
2. **Two words for the feel**, pulling in different directions so the result has tension: calm and exact, playful and dense, warm and technical. Words like "clean" and "modern" decide nothing; do not use them.
3. **The signature.** One thing a user would describe to a friend: an unusual type pairing, a colour used with conviction, a layout that breaks the grid on purpose, a motion that explains a state change. One, done fully, not five half-done.
4. **What it refuses.** The look it must not drift into (see section 9).

Every later choice is checked against these four lines. When two options both fit, pick the one a competitor would not.

## 2. Type carries most of the identity

- Pair two families with different characters: a display face with personality for headings, a quiet, highly legible face for text. A single family works only when its weights and widths are used as a deliberate system.
- Avoid the platform default stack as the whole identity unless the product must feel native; it signals that no one decided.
- Build sizes from a ratio (section "Type scales" in the data file), not from ad hoc pixels. Five to seven steps cover almost every product.
- Text blocks run 45 to 75 characters wide. Body line height 1.4 to 1.6; headings tighter, 1.05 to 1.25.
- Weight and size make hierarchy before colour does. If a heading needs colour to stand out, the scale is too flat.
- Load fonts with `font-display: swap`, subset them, and set fallback metrics so the layout does not jump.

## 3. Colour is a set of roles, not a swatch list

- Define roles: page, surface, raised surface, border, text, muted text, accent, accent text, and the states (info, success, warning, danger). Components use roles, never raw values.
- One dominant hue and one accent used sparingly beat an even spread of five colours. Tint the neutrals slightly toward the dominant hue so greys do not look dead.
- Contrast is measured, not eyeballed: body text at least 4.5:1 against its background, large text and UI boundaries at least 3:1 (WCAG 2.2 AA). Record the ratio next to each text role.
- Dark mode is its own set of role values, not an inversion: lower the saturation of accents, raise surfaces by lightness rather than shadow, keep text off pure white.
- Colour never carries meaning alone: pair it with an icon, a label or a pattern.

## 4. Space, grid and layout

- One spacing scale on a 4 or 8 point base. Every margin, padding and gap comes from it.
- Group by proximity: space inside a group is clearly smaller than space between groups.
- A grid gives order; breaking it once, on purpose, gives interest. Asymmetry, overlap and generous negative space are tools, not accidents.
- Density follows the work: a trading screen is dense, a sign-up page is sparse. Do not average them.
- Mobile first. Breakpoints come from where the content breaks, not from device names. No horizontal scroll at any width; touch targets at least 44 by 44 points.

## 5. Hierarchy and flow

- One primary action per view, visibly heavier than the rest. Secondary actions look secondary.
- Order the screen by the question the user arrives with, then what they do next.
- Headings describe; buttons say what happens ("Save changes", not "Submit").
- Show progress and position in multi-step flows; never strand someone without a way back.

## 6. Motion explains, it does not decorate

- Animate to show cause and effect: where something came from, where it went, what changed state.
- Durations: 120 to 200 ms for small feedback, 200 to 350 ms for panels and page elements, longer only for deliberate storytelling. Ease out when entering, ease in when leaving.
- One orchestrated entrance (staggered reveal) beats scattered effects on every element.
- Plain CSS transitions cover most needs. Timelines, scroll-linked sequences and complex choreography justify an animation library (the data file names the usual picks); propose it through the library step, never add it silently.
- Honour `prefers-reduced-motion`: replace movement with a fade or nothing.

## 7. Every state is designed

For each screen, design: empty (first use, with the action that fills it), loading (skeletons shaped like the content, not spinners everywhere), partial, error (what happened, what to do, without blame), success, and offline where it applies. For each control: default, hover, focus-visible, active, disabled, and invalid. Forms: visible labels, help text before the error, errors next to the field, input kept on failure.

## 8. Accessibility is part of the design, not a pass at the end

Semantic structure (landmarks, headings in order, real buttons and links), full keyboard use with a visible focus ring, logical focus order, labels for every input, text alternatives for meaningful images, no information in colour alone, content that survives 200 % zoom, and motion that respects user settings. ARIA only where native elements cannot express it.

## 9. Signs a screen looks generic

Replace each with a decision tied to the direction:

- a centred hero, a three-card feature row, a testimonial strip, in that order, because that is what pages look like;
- a purple-to-blue gradient on white, or any gradient chosen without a reason;
- every corner the same large radius and every card the same soft shadow;
- the default font stack and default icon set used everywhere with no adjustment;
- icons standing in for words the user needs to read;
- placeholder copy ("Lorem", "Feature one") that reached a review;
- decoration that does not serve the direction's two words.

## 10. Components and libraries

- Reuse what the repo already has before adding anything; extend its components to the new tokens.
- When a React project needs a component set, prefer one whose components are copied into the repo and owned there, built on accessible primitives, over a closed theme that fights custom tokens (see the data file).
- Component galleries are references for patterns and structure. Do not paste their code without checking its licence and fitting it to the tokens.
- A library is proposed through idleflow's library step with its reason and cost; the human accepts it before any task installs it.

## 11. What the design files hold

`design-system` (lasting, shared by every run): the direction's four lines, the tokens (type families and scale, colour roles for light and dark with contrast ratios, spacing, radius, elevation, motion durations and easing, breakpoints), the component inventory with what each is for, and the libraries in use.

`design` (one run): for each screen the run touches, its purpose, the layout from top to bottom on phone and desktop, the hierarchy, every state from section 7, the motion, the accessibility notes, and which tokens and components it uses. A spec is concrete enough that two implementers working in parallel build screens that look like one product.
