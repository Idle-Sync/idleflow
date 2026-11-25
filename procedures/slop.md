# UI slop: the catalogue and how it is used

Read by `idleflow:slop-auditor` and `/idleflow:unslopify`, by the designer while it designs and by the design reviewer (`procedures/design.md` §9). The evidence for every pattern, with its sources, is in `docs/research/ui-slop.md`. Last reviewed: 2026-11-25. The patterns that mark a UI as generated move within about a year; when this date is more than six months old, the audit says so in its report and the catalogue is due a refresh from new research.

## What a pattern is

A pattern is an **unchosen default**: a look a generator falls into when nothing told it otherwise. The same thing chosen on purpose is design, not slop. So nothing here is banned. Every hit is weighed against what the project chose (its design system file, its tokens, its brand assets, the waivers in `.idleflow/slop-waivers.md`), and a hit the project chose is reported as chosen and never fixed.

No single pattern marks a UI as generated; almost every one has defenders. What people recognise is several of them together, so a page is scored on the combination (see **Scoring**).

## Tiers

- **static**: `scripts/slop-scan.sh` finds it in the source. A hit names the file and line.
- **rendered**: `scripts/slop-page.js`, evaluated inside the loaded page by a browser tool, measures it and returns it in `flags`.
- **judged**: the auditor decides it from screenshots and the page, because only judgement can tell (whether something is real, a sequence, chosen, right for the audience).

A pattern with two tiers is found by the first and confirmed by the second.

## The catalogue

Weight is how strong the evidence is that people read the pattern as generated: **strong** (many independent sources plus data or tool support), **medium**, **contested** (named, and defended about as often), or **note**. A palette is not a reliable tell: the generated look has moved between palettes, and people's own designs use every one of them. So every pattern that is only a hue or a palette is a **note**: reported, so the human sees it, but never scored and never fixed unless the human asks. A `contested` pattern whose look is `-` is likewise reported in an audit's list and never scored, since no stronger pattern of its look can stand beside it. Look is the cluster it belongs to: **2024** (the earlier generated look), **paper** (the later one, a warm light page with a serif display face), **template** (structure any generated page shares), or `-`.

### Colour and surface effects

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| violet-accent | an accent or primary hue in the violet-indigo band the project's brand does not define | static | note | 2024 |
| gradient-text | headline text filled with a gradient | static | medium | 2024 |
| gradient-surface | gradients on backgrounds, buttons or borders that nothing in the direction or the subject calls for | static | contested | 2024 |
| stock-shadow | one soft shadow on every card and panel | judged | medium | template |
| neon-glow | a coloured glow with no offset, mostly on a dark page | static | medium | 2024 |
| blur-orbs | large blurred shapes or halos behind content | static | contested | 2024 |
| glass-cards | frosted translucent panels as the default surface | static | contested | 2024 |
| cream-paper | a warm off-white page as the default surface | static | note | paper |
| terracotta-accent | a warm orange-brown accent | static | note | paper |
| acid-accent | one saturated acid accent on a near-black page | static | note | - |
| design-drift | colour literals in components outside the project's tokens; screens that look like different products | static | medium | - |
| low-contrast | text under its contrast threshold against what is behind it | rendered | medium | - |
| hue-clash | many unrelated saturated hues with no role | rendered, judged | note | - |

### Type

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| stock-display-face | a framework's default sans as the display face | static | contested | 2024 |
| stock-icons | a framework's default icon set used everywhere with no adjustment | judged | contested | 2024 |
| icon-for-words | icons standing in for words the end user needs to read | judged | medium | - |
| eyebrow-label | a tracked all-caps small label above headings | static | strong | paper |
| accent-word | one word of a headline set apart in another face, style or colour | static | medium | paper |
| mono-costume | a monospace face on text that is not code | static | medium | paper |
| tiny-text | body or label text set too small to read comfortably | rendered | medium | paper |
| flat-hierarchy | heading levels that render close to one size, or barely larger than the body | rendered, judged | medium | - |

