# Design data

Reference values for `procedures/design.md`. Starting points, not rules: the direction decides, and a value used here is recorded in the repo's design system with the reason.

## Type pairings

All are open-licence families on Google Fonts. Display face first, text face second.

| Feel | Display | Text | Suits |
|---|---|---|---|
| warm editorial | Fraunces | Source Sans 3 | publishing, food, lifestyle |
| calm editorial | Instrument Serif | Geist | portfolios, studios, essays |
| civic, trustworthy | Newsreader | Public Sans | government, health, finance |
| reading-first, accessible | Literata | Atkinson Hyperlegible | learning, long-form, low-vision users |
| precise, technical | Space Grotesk | IBM Plex Sans | developer products, analytics |
| terminal-native | IBM Plex Mono | IBM Plex Sans | CLIs, logs, infrastructure |
| friendly, characterful | Bricolage Grotesque | Figtree | consumer apps, communities |
| elegant consumer | DM Serif Display | DM Sans | retail, hospitality |
| expressive, creative | Syne | Manrope | agencies, events, art |
| bold, athletic | Archivo Black | Archivo | sport, fitness, campaigns |
| future-facing | Unbounded | Onest | hardware, crypto, launches |

## Type scales

Base 16 px. Round to whole pixels; set line height per step.

| Ratio | Name | Steps (px) | Use |
|---|---|---|---|
| 1.2 | minor third | 13, 16, 19, 23, 28, 33, 40 | dense apps, dashboards |
| 1.25 | major third | 13, 16, 20, 25, 31, 39, 49 | most products |
| 1.333 | perfect fourth | 12, 16, 21, 28, 38, 50, 67 | marketing, editorial |
| 1.5 | perfect fifth | 11, 16, 24, 36, 54, 81 | posters, landing heroes |

## Colour recipes

Written in OKLCH (lightness, chroma, hue) because equal lightness steps look equal. Build the neutrals first, then the accent, then the states; check every text role's contrast with the formula below before recording it.

| Feel | Neutrals | Accent | Notes |
|---|---|---|---|
| ink and paper | hue 85, chroma 0.008 | deep red, L 0.52 C 0.17 H 28 | warm off-white page, near-black text |
| night console | hue 255, chroma 0.015, dark first | electric green, L 0.82 C 0.17 H 150 | dark surfaces stepped by lightness |
| clinic calm | hue 220, chroma 0.01 | teal, L 0.55 C 0.09 H 195 | low chroma everywhere, generous space |
| market energy | hue 60, chroma 0.012 | saturated orange, L 0.68 C 0.19 H 45 | accent only on the primary action |
| forest field | hue 130, chroma 0.012 | moss, L 0.5 C 0.1 H 140, plus ochre second accent | earthy, outdoors, sustainability |
| bank vault | hue 250, chroma 0.01 | navy, L 0.35 C 0.08 H 260, with gold L 0.75 C 0.12 H 85 | gold for highlights only |
| studio pop | hue 300, chroma 0.01 | two accents at equal lightness, H 330 and H 180 | playful; keep text neutral |

Contrast ratio, WCAG 2.x: for each colour take the sRGB channels c in 0..1, linearise with `c <= 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`, luminance `L = 0.2126 R + 0.7152 G + 0.0722 B`, ratio `(L_lighter + 0.05) / (L_darker + 0.05)`. Text needs at least 4.5, large text (24 px, or 19 px bold) and UI boundaries at least 3. A few lines of Python or Node compute it; never estimate it.

## Spacing, radius, elevation

- Spacing (px): 2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128.
- Radius sets, pick one: sharp 0 / 2 / 4; soft 4 / 8 / 12; round 8 / 16 / 24; pill 999 for chips and buttons only.
- Elevation: three levels at most. Light theme: a small, tight shadow with low opacity for raised surfaces, a larger soft one for overlays. Dark theme: raise by surface lightness, not shadow.

## Motion

| Token | Duration | Easing | Use |
|---|---|---|---|
| instant | 100 ms | linear | colour and opacity on hover |
| quick | 150 ms | cubic-bezier(0.2, 0, 0, 1) | buttons, toggles, small feedback |
| standard | 250 ms | cubic-bezier(0.2, 0, 0, 1) | panels, menus, cards |
| enter | 300 ms | cubic-bezier(0, 0, 0.2, 1) | elements arriving |
| exit | 200 ms | cubic-bezier(0.4, 0, 1, 1) | elements leaving |
| story | 500 to 900 ms | per sequence | one orchestrated entrance or scroll sequence |

Stagger list items by 30 to 60 ms, at most eight before the rest appear together.

## Breakpoints

Start from content: where a line gets too long or a row too cramped. Common landing points: 480, 768, 1024, 1280, 1536 px. Check every screen at 360 and 390 px wide (small phones) and at 1440 px.

## Checklists by screen type

- **Landing**: one promise in the first view, one primary action, proof near the claim it supports, a page that still works with images off.
- **Sign up and sign in**: the fewest fields, a visible password rule before the error, the way back and the way to the other form, errors that do not reveal which accounts exist.
- **Onboarding**: one goal per step, a visible count of steps, skip where possible, a first useful result before any setup that can wait.
- **Dashboard**: the one number or list the user came for at the top left, comparison context for every number, empty states that say how data arrives, no chart without a question it answers.
- **List and table**: sortable headers that show the sort, a sticky header for long lists, row actions on hover and in a menu for touch, filters that show what is filtered, pagination or virtual scroll past a few hundred rows.
- **Detail**: the identity of the item first, primary action near it, related items after the main content.
- **Form and settings**: groups with headings, labels above fields, sensible defaults, save state shown, destructive actions separated and confirmed.
- **Search**: results as the user types where cheap, the query echoed, no-result states that suggest a next step.
- **Checkout and payment**: total always visible, steps shown, nothing new at the last step, errors that keep entered data.
- **Error and empty pages**: what happened in plain words, what to do next, a way home.
- **Mobile navigation**: at most five top-level destinations, the current one marked, reachable by thumb.

## Libraries to propose

Proposed through idleflow's library step with research and the human's yes; never installed by a design agent.

| Need | First choice | Also consider | Note |
|---|---|---|---|
| timelines, scroll-linked sequences, text and SVG animation | GSAP (free for commercial use, its plugins included) | Motion for React-only projects | GSAP's licence prohibits use inside tools that let people build visual animations without code; check it if the product is such a tool |
| simple transitions | CSS transitions and `@keyframes` | View Transitions API | no dependency |
| React components owned in the repo | shadcn/ui (components copied in, built on Radix primitives, MIT) | Radix primitives directly, React Aria | style them with the design system's tokens |
| Vue or Svelte components | shadcn-vue, shadcn-svelte, Bits UI | Radix Vue | same approach as above |
| icons | Lucide | Phosphor, Tabler | one set per product, at consistent stroke widths |
| pattern references | 21st.dev | the repo's own components first | references for structure; check the licence of any code before using it |