### Layout and components

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| template-sequence | a centred hero, a row of three cards, then a call to action and footer | rendered, judged | strong | template |
| box-everything | content boxed by default; rounded boxes inside rounded boxes | rendered | strong | template |
| side-stripe | a thick coloured border on one side of a rounded card | static | strong | paper |
| pill-everything | one large radius on everything; pill-shaped buttons | static | medium | 2024 |
| icon-tile | an icon in a tinted rounded tile above each heading | judged | medium | template |
| ordinal-numbering | two-digit ordinals on content that is not a sequence | static, judged | medium | paper |
| stat-banner | a row of large numbers with small labels that the product cannot back | judged | medium | template |
| bento-grid | a grid of unequal tiles as the default layout | judged | contested | template |
| same-rhythm | every section the same height and spacing | rendered, judged | medium | template |
| off-scale-spacing | one-off spacing values outside the project's scale | static | medium | - |
| text-wall | more words in one screen than a reader takes in | rendered, judged | medium | - |
| no-images | a long page carried by icons and text with no real picture of the product | rendered | medium | template |
| dashboard-chrome | marketing-page or dashboard furniture inside an app screen with one job | judged | medium | - |

### Decoration and punctuation

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| emoji-icons | emoji standing in for icons in navigation, headings, features or buttons | static | strong | 2024 |
| sparkle-ai | a sparkle mark on anything that is an AI feature | static | contested | 2024 |
| badge-above-heading | a small pill badge above the main heading | judged | medium | 2024 |
| template-punctuation | separator strings, middle-dot meta strings and trailing arrows on links as ornament | static | medium | paper |
| chip-overload | tags, badges or status chips on most items | judged | medium | - |
| logo-marquee | a scrolling wall of logos | static, judged | medium | template |
| fake-mock | a hand-drawn product mock or fake window chrome in place of the product | judged | medium | - |

### Motion

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| reveal-everything | content fading or sliding in on scroll, section after section | static, judged | strong | 2024 |
| hover-lift | cards that lift or grow on hover, clickable or not | static | medium | 2024 |
| pulse-dot | a pulsing dot not wired to any live state | static, judged | medium | - |
| shimmer-bounce | shimmering text or bouncing elements as decoration | static | contested | - |
| scroll-hijack | scrolling taken over, or carousels for content that fits | judged | medium | - |
| no-reduced-motion | animation with no reduced-motion rule anywhere in the project | static | medium | - |

### Copy

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| generic-hero | a headline any product could use: a verb, "your", a noun, a promise | static, judged | strong | template |
| buzzwords | stock marketing intensifiers in place of a concrete claim | static | strong | - |
| rebuttal-cadence | the dismiss-then-assert sentence pattern and its stacked short negations | static | medium | - |
| manifesto-filler | grand sentences about purpose that state nothing | judged | medium | - |
| em-dash | dense em dashes through interface copy | static | contested | - |
| chat-leak | text about how the page was built, or from the conversation that built it | static, judged | medium | - |
| filler-repeat | a heading and its description that say the same thing | judged | medium | - |

### Honesty and behaviour

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| fake-proof | invented numbers, testimonials, customer logos, placeholder names or placeholder text | static, judged | strong | template |
| fake-controls | links to nowhere, buttons with no action, forms that report success without sending | static, judged | strong | - |
| raw-errors | raw error text shown to the end user, or no error shown at all | static, judged | medium | - |
| missing-states | no designed empty, loading or error state where data can be absent, slow or fail | judged | medium | - |
| broken-basics | sideways scroll, content stuck hidden, failed images, controls too small to tap | rendered | strong | - |
| toast-overuse | toasts or modals for routine events | judged | medium | - |
| no-architecture | everything on one screen; no primary task per screen | judged | medium | - |

### The whole page

| id | pattern | tier | weight | look |
|---|---|---|---|---|
| median-look | without its logo, the page could belong to any product | judged | strong | - |
| quilt | many effects competing, none of them the one memorable thing | judged | medium | - |
| idle-decoration | decoration that serves neither the subject nor the direction | judged | medium | - |
| greyscale-collapse | hierarchy that disappears in greyscale because colour alone carries it | judged | medium | - |
| audience-mismatch | a style at odds with who the end users are and what they came to do | judged | medium | - |

## Chosen or default

For each hit, before it is scored:

- **chosen** when the project's design system file, tokens or brand assets define it, when the run's `design.md` spec names it for that screen (for a reader that has one), when a waiver in `.idleflow/slop-waivers.md` names it for that place, or when the source line holds `slop-ignore`. Reported as chosen with the record that chose it; never scored and never fixed.
- **default** when it matches a framework's default theme, or a literal no project record defines. A framework default is not a choice.
- **ask** when the evidence cannot settle it. The human is asked, and the answer is kept as a waiver or treated as a default.

## Scoring

The score is a lead, not the verdict. Score each page audited, from its default hits only:

- Count the distinct patterns, not the hits: one pattern on ten lines counts once. A static hit counts for the pages that render its file. A note never counts.
- A contested pattern counts only on a page where a strong or medium pattern of the same look also counts; one whose look is `-` never counts.
- **low** at 0 to 1, **medium** at 2 to 3, **high** at 4 or more.
- A look is **named** for the page when three or more of its patterns count; the report says which look the page reads as.
- `median-look` and `quilt`, when judged present, raise the page one level.

The repo's score is its highest page score, with the looks named on any page.

## The verdict: how the page feels

Whether a page reads as made by people or as generated has no clear line. It is a judgement of the whole, and the patterns only point at where to look. For each page the auditor gives a verdict, **made by people**, **mixed** or **generated**, with how sure it is (**clear** or **borderline**). The verdict is calibrated against `docs/research/human-made.md`: the traits that recur in sites people praise for craft, and how they differ from generated pages. Judge **craft, not taste**. Craft is whether the page's choices follow from its own subject: copy specific to this product and its people, imagery made for it, type chosen for what it sets, a composition that holds together, real facts and states. Taste is the style chosen. People's own work spans every taste, so taste is never evidence either way. The reasons name the traits the page has and lacks, in what an end user sees; a count of traits raises or lowers how sure the verdict is, and never settles a borderline page. The references calibrate the judgement; none of them is a look to aim for, because pages that converge on a reference are another sameness. A page can score low and still read as generated, or score medium and read as made by people; the verdict says so, and the recommended level follows the verdict, with the score as its evidence.

## Fix levels

The human chooses one, after the report. The smallest level that moves every page read as generated toward made by people is recommended. A note is fixed only when the human asks for it.

- **report**: nothing changes.
- **polish**: only the scored default hits, each removed or moved onto an existing token or component. No token, layout or copy changes beyond the hit's own line.
- **restyle**: as polish, plus the token changes the human approved in this run. Layout stays.
- **redesign**: the composition of the named screens changes, starting from new directions the human chooses.

## Fixing

- Removal before replacement: most patterns go by taking something away. A replacement is used only where removal leaves a gap.
- Only the project's own tokens, components and content. A new colour, face, radius or layout comes only from a source the project or the human gave (the brand, the subject, a reference the human named, an existing token). Without one, nothing new is prescribed: polish removes, and a direction for restyle or redesign is chosen by the human from options, never picked silently.
- Nothing is invented: a missing fact, number or quote stays an empty, visible slot. Every changed line of copy is listed before and after. Legal and consent text stays as it is.
- Wiring stays: links, ids, test hooks, handlers and routes are recorded before a change and unchanged after it.
- **Checked again**: every fixed page is scanned and measured again, and the fix passes only when it adds no pattern, from any look, that the audit did not find. A fix that moves the page from one look to another has failed.

## Honest about the ceiling

A scan removes tells; it does not give a page a point of view. The report says what was removed, what was left as chosen, and what still needs a human's taste. It never calls the result designed.
