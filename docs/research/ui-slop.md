# UI slop: what makes a UI read as AI-made

The evidence behind `procedures/slop.md`, the catalogue `/idleflow:unslopify` checks against. Two independent reports, gathered on 2026-11-25 by different routes: Part 1 was open-ended (Reddit threads through an archive, Hacker News, two studies, five tools); Part 2 started from a seeded list of sources (the Hacker News API, a mined Reddit dataset, the same tools). Where they agree, the pattern is in the catalogue as strong or medium; where they disagree, the catalogue marks it contested. Refresh both before the catalogue's review date passes.

# Part 1

## What makes a UI read as AI-made: a cited catalogue for "unslopify"

Research date: 2026-11-25. Scope: websites and app UIs, with a focus on output from Claude and Claude Code.

How the material was gathered:

- **Reddit.** Full comment trees for 40 threads, pulled verbatim from the Arctic Shift Reddit archive (`arctic-shift.photon-reddit.com/api/comments/tree?link_id=...`), because reddit.com returns 403 to scripts. The threads come from r/ClaudeAI, r/ClaudeCode, r/vibecoding, r/webdev, r/web_design, r/Frontend, r/UI_Design, r/UXDesign and r/SaaS. Every Reddit quote below is copied from that archive text, and its permalink is given.
- **Hacker News.** Six threads, read through WebFetch on `news.ycombinator.com/item?id=...`. HN quotes are short fragments that the fetch tool extracted from the page, attributed to the username shown, and cited by thread URL.
- **Prior quantitative work.** Two studies: a Reddit mining study (JCarterJohnson, 3.2M posts and 3,033 comments) and a DOM scan of about 1,590 Show HN landing pages (Adrian Krebs).
- **Tools.** Five anti-slop tools and rule sets, read from source: Anthropic frontend-design, Hallmark, Impeccable, unslop-ui and Uncodixfy. OpenAI's frontend prompt guide was also read.

How the "named by" count works: it is the number of independent sources in this research that name the pattern. A source is a separate thread, article or tool, not a single comment. Where the JCarterJohnson study has a comment count for the pattern, that count is given too.

---

### 1. Summary

#### What people agree on

1. **Sameness is the main complaint, more than any single feature.** In the JCarterJohnson Reddit study, the two largest buckets by far are "all looks the same / template / cookie-cutter" (13.1% of design-context posts, 91% negative) and "screams AI / soulless / slop" (13.0%). Every named visual tell sits under 3% ([repo](https://github.com/JCarterJohnson/vibecoded-design-tells), `unslop-ai-ui/summary.txt`). A typical complaint is a r/ClaudeAI post with 2,445 upvotes, whose author found "a dozen other sites that had the exact same design cues and colors" ([thread](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/)).
2. **The look is what you get by default from an unspecified prompt.** Nearly every thread lands on "generic prompt = generic result" ([r/ClaudeCode](https://reddit.com/r/ClaudeCode/comments/1p9srut/finally_figured_out_why_claudes_ui_generations/nrfmpq5/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/np02vjf/)). Anthropic calls the cause "distributional convergence" toward safe, high-probability choices ([Claude blog](https://www.claude.com/blog/improving-frontend-design-through-skills)). The most-upvoted fixes are the same everywhere: give the model a reference site, a design system or a DESIGN.md, and specific direction ([r/ClaudeAI 120 pts](https://reddit.com/r/ClaudeAI/comments/1ws9oix/how_are_people_actually_getting_claude_to_build/pcjis33/), [r/ClaudeAI 373 pts](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/)).
3. **One cluster is recognised everywhere: the "2024 look".** It is a purple or indigo accent, purple-to-blue gradients, gradient headline text, dark backgrounds with neon glow, Inter, rounded cards in a three-up grid under a centred hero, and emoji as icons.
4. **A second cluster has replaced it: the "Claude look".** It is a cream or beige page, a high-contrast serif display face, a terracotta or orange accent, tracked all-caps eyebrow labels, monospace micro-labels, middle-dot meta strings, "01/02/03" numbering and colored left-border cards. HN commenters, Jim Nielsen's essay and Anthropic's own skill file all name it. The skill names its exact colours (#F4F1EA paper, #D97757 accent) ([Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [HN "The AI Aesthetic"](https://news.ycombinator.com/item?id=49117099)).
5. **Copy is a tell as strong as visuals.** People name "No X. No Y. Just Z" taglines, "Build / Manage / Grow" heroes, buzzwords, em dashes, text that leaks from the chat (how the site was built) and walls of text ([r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/), [HN "Tells of a Slop UI"](https://news.ycombinator.com/item?id=49867038)).
6. **Product designers care most about structure and behaviour.** Their complaints are no hierarchy, everything on one screen, design-system drift between screens, raw errors, missing states and broken links ([r/UXDesign](https://reddit.com/r/UXDesign/comments/1s7e3d1/the_design_drift_created_by_vibe_coding_is_insane/), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1wn97pn/psa_dont_want_your_app_to_look_like_ai_slop_stop/)).

#### Where people disagree

- **"Websites always looked the same."** The Bootstrap, WordPress-template and Material eras are the most common rebuttal, and often the top comment: "Were you not here for the Web 2.0 phase where literally everything was the unthemed Bootstrap framework?" (118 pts, [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/noztjte/)). Others: [r/vibecoding 38 pts](https://reddit.com/r/vibecoding/comments/1ta6r5y/why_do_all_aigenerated_websites_look_exactly_the/ol780j2/), [r/SaaS 24 pts](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19smcbma14m05/), and [HN](https://news.ycombinator.com/item?id=49867038) (users api, thiht, ronbenton).
- **"Generic is fine and converts."** Familiar layouts help users on phones ([r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19slz0univmg0/)). A two-decade designer says "If a website converts well and makes me money, done deal" ([r/web_design](https://reddit.com/r/web_design/comments/wx78w4/barbershop_websites_all_look_the_same_change_my/ilrcu3e/)). tptacek on HN says the look "is basically fine" and that the real problem is lack of substance ([HN](https://news.ycombinator.com/item?id=47864393)).
- **Specific patterns get defended:**
  - Inter: "Hey inter don't doesn't deserve to be called ai slop. That's a very good typeface." ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od5fr0i/))
  - Bento grids and rounded corners: "leave Bento grids and rounded corners alone, I love Bento grids." ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4oojg/))
  - Thick side borders: liked by InexSquirrel ([HN](https://news.ycombinator.com/item?id=50576012)), and called useful for status by tapvt ([HN](https://news.ycombinator.com/item?id=49867038)).
  - Shimmer loading text: data-ottawa "actually like[s] the shimmer effect" ([HN](https://news.ycombinator.com/item?id=49117099)).
  - Sparkle emoji: throwaway27448 never connected it with AI ([HN](https://news.ycombinator.com/item?id=49117099)).
  - Uniform UX: "I actually like that pages have uniform UX especially on mobile." ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3iug6/))
  - Glass and status boxes: hnlmorg says "pioneered by Apple" and "good UX" ([HN](https://news.ycombinator.com/item?id=49867038)).
- **The purple critique is out of date.** "their idea of what AI design looks like is stuck at what it looked like over a year ago" ([r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/p8ib3vw/)). On the Slopstrap parody, HN commenters said it mocks "a few months ago" slop and that today's look is "small type sizing, serif fonts and beige / tan" ([HN](https://news.ycombinator.com/item?id=50576012)).
- **Fixers recreate the problem.** The top comment (278 pts) on the unslop-ui launch: "The second looks like slop still just from this year not last year". Replies include "Slop v2" and "So it turns 2023 slop into 2026 slop?" ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/)). The Impeccable site itself was called "atrocious... horribly busy and overdone" ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1ws9oix/how_are_people_actually_getting_claude_to_build/pcohrn5/)). Its own Chrome extension reportedly found 117 issues on impeccable.style ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opys2h4/)). Frontend-design-pro's showcase was called slop ([r/ClaudeCode](https://reddit.com/r/ClaudeCode/comments/1p9srut/finally_figured_out_why_claudes_ui_generations/nrgltfr/)).
- **Taste cannot be automated.** "a linter can strip the slop tells but it can't pick a direction... rules constrain, they don't decide." ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtv3ftjbjsz/)). A r/Frontend top answer was, in effect, "learn design" ([r/Frontend](https://reddit.com/r/Frontend/comments/1ssqj99/how_do_you_avoid_the_generic_ai_slop_look_when/ohnu2il/)).
- **Only insiders notice.** "Only "founders" and people in the bubble will recognize an AI website... Real people won't care" ([r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/p8i3bbc/)). The opposing view: "Buyers have pattern recognition now... they just bounce." ([r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19sncmjjjq6ao/)).
- **Labelling bias.** Telling people a site was AI-made makes them see slop: "your title tells: Is it Ai slop... any viewer will now be biased" ([r/claude](https://reddit.com/r/claude/comments/1u3oksv/is_this_design_an_ai_slop/or6rvuy/)). A fully hand-made game UI got asked "does this look AI?", and the answer was "So now the goalpost is 'not looking AI' when it wasn't used at all?" ([r/UI_Design](https://reddit.com/r/UI_Design/comments/1tq8u5r/anyone_feel_like_this_ui_looks_too_ai_generated/ookjtj7/)).

**What this means for the command:** a tell is an *unchosen default*, not a banned colour or font. Every pattern below is legitimate when a brief or a design system chose it. All the serious tools say this (Anthropic skill, unslop-ui, Hallmark waivers, OpenAI's "unless the existing design system requires otherwise").

---

### 2. The catalogue

Column key:

- **Detect**: S = a static script over source/CSS can find it; R = it needs a rendered page (headless browser, computed styles); J = it needs a reviewer's judgement. How a script would find it is in the "How to recognise" column or the "Detect" note.
- **Named by**: the number of independent sources in this research, then the JCarterJohnson Reddit comment count where it has one ("JCJ n=").

#### A. Colour and surface

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| "AI purple" accent | Primary or accent hue in violet/indigo (Tailwind `indigo-500`, `violet-600`, `purple-*`; hue about 250-300 in OKLCH) when the project brand does not define it | It was the model default for so long that it became a meme; "the purple-to-blue gradient is the biggest tell" (373 pts) | A brand hue taken from something real (logo, product). Hallmark: "a colour mixed for the page in OKLCH" | S (token, utility and literal scan; Hallmark gate 74 "stock swatch") | 12; JCJ n=71 comments, 234 posts | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdemjc/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/nozzj2q/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ptoz0v/ai_websites_all_look_the_same/), [r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/), [r/Frontend](https://reddit.com/r/Frontend/comments/1xtkx7a/the_worst_part_about_ai_startup_websites_is_that/), [HN](https://news.ycombinator.com/item?id=47864393), [HN](https://news.ycombinator.com/item?id=50576012), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Anthropic blog](https://www.claude.com/blog/improving-frontend-design-through-skills), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Purple-to-blue / purple-to-pink gradients, gradients everywhere | `linear-gradient` with violet to blue/pink stops; gradients on backgrounds, buttons and borders all at once | Decoration with no meaning; "Most of the gradient stuff fails AA standard" | Flat colour by default, at most one intentional gradient; single-hue ramps only | S (parse gradient stops, compute hue spread; Hallmark 2a/2b) | 14; JCJ n=60 | [r/web_design](https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nyfjs53/), [r/web_design](https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/ka7nryt/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv7y72o/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1u1ju10/ai_codingdesign_tools_are_great_until_screen_5/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=49901973), [godobject "10 tells"](https://godobject.dev/blog/10-tells-of-slop), [Nelson Lee](https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Hallmark gates](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [Impeccable](https://impeccable.style/slop) |
| Gradient headline text | `background-clip: text` + `color: transparent` on h1/h2, often on "Transform your X" | Named alongside the purple gradient as the signature 2024 hero | Solid ink; emphasis by weight, size or a display face | S | 6 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [HN](https://news.ycombinator.com/item?id=50576012), [Impeccable](https://impeccable.style/slop), [unslop-ui](https://github.com/JCarterJohnson/vibecoded-design-tells/blob/main/skill/SKILL.md), [Hallmark 2a](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Dark mode + neon/lime glow | Permanent dark background with coloured zero-offset `box-shadow`/`text-shadow` glows, neon or lime accents | "AI loves this glowing shit. for no reason."; it hurts readability for people with astigmatism | Decide light or dark on purpose; elevation by lightness, neutral offset shadows | S (coloured shadow with 0 offset and large blur on a dark bg) | 9; JCJ n=22 | [r/webdev](https://reddit.com/r/webdev/comments/1qwiqen/is_this_website_horrible_ai_slop/o3p7rcs/), [r/webdev](https://reddit.com/r/webdev/comments/1qwiqen/is_this_website_horrible_ai_slop/o3p75h5/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ew3r/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv6z7wq/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/nozqqdu/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1vnc06s/every_ai_landing_page_looks_the_same_mine_did_too/), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Impeccable](https://impeccable.style/slop), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Glowing orbs, blobs, aurora/mesh, radial halos | Absolutely positioned blurred circles behind the hero; radial "spotlight" behind sections | Decoration that "look[s] busy and say[s] nothing about your product" | Solid or grained surface; real content (a screenshot) in the hero | S/R | 6 (but JCJ found the Reddit signal weak; its verification pass rejected it as a keyword artifact) | [Nelson Lee](https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [OpenAI frontend prompt](https://developers.openai.com/api/docs/guides/frontend-prompt), [Impeccable](https://impeccable.style/slop), [Hallmark 29](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| The "Claude look": cream paper + serif display + terracotta/orange | Background near #F4F1EA (high lightness, warm hue), serif display (Instrument Serif, Fraunces, Playfair), accent near #D97757 | It is Anthropic's own interface style, so it reads as "the Claude look"; "that color palette + font style 100% screams Claude" | Move one axis at a time: accent first, paper second, display last (Hallmark 65) | S (colour and font tokens) + J | 9 | [HN "The AI Aesthetic"](https://news.ycombinator.com/item?id=49117099), [Jim Nielsen](https://blog.jim-nielsen.com/2026/ai-aesthetic/), [HN](https://news.ycombinator.com/item?id=50576012), [HN Tells (jd7h "Claude beige")](https://news.ycombinator.com/item?id=49867038), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/oskxayx/), [r/ClaudeAI (Hallmark test, "Cream background")](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/), [unslop-ui](https://github.com/JCarterJohnson/vibecoded-design-tells/blob/main/skill/SKILL.md) |
| Near-black page with one acid-green or vermilion accent | `#0B0B0B`/`#111` background, single loud accent | One of the clusters Anthropic says its model now falls into | A palette derived from the subject | S + J | 3 | [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [r/ClaudeAI (lime green)](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ew3r/), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/) |
| Untouched framework palette (shadcn slate, Tailwind defaults) | shadcn's default CSS variables unchanged; `slate-*` cards, the stock blue accent | "generic default shadcn themes are just as bad as the purple gradient AI slop" (43 pts) | Theme the kit (tweakcn was suggested); own tokens | S (diff `globals.css` against the shadcn default theme; Tailwind palette utilities) | 8; JCJ n=76 | [r/cursor](https://reddit.com/r/cursor/comments/1p8jyg7/how_do_i_get_my_ui_to_look_this_clean_mine_always/nr5x345/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/oduqy2k/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/nozwud6/), [r/webdev](https://reddit.com/r/webdev/comments/1ne0h3g/almost_80_of_applications_today_look_the_same_is/ndl3je3/), [HN](https://news.ycombinator.com/item?id=47864393), [HN Tells](https://news.ycombinator.com/item?id=49867038), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Glassmorphism by default | `backdrop-filter: blur` on cards and panels everywhere | "glassification"; JCJ ranks it low on Reddit, but HN and the tools flag it | Solid surfaces with a visible border | S | 7; JCJ n=7 | [r/web_design](https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1vnc06s/every_ai_landing_page_looks_the_same_mine_did_too/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=49901973), [godobject](https://godobject.dev/blog/10-tells-of-slop), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Uncodixfy](https://github.com/cyxzdev/Uncodixfy) |
| Low-contrast text (grey on dark, beige on beige, grey on colour) | Body text under 4.5:1 contrast against its computed background | "There's no contrast."; "various shades of dark brown or beige" called an accessibility failure | Fix the pair to WCAG AA | R (computed contrast) | 7 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=47864393), [r/webdev](https://reddit.com/r/webdev/comments/1qwiqen/is_this_website_horrible_ai_slop/o3pau1s/), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [developersdigest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it), [Impeccable](https://impeccable.style/slop), [Hallmark 40/41](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Meaningless rainbow / clashing colours | Many accent hues with no mapping to meaning | "Rainbow Vomit"; "the overuse of colors makes it look garish" | One anchor hue; colour only where it encodes state | R (count distinct saturated hues per viewport) + J | 4 | [godobject](https://godobject.dev/blog/10-tells-of-slop), [HN](https://news.ycombinator.com/item?id=50576012), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/), [Hallmark 23](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |

#### B. Typography

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Inter/Geist (or Roboto, system) as the display face | `font-family` on h1/h2 resolves to Inter, Geist, Roboto, Arial or system-ui | The model's default; "the inter font gradient CTA combo is basically a fingerprint" | A typeface chosen for the subject, with a stated reason. Inter as body text is widely defended | S | 11; JCJ n=13 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4ijlp/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/odcncsm/), [r/ClaudeCode](https://reddit.com/r/ClaudeCode/comments/1p9srut/finally_figured_out_why_claudes_ui_generations/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1sqrpyh/my_finance_app_logic_is_solid_but_it_still_looks/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [godobject](https://godobject.dev/blog/10-tells-of-slop), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Anthropic blog](https://www.claude.com/blog/improving-frontend-design-through-skills), [Impeccable](https://impeccable.style/slop), [Hallmark 1](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Tracked all-caps eyebrow label above every heading | Short text (15px or under) with `text-transform: uppercase` and `letter-spacing` over 0.03em directly before an h2, often in the accent colour | "the tiny all-caps label above every heading is the landing page version of "you're absolutely right""; "overuse of all-caps is one of the biggest tells" | Open the section with the heading itself; sentence-case labels only where they carry information | S (Hallmark 54/67; Impeccable "label above a heading") | 10 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtvmw75ehac/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz90y1/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=50576012), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Impeccable](https://impeccable.style/slop), [Hallmark](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [Uncodixfy](https://github.com/cyxzdev/Uncodixfy) |
| One accented word in a headline | One word in italic serif, a different colour or a highlight inside a roman sans heading | "the last word of the sentence being italicized"; "A single flourish word reads as a template habit" | Set the whole heading one way; use a line break or a second line at a second size | S (an `<em>`/`<span>` with a different font-family or colour inside an h1/h2) | 6 | [HN](https://news.ycombinator.com/item?id=50576012), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [developersdigest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Impeccable "italic serif"](https://impeccable.style/slop), [Hallmark 38](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Monospace as costume | Mono font on labels, meta rows, captions and h1s when the content is not code | "that somewhat hard to read console-ish font Claude seems to love as a default"; "Monospace fonts are my personal one" | Labels in the body face, one step smaller | S (mono font-family on non-code elements) | 7 | [HN](https://news.ycombinator.com/item?id=47864393), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od34isb/), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [godobject](https://godobject.dev/blog/10-tells-of-slop), [Hallmark 64](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Tiny text, crammed | Body under about 14px, micro-labels, dense paragraphs in small boxes | "cram huge amounts of tiny text into every visible inch of the page"; "typically have minuscule font sizes" | Body 16px at 1.5-1.65 leading; fewer words | R | 5 | [HN](https://news.ycombinator.com/item?id=47864393), [HN](https://news.ycombinator.com/item?id=50576012), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [Impeccable](https://impeccable.style/slop), [Hallmark 75](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Flat hierarchy: every heading the same volume | h1-h4 sizes close together; one font size across a screen | "Every heading shouts at the same volume, so your eye has nowhere to land"; "No visual hierarchy. One font size." | A clear type scale with deliberate steps | R (ratio of rendered heading sizes) + J | 6 | [Nelson Lee](https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1vbz5e0/when_your_client_cant_understand_why_you/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/oq15shh/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [Impeccable](https://impeccable.style/slop), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdhuoc/) |
| Letter-spacing/kerning oddities | Negative tracking on display text, wide tracking on body | "don't forget letter kerning" (47 pts) | Default tracking; tighten display type only slightly | S | 3 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3emtk/), [OpenAI frontend prompt ("Letter spacing must be 0")](https://developers.openai.com/api/docs/guides/frontend-prompt), [Impeccable](https://impeccable.style/slop) |

#### C. Layout and components

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| The template page: centred hero + 3 feature cards + pricing + CTA + footer | Centred h1 + subhead + two buttons; a three-column grid of icon-topped cards; 3-tier pricing | "Hero Image, 3 Colums, footer"; "Same 3 features with checkmarks"; "Same pricing: $19 / $49 / $99" | Structure that follows the page's job; left-aligned or asymmetric hero; one real screenshot instead of three cards | S/R (section sequence fingerprint) + J | 12; JCJ n=7 hero, 13 three-column | [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/), [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19smkwwn432w0/), [r/ClaudeCode](https://reddit.com/r/ClaudeCode/comments/1p9srut/finally_figured_out_why_claudes_ui_generations/), [r/web_design](https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz4jtb/), [HN](https://news.ycombinator.com/item?id=49901973), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/), [unslop-ui](https://github.com/JCarterJohnson/vibecoded-design-tells/blob/main/skill/SKILL.md), [Hallmark 8](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| A box around everything; cards inside cards | Every section and item wrapped in a bordered, rounded, shadowed container; nested containers | "the urge to put a box around everything"; "cards and pills everywhere, cards inside cards" | One containment layer; cards only for repeated items, modals and framed tools | S (nested elements that each have border/background + radius) | 9 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3irw0/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4def5/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/osiyrs3/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=47864393), [Anthropic skill ("SaaS-card kit")](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt), [Impeccable](https://impeccable.style/slop), [Hallmark 4](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Thick coloured left (or top) border on rounded cards | `border-left: 3-4px solid <accent>` on an element with `border-radius` | "3 cards with thick border on left only" (67 pts); "an exact fingerprint of Anthropic models"; "almost as reliable a sign of AI-generated design as em-dashes" | Remove it; use spacing, a background tint or a label. Keep it only when it encodes real state | S (Impeccable "side-tab"; Hallmark 3) | 10 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ew3r/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3zwrh/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od53wkh/), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [HN](https://news.ycombinator.com/item?id=50576012), [HN](https://news.ycombinator.com/item?id=47864393), [HN Tells](https://news.ycombinator.com/item?id=49867038), [godobject "Finger Nail Cards"](https://godobject.dev/blog/10-tells-of-slop), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Impeccable](https://impeccable.style/slop) |
| One big radius on everything; pill buttons | Same large `border-radius` on cards, buttons, inputs and images; `rounded-full` buttons | "rounded corners on everything"; "the unnecessarily aggressive border radius" | A small radius scale tied to hierarchy (Uncodixfy suggests 8-12px max on cards; OpenAI 8px unless the design system says otherwise) | S | 9; JCJ n=23 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ptoz0v/ai_websites_all_look_the_same/nvikdg1/), [r/Frontend](https://reddit.com/r/Frontend/comments/1xtkx7a/the_worst_part_about_ai_startup_websites_is_that/), [HN](https://news.ycombinator.com/item?id=50576012), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Uncodixfy](https://github.com/cyxzdev/Uncodixfy), [OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt) |
| Icon in a tinted rounded tile above each heading | A square with a translucent accent background holding an icon, stacked above a card title | "an icon surrounded in a half transparent box with the same coloe as the icon" | Inline icons, or none, with a more specific sentence | S (Impeccable "icon-tile-stack"; Hallmark 3) | 5 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3vw9d/), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [developersdigest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it), [Impeccable](https://impeccable.style/slop), [Hallmark 3](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| 01 / 02 / 03 numbering on non-sequential content | Ordinal markers on sections or features that are not a sequence | "The 01, 02, 03 numbering is a pretty dead give away this was generated by Claude Design"; "section numbering gives it away now" | Number only real sequences (steps, timeline) | S (finds ordinal markers) + J (is it a sequence?) | 7 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/oq2v0nz/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=47864393), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Impeccable](https://impeccable.style/slop), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/) |
| Stat banner / hero metric | A row of big numbers with small labels ("10k+ users", "99.9%"), often invented | "a big number with a small label, supporting stats, and a gradient accent is the default treatment" | Only stats you can source, placed in context | S (repeated big-number + small-label blocks) + J (is it real?) | 4 | [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Impeccable](https://impeccable.style/slop), [falia (Codex: stat cards)](https://falia.co/en/insights/web-design/spot-ai-built-website/) |
| Bento grid | Asymmetric tile grid of feature cards | Named as a tell (373-pt comment) but defended; JCJ found it near the bottom on Reddit | Use only when content has genuinely different weights | S + J | 4, contested; JCJ n=4 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [r/ClaudeAI (defence)](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4oojg/), [HN](https://news.ycombinator.com/item?id=50576012), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Same rhythm in every section | Equal gaps, identical section shells, the same separator everywhere | "Every major section looks the same"; "too evenly spaced, and every section has the s[ame]..." | Vary density and section shape by content | R (gap variance) + J | 5 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz4jtb/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/), [Impeccable "monotonous spacing"](https://impeccable.style/slop), [Hallmark 9/59](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Spacing with no system; misalignment | Arbitrary px values (13, 22, 40); icons off the text baseline; uneven padding | "13px here, 22px there, 40px somewhere else"; "icon is vertically misaligned with the text"; "fonts, spacings, alignments" | One spacing scale, as tokens | S (raw lengths not on the scale) + R (alignment) | 8 | [Nelson Lee](https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site), [HN Tells](https://news.ycombinator.com/item?id=49867038), [godobject "Misaligned Stuff"](https://godobject.dev/blog/10-tells-of-slop), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdhuoc/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od7jshb/), [HN](https://news.ycombinator.com/item?id=50576012), [Hallmark 24](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [r/UI_Design](https://reddit.com/r/UI_Design/comments/1tq8u5r/anyone_feel_like_this_ui_looks_too_ai_generated/oofwluv/) |
| Narrow column / endless whitespace | Everything centred in about 700px; large empty bands | "Max-width of 700px on everything for some fuckin reason"; "way too much whitespace" | Measure prose at 45-75ch, but let layouts use the container | R | 4; JCJ n=7 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4uzxl/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [Hallmark 77/79](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Too much text; everything shouting | Header + subheader + bullets + badges on every block; many CTAs in the hero | "SO MUCH TEXT."; "All elements yell at the same time"; "5 buttons, 10 icons" | Headline, one sentence, actions; one memorable element per page | R (word count per viewport; Hallmark 58: about 80 words per 900px window) + J | 8 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=50576012), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/oq15shh/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1ws9oix/how_are_people_actually_getting_claude_to_build/pcohrn5/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ptoz0v/ai_websites_all_look_the_same/nvik3ed/), [r/Frontend](https://reddit.com/r/Frontend/comments/1sk542y/my_site_is_vibecoded_what_would_make_it_look_less/ogikw33/), [HN AI Aesthetic ("busy-ness is a hallmark")](https://news.ycombinator.com/item?id=49117099), [Hallmark 58](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| No images: cards with icons only | Sections built entirely from icon cards; no photography or product screenshots | "The biggest tell is the lack of images... Most good websites are like 50% images"; "So many slop sites have 0 images" | Real product screenshots, real photos, or type at scale | R (image area share) | 5 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4def5/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od6ewn7/), [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19smkwwn432w0/), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Hallmark 84](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Hero/dashboard chrome in an app | Marketing hero blocks and decorative copy inside dashboards; floating sidebar shells | Uncodixfy lists "hero sections in dashboards" first; OpenAI: "You should not make a landing page unless absolutely required" | Plain app shell: fixed sidebar, simple headers | S/J | 3 | [Uncodixfy](https://github.com/cyxzdev/Uncodixfy), [OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt), [HN Tells ("pointless dashboards")](https://news.ycombinator.com/item?id=49867038) |

#### D. Decorative chrome, icons and punctuation

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Emoji as icons (🚀 ✨ 🧠 in nav, features and buttons) | Emoji code points in headings, nav items, buttons and feature bullets | "Emojis as icons. If I see them, I instantly doubt the creators ability"; they render differently per OS | One icon library with a consistent stroke, or plain text | S (Unicode emoji ranges in JSX/HTML) | 12; JCJ n=16 comments, 879 posts | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3z5jw/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od5a83n/), [r/webdev](https://reddit.com/r/webdev/comments/1p9ysk0/can_we_ban_ai_slop_generated_websites_and_apps/nrgikmz/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [HN](https://news.ycombinator.com/item?id=47864393), [godobject "Emoji Slop"](https://godobject.dev/blog/10-tells-of-slop), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Hallmark 30a](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [unslop-ui](https://github.com/JCarterJohnson/vibecoded-design-tells/blob/main/skill/SKILL.md), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| ✨ sparkle on AI features | Sparkle icon next to buttons or search | "the telltale sign of 'buttons not to click'" (contested) | Name the action | S | 2 | [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [Jim Nielsen](https://blog.jim-nielsen.com/2026/ai-aesthetic/) |
| Pulsing/blinking status dot | A small animated dot ("live", "online", "Made with ● by") with no state behind it | "Pulsing status badges... even when the status is always true"; "this green dots that seems like live indicator" | Only show status that changes, wired to real state | S (keyframe opacity/scale on a small circle) + J | 6 | [godobject](https://godobject.dev/blog/10-tells-of-slop), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ptoz0v/ai_websites_all_look_the_same/nvikdg1/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=50576012), [Impeccable](https://impeccable.style/slop), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73) |
| Badge/pill above the H1 ("New", "Now in beta") | Small rounded chip directly above the hero headline | Formulaic opener | Remove it, or move the proof point | S | 4 | [Krebs](https://www.adriankrebs.ch/blog/design-slop/), [developersdigest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it), [Impeccable "hero-eyebrow-chip"](https://impeccable.style/slop), [Hallmark 54/66](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Template punctuation: `//` separators, `A · B · C`, `Learn more →`, `WORD — fragment` | Two or more middle dots in a meta string; arrows glued to link text; `//` between nav or header items | "Center-dots as dividers are the new tell tale."; "AI loves to separate headers with //" | Line breaks, columns, hairlines; a verb as the label | S (regex over rendered text) | 6 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [godobject](https://godobject.dev/blog/10-tells-of-slop), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Hallmark 63](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/) |
| Tags/badges/status chips everywhere | Many small pills with vague labels | "useless badges with nonsensical labels"; "coloured left borders, tags and superfluous numbers all over the place" | Badges only for real metadata | S (count) + J | 4 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=47864393), [r/vibecoding ("The tag system version thing looks very AI")](https://reddit.com/r/vibecoding/comments/1ptoz0v/ai_websites_all_look_the_same/nvik3ed/), [Impeccable "Status-chip soup"](https://impeccable.style) |
| Logo marquee / "trusted by" wall | Auto-scrolling logo row, often of non-customers | "the logo river"; fake proof | Real customers only, static, or nothing | S (marquee animation) + J (real?) | 3 | [HN](https://news.ycombinator.com/item?id=50576012), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Hallmark 46a/54](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Hand-drawn product mock / fake browser chrome / rough SVG illustrations | Divs styled as a fake app UI, traffic-light browser bars, clumsy inline SVG art | "drawing weird inline SVGs"; "Rough SVG illustrations" | A real screenshot of the product; an icon library | S/R | 4 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xm5lz3/what_toolsplugins_do_you_use_with_claude_code_to/19s1lql4drokg/), [Impeccable](https://impeccable.style/slop), [Hallmark 47/80/84](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt) |

#### E. Motion

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Fade-and-slide-up on every section | IntersectionObserver or Framer `whileInView` reveal on every block | "content that fades in as you scroll down a page"; Anthropic: it is "the generic default and read[s] as AI-generated" | One orchestrated moment; motion that answers the user's action | S (count reveal wrappers) | 8; JCJ n=34 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=49901973), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [falia](https://falia.co/en/insights/web-design/spot-ai-built-website/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od49myt/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdh07p/), [Hallmark 62 (blank page when JS fails)](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells) |
| Hover lift/shadow on every card, including non-clickable ones | The same `hover:translate-y`/`hover:shadow` on all cards | "the shadow on hover transition on everything"; "unnecessary hover animations" | Hover only on interactive elements, one signal each | S | 5 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od7swsc/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od49myt/), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Hallmark 11](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Scroll hijacking, carousels | Scroll-locked transitions; auto-rotating content with no pause | "Scroll hijacking is website terrorism." | Native scroll; pause controls | S/R | 3 | [r/web_design](https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/kaap819/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [Hallmark 18](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Shimmer text, bounce easing, page-load body animation | Shimmering "thinking" text for any async task; overshoot easing; content animating in on load | "<marquee> for AI"; "The way the body content animates at page load is pretty annoying" | Specific progress text; ease-out; instant content | S | 4, contested | [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [HN](https://news.ycombinator.com/item?id=49901973), [Jim Nielsen](https://blog.jim-nielsen.com/2026/ai-aesthetic/), [Impeccable](https://impeccable.style/slop) |
| Missing reduced-motion fallback | Keyframes/transforms with no `prefers-reduced-motion` | Quality floor all the tools enforce | Add it | S | 3 | [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), [Hallmark 27](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [Impeccable](https://impeccable.style/slop) |

#### F. Copy

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Generic hero lines ("Build / Manage / Grow your X faster", "Transform your X", "For teams of all sizes", "AI powered") | Hero verbs from a short stock list; no product noun | "Change the logo and the color, you can't tell whose site it is."; "the generic copy has basically become an instant red flag" | Write the hero in the customer's words (pull lines from support emails); name what the product does | S (phrase list) + J | 8 | [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/), [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19smjrsjj15k4/), [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19sm0dtwhtrhc/), [r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/), [r/ClaudeAI ("Well-written copy that has nothing to do with the content")](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ngh6/), [r/ClaudeAI (Hallmark test: headline did not say "coffee")](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtwszk2cw74/), [godobject](https://godobject.dev/blog/10-tells-of-slop) |
| Buzzwords ("Elevate", "Seamless", "Unlock", "Supercharge", "leverage scalable ecosystems") | Word list | "Corporate Buzzword Soup"; "Generic Taglines And Unnecessary Hype" | Plain, specific verbs | S (Hallmark 19 word list) | 5 | [godobject](https://godobject.dev/blog/10-tells-of-slop), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opyxum8/), [Impeccable "Generic marketing claims"](https://impeccable.style/slop), [Hallmark 19](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73) |
| Rebuttal cadence ("No X. No Y. Just Z.", "Not X, it's Y", "FEATURES, IN PLAIN ENGLISH.") | Regex over sentence pairs | "The copy of "No X. No Y. Just Z" Makes me sick"; "is ai from a thousand kilometers" | State the claim once, plainly | S (regex) | 7 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od5nauh/), [r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/p8fmht3/), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/olgzb3j/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz90y1/), [HN Tells ("No this. No that.")](https://news.ycombinator.com/item?id=49867038), [Impeccable "Forced contrast"](https://impeccable.style/slop), [Hallmark 19](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Manifesto filler ("Every line of code we write serves a purpose. Every feature earns its place.") | Triads, "Every X... Every Y..." parallelism, "it's about doing what matters" | "This part was slightly a cringe"; "Everything comes in punchy threes" | Cut it, or replace with a fact | S (heuristic) + J | 3 | [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv6udj4/), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [HN Tells ("SEVEN slogans")](https://news.ycombinator.com/item?id=49867038) |
| Em dashes in UI copy | `—` density in visible strings | "the em dash is the biggest tell"; "Em-dash overuse" (contested: "I love em dashes") | Rewrite the sentence | S | 7 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ztjo/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opyxum8/), [HN](https://news.ycombinator.com/item?id=49901973), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [HN](https://news.ycombinator.com/item?id=50576012), [Impeccable](https://impeccable.style/slop), [Hallmark 19](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Chat context or implementation details leaking into the UI | Copy that repeats the prompt ("3 campuses, one app"), describes how the site was built, says "Your files never leave your browser", or explains UI features in-app | "Redundant Text Due To Chat Context"; "spill the beans (=implementation details) into frontend code" | Describe what the user can do, in their words | J (S can flag phrases like "built with", "powered by", "never leave") | 5 | [godobject](https://godobject.dev/blog/10-tells-of-slop), [HN Tells](https://news.ycombinator.com/item?id=49867038), [HN](https://news.ycombinator.com/item?id=49901973), [OpenAI ("You do not use visible, in-app text to describe the application's features")](https://developers.openai.com/api/docs/guides/frontend-prompt), [Anthropic skill ("A user manages notifications, not webhook config")](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Redundant headings and filler descriptions | Eyebrow + h1 + subtitle saying the same thing; a description paragraph under every heading; "Choose a ..." narration labels | "Repeated header, eyebrow, h1, and footer saying the same thing"; "an unnecessary header and a filler paragraph added to every output" | Each element does one job | J (S can flag high text overlap between adjacent elements) | 4 | [HN Tells](https://news.ycombinator.com/item?id=49867038), [Impeccable "Same text repeated"](https://impeccable.style/slop), [Hallmark 69 "the echo"](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [Anthropic skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Second-person cute labels ("Needs You") | Chatty status or section labels | Named as a newer tell | Plain labels ("Requires attention") | J | 1 | [HN Tells (arshxyz)](https://news.ycombinator.com/item?id=49867038) |

#### G. Honesty and placeholder content

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Fake proof: invented stats, testimonials, logos of non-customers, "Jane Doe" | Testimonial blocks with stock names; numbers with no source; logo walls | Breaks trust; one of the nine Slopstrap tells | Real quotes and numbers, or an empty slot the owner fills | S (placeholder names, Acme) + J | 4 | [Slopstrap tells](https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73), [Hallmark 19/46a](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md), [r/SaaS (legal footer generated)](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/p8frwc4/), [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/) |
| Placeholder image boxes, empty FAQ answers | Dashed "photo goes here" boxes; gradient blocks standing in for images; empty answers | "a dashed "photo goes here" box where an image should be"; "Empty FAQ answers" | Real assets, or a clearly marked TODO for the owner | S/R | 3 | [r/ClaudeAI (Hallmark test)](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/), [HN Tells](https://news.ycombinator.com/item?id=49867038), [Hallmark 68/81](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Fake send / controls that do nothing | Forms that show "Thanks!" with no request; buttons with no handler; dead lead magnets | "the lead magnet doesn't work"; "one of the drawers is glued in because it doesn't exist internally" | Wire it, or remove the success state | S (submit handlers that never fetch) + R | 3 | [r/web_design](https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nyg2xcd/), [r/web_design](https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nygqa8x/), [Hallmark 70](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |

#### H. UX and behaviour (apps more than landing pages)

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| Design drift: screens that look like different products; the repo's design system ignored | New components duplicating existing ones; colours and fonts outside tokens; "screen 5 looks nothing like screen 1" | "AI... often ignores your design system"; "turning a design system into 40 slightly different versions of the same component" | Decide tokens once, tell the agent to use only those; reuse components | S (literals outside tokens; near-duplicate components) | 7 | [r/UXDesign](https://reddit.com/r/UXDesign/comments/1s7e3d1/the_design_drift_created_by_vibe_coding_is_insane/), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1s7e3d1/the_design_drift_created_by_vibe_coding_is_insane/od8tyyi/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1u1ju10/ai_codingdesign_tools_are_great_until_screen_5/), [r/Frontend](https://reddit.com/r/Frontend/comments/1vwclwd/ai_can_generate_a_component_it_cant_feel_when_a/), [r/ClaudeAI 37 pts](https://reddit.com/r/ClaudeAI/comments/1xm5lz3/what_toolsplugins_do_you_use_with_claude_code_to/19s1jgwuz8gtd/), [Impeccable "outside DESIGN.md" rules](https://impeccable.style/slop), [Hallmark 48](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| No information architecture; everything on one screen | Many equal-weight actions on one screen; every metric shown at once | "all the app's functionality spread across EIGHTEEN gradient-filled buttons"; "you have everything on one screen... AI puts all on-top of each other"; "There is no information architecture" | One primary task per screen; progressive disclosure | J | 4 | [r/UXDesign](https://reddit.com/r/UXDesign/comments/1vbz5e0/when_your_client_cant_understand_why_you/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdfkf9/), [r/UXDesign](https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/), [r/vibecoding ("looks like a quilt")](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdhd6a/) |
| Raw errors on screen, or none at all | Exception text, status codes or stack traces rendered in the UI; silent failures | "AI... default[s] either to a) not displaying errors at all, or b) displaying the raw error message body" (contested: raw errors help bug reports) | Tiered errors: fixable (what to do), not fixable (what to try, a reference id), invisible; detail goes to logs | S (rendering `error.message`/`err.toString()` in JSX) + J | 3 | [r/vibecoding](https://reddit.com/r/vibecoding/comments/1wn97pn/psa_dont_want_your_app_to_look_like_ai_slop_stop/), [r/vibecoding (defence)](https://reddit.com/r/vibecoding/comments/1wn97pn/psa_dont_want_your_app_to_look_like_ai_slop_stop/pbd0p6j/), [Anthropic skill ("Errors don't apologize")](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Broken basics: dead links, page that will not scroll, wrong cursor, tap targets | Links to 404s, scroll lock after opening nav, touch cursor on desktop, small tap targets | "Many AI sites I've seen have broken links"; "Can't even scroll the home page without it crashing"; "the tap targets were just slightly infuriating" | Test on devices; a link checker | R | 6 | [r/web_design](https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nyg2xcd/), [r/vibecoding (scroll crash)](https://reddit.com/r/vibecoding/comments/1tk55n4/your_vibecoded_app_looks_aimade_because_the_model/on69a1h/), [r/vibecoding (touch cursor on desktop)](https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv6nocr/), [r/Frontend](https://reddit.com/r/Frontend/comments/1vwclwd/ai_can_generate_a_component_it_cant_feel_when_a/p5fyx84/), [r/web_design (scroll lock after nav)](https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/ka9id8q/), [Hallmark 34/39](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Missing empty, loading and error states | Lists with no empty state; one spinner for everything; forms that clear on error | Practitioner blogs: these are the screens AI skips because it builds happy paths | Design every state; keep user input on error | S (components fetching data with no empty/error branch) + J | 2 (blogs, not threads) | [digitraly](https://www.digitraly.com/vibe-coded-app-ux-why-users-can-tell-and-what-to-fix/), [Anthropic skill ("An empty screen is an invitation to act")](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Toast/modal overuse; celebratory toasts | Toast on every action; modals for simple choices | "'dont use toasts' and 'avoid modals when possible'" given as anti-slop rules | Silent success where the effect is visible | S (count) + J | 2 | [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1w90wze/is_there_any_way_to_stop_ai_coding_agents_from/p86vxyx/), [Hallmark 16](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md) |
| Whack-a-mole controls | Toggling repaints or moves the layout so the control jumps | Named in Jim Nielsen's essay | Stable control positions | R | 2 | [Jim Nielsen](https://blog.jim-nielsen.com/2026/ai-aesthetic/), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099) |

#### I. The whole-page judgement (no single feature)

| Pattern | How to recognise | Why it reads as AI-made | Better alternative | Detect | Named by | Sources |
|---|---|---|---|---|---|---|
| "Looks like every other site": the median look | Several of the above at once; the page could belong to any product | The single largest complaint (JCJ: 13.1% of posts, 91% negative); "If I removed your logo, would I know it's yours?" | A specific direction grounded in the subject, a reference site and the product's real content | R (pattern-count tiering as Krebs did: 4+ patterns = high) + J | 20+ | [JCJ](https://github.com/JCarterJohnson/vibecoded-design-tells), [r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/), [Krebs](https://www.adriankrebs.ch/blog/design-slop/), and most threads above |
| "A quilt of neat things with no concept" | Many effects competing: gradient + shadow + animation + glow on one page | "too many effects competing for attention"; "A lot of neat things cobbled together and the result looks like a quilt" | Spend boldness in one place; remove one accessory | J | 4 | [r/Frontend](https://reddit.com/r/Frontend/comments/1sk542y/my_site_is_vibecoded_what_would_make_it_look_less/ogikw33/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdhd6a/), [HN AI Aesthetic](https://news.ycombinator.com/item?id=49117099), [Anthropic skill ("Chanel's advice")](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) |
| Looks impressive in colour, collapses in greyscale | Hierarchy carried only by colour | "When you strip these prompted mocks back to core heuristics—or even just look at them in grayscale—the whole thing collapses." | Hierarchy by size, weight, position and space | R (render in greyscale, check contrast ranking) + J | 1 | [r/UXDesign](https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/) |
| Visual style mismatched to the audience | Dark, glowing "technical" style on a product for non-technical users | "I'd built a site that looked like it required prior knowledge"; the fix was "familiar rather than impressive" | Style follows audience and job | J | 2 | [r/vibecoding](https://reddit.com/r/vibecoding/comments/1vnc06s/every_ai_landing_page_looks_the_same_mine_did_too/), [r/vibecoding](https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv71b5o/) |

#### How the evidence weighs up

- **Strongest** (many independent sources plus data or tool support): purple/indigo, purple-blue gradients, emoji icons, the hero + three cards template, box-everything cards, left-border stripe cards, tracked all-caps eyebrows, Inter as the display face, untouched shadcn, scroll fade-ins, generic hero copy, the cream/serif/terracotta Claude look.
- **Medium:** glow/neon on dark, rounded-everything and pills, 01/02 numbering, middle-dot and `//` punctuation, pulsing dots, monospace costume, stat banners, no images, too much text, design drift.
- **Weak or contested:** bento grids, glassmorphism, aurora/mesh blobs (JCJ's verification rejected the mesh/blob signal), sparkle emoji, shimmer text, em dashes, raw errors (some developers defend them).

---

### 3. What people say, in their words

Reddit quotes are verbatim from the Arctic Shift archive. HN quotes are fragments extracted from the thread page. Points are given where known.

- "the purple-to-blue gradient is the biggest tell lol. also bento grid layouts, rounded corners on everything, hero section with gradient text that says 'transform your X', and way too much whitespace." (373 pts): https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/
- "the moment you say 'modern landing page' it defaults to the same aesthetic as every other vibe-coded site" (same comment): https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od38vuq/
- "Black background, neon and lime green text. Inter font. 3 cards with thick border on left only." (67 pts): https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3ew3r/
- "Purple gradients and the urge to put a box around everything.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3irw0/
- "Emojis as icons. If I see them, I instantly doubt the creators ability to even vibe-code properly. And it gives me a hint of the "quality" of the backend.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3z5jw/
- "The biggest tell is the lack of images. Every section is just a bunch of cards with icons, NO images at all.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4def5/
- "The copy of "No X. No Y. Just Z"  Makes me sick": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od5nauh/
- "Max-width of 700px on everything for some fuckin reason": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4uzxl/
- "When the website has an icon surrounded in a half transparent box with the same coloe as the icon.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od3vw9d/
- "dont forget the shadow on hover transition on everything": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od7swsc/
- "Every Claude/Cursor project defaults to the same shadcn components with identical slate gray cards, that specific blue accent, and the same padding rhythm.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/oduqy2k/
- "When I see base Inter as a display font, I know by now that I'm usually safe to just leave a page": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/odcncsm/
- "Hey inter don't doesn't deserve to be called ai slop. That's a very good typeface.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od5fr0i/
- "Agree about purple to blue  But leave Bento grids and rounded corners alone, I love Bento grids.": https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/od4oojg/
- "the tiny all-caps label above every heading is the landing page version of "you're absolutely right"": https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtvmw75ehac/
- "a linter can strip the slop tells but it can't pick a direction - there's no design system underneath, so once the cliches are gone the model free-styles. rules constrain, they don't decide.": https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtv3ftjbjsz/
- "The second looks like slop still just from this year not last year" (278 pts, on the unslop-ui before/after): https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/osirsi5/
- "So it turns 2023 slop into 2026 slop?": https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/osj3osi/
- "Yeah that color palette + font style 100% screams Claude from the other side of the continent.": https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/oskxayx/
- "The 01, 02, 03 numbering is a pretty dead give away this was generated by Claude Design. Also the "toy paper" theme.": https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/oq2v0nz/
- "this is exactly the sort of line I try to avoid that screams AI: "FEATURES, IN PLAIN ENGLISH."": https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz90y1/
- "most AI-looking sites are too centered, too evenly spaced, and every section has the s[ame]...": https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opz4jtb/
- "The "AI look" mostly comes from Claude inventing a new design every time. What helps most is deciding it once... put your tokens in a file (2-3 colors, one font, a spacing scale, one radius), and tell it in `CLAUDE.md` to only use those, no new colors or gradients." (37 pts): https://reddit.com/r/ClaudeAI/comments/1xm5lz3/what_toolsplugins_do_you_use_with_claude_code_to/19s1jgwuz8gtd/
- "You find a website you want to replicate from dribble or awwwards.com and then ask Claude to replicate X website's layout with your brand colors and identity." (120 pts): https://reddit.com/r/ClaudeAI/comments/1ws9oix/how_are_people_actually_getting_claude_to_build/pcjis33/
- "IMO the Impeccable website itself is atrocious... horribly busy and overdone... 5 buttons, 10 icons": https://reddit.com/r/ClaudeAI/comments/1ws9oix/how_are_people_actually_getting_claude_to_build/pcohrn5/
- "use tweakcn. generic default shadcn themes are just as bad as the purple gradient AI slop" (43 pts): https://reddit.com/r/cursor/comments/1p8jyg7/how_do_i_get_my_ui_to_look_this_clean_mine_always/nr5x345/
- "Were you not here for the Web 2.0 phase where literally everything was the unthemed Bootstrap framework?" (118 pts): https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/noztjte/
- "If you tell it how to make the UI instead of "create the UI" it won't be generic" (72 pts): https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/noztva9/
- "That Black/purple theme 80% of the time for me.": https://reddit.com/r/vibecoding/comments/1oxutwy/lets_be_honest_ai_ui_all_looks_the_same/nozzj2q/
- "Very obviously just prompted to "make it look good and modern" without any kind of overarching design language or concept. A lot of neat things cobbled together and the result looks like a quilt.": https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdhd6a/
- "you have everything on one screen... I think it is usualy that AI puts all on-top of each other.": https://reddit.com/r/vibecoding/comments/1s37qlp/what_are_the_signs_of_an_ai_slop_ui/ocdfkf9/
- "As someone who has used AI to build a heckton of landing pages, I can tell it is AI. The first give away was the very heavy glow": https://reddit.com/r/vibecoding/comments/1ps3rr4/just_launched_my_business_site_can_people_tell_if/nv6z7wq/
- "It went from dark mode slop to light mode slop. Multi colored hook, hook being some vague statement, gradient buttons, the layout, off white background, the font.": https://reddit.com/r/vibecoding/comments/1vnc06s/every_ai_landing_page_looks_the_same_mine_did_too/p3gap3s/
- "Same hero: Build / Manage / Grow your [thing] faster Same 3 features with checkmarks Same pricing: $19 / $49 / $99 Same For teams of all sizes  Change the logo and the color, you can't tell whose site it is.": https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/
- "write the hero In your customers' words, not yours... Swap the 3 checkmark cards for one real screenshot of the product doing the job... Specific beats pretty.": https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/19smkwwn432w0/
- "AI loves this glowing shit. for no reason. but at least there is no purple gradients.": https://reddit.com/r/webdev/comments/1qwiqen/is_this_website_horrible_ai_slop/o3p7rcs/
- "Most of the gradient stuff fails AA standard": https://reddit.com/r/web_design/comments/180pvpg/all_startup_landing_pages_look_the_same_these_days/ka7nryt/
- "Many AI sites I've seen have broken links.": https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nyg2xcd/
- "imagine buying an ikea furinture and one of the drawers is glued in because it doesn't exist internally  that's how vibe coded websites/apps feel": https://reddit.com/r/web_design/comments/1q73fox/everything_already_looks_and_feels_like_its_ai/nygqa8x/
- "all the app's functionality spread across EIGHTEEN gradient-filled buttons with goofy cartoon images on them on one screen. No visual hierarchy. One font size. No branding.": https://reddit.com/r/UXDesign/comments/1vbz5e0/when_your_client_cant_understand_why_you/
- "AI fills in gaps it has no business filling in, confidently and with 0 hesitation... It just ships and often ignores your design system": https://reddit.com/r/UXDesign/comments/1s7e3d1/the_design_drift_created_by_vibe_coding_is_insane/
- "When you strip these prompted mocks back to core heuristics—or even just look at them in grayscale—the whole thing collapses. There is no information architecture.": https://reddit.com/r/UXDesign/comments/1tbbpta/weve_officially_entered_the_vibe_coding_era_of/
- "The biggest tell of vibe-coded sites is too many effects competing for attention — gradients, shadows, animations, glows all on the same page.": https://reddit.com/r/Frontend/comments/1sk542y/my_site_is_vibecoded_what_would_make_it_look_less/ogikw33/
- "slowly turning a design system into 40 slightly different versions of the same component": https://reddit.com/r/Frontend/comments/1vwclwd/ai_can_generate_a_component_it_cant_feel_when_a/
- "displaying the raw error message body in its entirety or truncated oddly right in the user's face": https://reddit.com/r/vibecoding/comments/1wn97pn/psa_dont_want_your_app_to_look_like_ai_slop_stop/
- HN, vmg12: "overuse of all-caps is one of the biggest tells". atoav: "Center-dots as dividers are the new tell tale." dawnerd: "section numbering gives it away now". nullbio: "There's no contrast.": https://news.ycombinator.com/item?id=49867038
- HN, not_a_bot_4sho, on the rounded left border: "an exact fingerprint of Anthropic models". jjcm quoting the essay: "beige/cream colors, orange accents, and serif typefaces". lynndotpy: "Everything comes in punchy threes.": https://news.ycombinator.com/item?id=49117099
- HN, trueno: "thick left border is on the 72 apps my coworker has made." ChrisArchitect on the current look: "small type sizing, serif fonts and beige / tan color schemes": https://news.ycombinator.com/item?id=50576012
- HN, toraway: "that somewhat hard to read console-ish font Claude seems to love as a default" and "cram huge amounts of tiny text into every visible inch of the page." joegibbs: AI "seems to want to add coloured left borders, tags and superfluous numbers all over the place.": https://news.ycombinator.com/item?id=47864393
- Adrian Krebs on his scan of Show HN pages: "Is this bad? Not really, just uninspired.": https://www.adriankrebs.ch/blog/design-slop/

---

### 4. Existing tools, prompts and skills

| Tool | URL | What it does | What to learn from it |
|---|---|---|---|
| Anthropic frontend-design skill | https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md (also shipped as a Claude Code plugin, see https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design) | Build-time guidance. Ground the design in the subject; plan tokens (4-6 hex colours, type roles, layout with ASCII wireframes); review the plan against "what I'd produce for any similar page" before coding; screenshot and self-critique. It names five current AI clusters with exact values (cream #F4F1EA + serif + #D97757; near-black + acid accent; broadsheet hairlines; SaaS-card kit; template chrome: eyebrows, middle dots, `WORD — fragment`, mono labels, `→`). | It is the most current first-party list of Claude's own defaults, and the cluster list fits a detector directly. Its rule "the brief's own words always win, including when it asks for one of these looks" is the right override model. Reddit users note the older version itself produced the cream/serif look ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/)). |
| Anthropic blog: improving frontend design through skills | https://www.claude.com/blog/improving-frontend-design-through-skills | Explains "distributional convergence" and the first anti-default list (Inter, purple on white, predictable layouts) | The cause is defaults, not inability, so the fix is specification and choice, not a new house style |
| Hallmark (Together AI) | https://github.com/Nutlope/hallmark, gates at https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/gates.md | Large anti-slop skill (about 60k stars) with a numbered gate list. Each gate has a tier: Floor = never waivable; Reflex = waivable with written evidence; Finish; Ledger. Each also has a class saying who checks it: M = static linter, R = rendered, J = judged. `scripts/sloplint.mjs` runs the static and render checks; `audit` reports without editing. A redesign mode keeps content, wiring, files and brand, and offers polish / restyle / full depths. A `.hallmark/log.json` ledger stops repeating the same structure across builds. | The best model for our check taxonomy. Lessons: (1) split script-checkable from judged gates explicitly; (2) allow a waiver only with evidence and a page-specific reason, and treat three waivers of the same gate as a house style that belongs in design.md; (3) "a framework default or a look the gates name... is not a brand"; (4) record what the page has before changing it (links, ids, test hooks) and never break them; (5) depth levels the user picks. Cost warning from a user test: about 5x time and tokens, and it chose a blackletter font for coffee ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/)). Some of its rules are its own house style (for example "never use a dash in copy"), which users noticed. |
| Impeccable | https://impeccable.style, rule catalogue https://impeccable.style/slop, repo https://github.com/pbakaus/impeccable | Design vocabulary skill (critique, audit, polish, bolder, quieter, ...) plus a deterministic detector with about 62 rules (no LLM): a hook during agent edits, a CLI with exit codes for CI, and a Chrome extension. Has "outside DESIGN.md" rules for font, colour, radius and font size. Ignore attribute: `data-impeccable-ignore="<rule>"`. | Its rule list is the most complete public one; it separates "AI slop" from plain "quality" rules, and its "outside DESIGN.md" family is how to respect a repo's system. Users recommend it most often, but its own site is criticised as busy, which shows that passing a linter is not taste. |
| unslop-ui (JCarterJohnson) | https://github.com/JCarterJohnson/vibecoded-design-tells (skill in `skill/`, scanner `skill/scripts/devibe_scan.py`, data in `unslop-ai-ui/`) | Weights tells by Reddit frequency; a build mode demands a reference, colour, type and layout intent; an audit mode scans the code and gives a "vibe score"; the exit code is the count of high-severity findings; `unslop-ignore` honours deliberate choices. Explicitly flags the newer cream + serif + sage default. | Data-weighting means effort goes where complaints are. It does not prescribe a look. But its launch shows the risk: its "after" example was called "2026 slop" in the top comment ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1u9sgj3/unslopui_a_claude_skill_that_flags_and_removes/osirsi5/)). Never ship before/after showcases built from our own taste. |
| Uncodixfy | https://github.com/cyxzdev/Uncodixfy | A prompt rule set against the "Codex/GPT UI": soft gradients, floating panels, eyebrows, decorative copy, heroes in dashboards, big radii, pills, glass. Gives "normal" specs per component (sidebar 240-260px, radius 8-12px, shadows at most 0 2px 8px). | Useful for app and dashboard screens, where most tools focus on landing pages. Its "think Linear/Stripe/GitHub" fix risks a new monoculture of its own. |
| OpenAI frontend prompt guide | https://developers.openai.com/api/docs/guides/frontend-prompt and https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4 | Rules: cards at 8px radius or less "unless the existing design system requires otherwise", no cards in cards, no page sections as floating cards, no orbs or bokeh, limit purple/blue *and* beige/cream/sand *and* slate *and* espresso palettes, no in-app text describing features, use the existing app's conventions and icon library. | Limiting both the old and the new default palettes at once is the right defence against a swap. The existing design system is given precedence in writing. |
| Slopstrap | https://slopstrap.mikelacher.com/ (HN: https://news.ycombinator.com/item?id=50576012; the nine tells written up at https://dev.to/alanwest/how-to-make-your-website-not-look-ai-generated-9-tells-from-slopstraps-css-3a73) | A parody CSS framework of the AI look | Good as a test fixture (a page that must score high). HN says it already parodies last season's look, so the catalogue needs a date and regular refresh. |
| Adrian Krebs' Show HN scorer | https://www.adriankrebs.ch/blog/design-slop/ | Playwright + in-page DOM/computed-style checks for about 16 patterns over about 1,590 Show HN pages; tiers by pattern count (4+ high = 22%); manual QA puts false positives at about 5-10% | Proves the render-tier approach works and gives a scoring model: count co-occurring patterns rather than punishing any single one. |
| Nelson Lee, "How to unslop your vibe coded site" | https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site | Process: audit and list the patterns first without changing anything; the human marks what to keep; set a direction (three or four brand words plus one admired site) and approve it; fix one screen at a time with screenshots; persist the result to DESIGN.md referenced from CLAUDE.md | The workflow the command should follow: audit, then the human decides, then direction, then incremental fixes, then persist |
| awesome-design-md / DESIGN.md packs; tweakcn; make-interfaces-feel-better | https://github.com/VoltAgent/awesome-design-md, https://github.com/Meliwat/awesome-ios-design-md (per [r/vibecoding](https://reddit.com/r/vibecoding/comments/1tk55n4/your_vibecoded_app_looks_aimade_because_the_model/)), tweakcn (per [r/cursor](https://reddit.com/r/cursor/comments/1p8jyg7/how_do_i_get_my_ui_to_look_this_clean_mine_always/nr5x345/)), https://github.com/jakubkrehel/make-interfaces-feel-better (per [r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1txvaef/if_you_used_claude_to_build_your_website_which/opyrfh5/)) | Reference design systems for agents; a shadcn theme editor; a polish skill | The most-upvoted human advice is "give it a reference". A DESIGN.md is the shared format for that across tools (Impeccable, Hallmark, Nelson Lee, Reddit users). |
| frontend-design-pro (claudekit) | https://github.com/claudekit/frontend-design-pro-demo | 11 preset aesthetics (brutalism, claymorphism, ...) | A warning: presets were themselves called slop in the thread ([r/ClaudeCode](https://reddit.com/r/ClaudeCode/comments/1p9srut/finally_figured_out_why_claudes_ui_generations/)). A menu of styles is another default. |

---

### 5. What an unslopify command needs

#### 5.1 Checks a script can run

**Static tier** (source, CSS, Tailwind classes, JSX/HTML text). Fast, CI-friendly, file:line output:

1. **Colour tokens and literals.**
   - Violet/indigo hue as primary or accent.
   - Gradients with violet-to-blue/pink stops; `background-clip:text` gradients.
   - Untouched framework palettes: Tailwind `indigo/violet/purple/slate` utilities; a shadcn `globals.css` identical to the default theme.
   - The cream + serif + terracotta triple (paper L ≥ 90, hue 55-105; accent hue 15-55; serif display).
   - Near-black #0B0B0B/#111 with a single acid accent.
   - Coloured zero-offset glows; blurred absolutely positioned orbs; `backdrop-filter` on cards.
   - Colour literals outside the token file.
2. **Type.**
   - The display `font-family` is Inter/Geist/Roboto/system.
   - Mono on non-code elements.
   - `uppercase` + `letter-spacing > 0.03em` on small text before a heading (the eyebrow).
   - An `<em>`/`<span>` with a different family or colour inside an h1/h2 (the accent word).
   - More than 3 families; non-zero letter-spacing on body text.
3. **Components.**
   - A thick one-side border on an element with `border-radius`.
   - Nested bordered/rounded containers.
   - One radius value on most elements; `rounded-full` buttons.
   - An icon in a tinted tile above a heading.
   - `hover:` lift/shadow on non-interactive elements.
   - Reveal-on-scroll wrappers on most sections.
   - Pulsing small circles.
   - Marquee animations.
   - Missing `prefers-reduced-motion`.
   - Off-scale spacing values.
4. **Text** (visible strings).
   - Emoji code points in nav, headings and buttons.
   - Two or more middle dots in a string; `//` separators; trailing `→` on link text.
   - Rebuttal cadence ("No X. No Y. Just Z.", "Not X, it's Y").
   - Buzzword list (elevate, seamless, unlock, supercharge, empower, effortless, next-generation, ...).
   - Hero verbs (Build/Manage/Grow/Transform).
   - Placeholder names (Jane Doe, Acme), "Lorem".
   - Em-dash density.
   - Phrases leaking implementation ("built with", "powered by", "never leave your browser").
5. **Behaviour.**
   - `{error.message}`-style rendering in JSX.
   - Forms whose submit handler sets success without a network call.
   - `href="#"` / empty handlers.
   - Data-fetching components with no empty or error branch.

**Render tier** (Playwright at phone and desktop widths, computed styles and screenshots), as Krebs, Hallmark `--render` and Impeccable "Browser" rules do:

- contrast ratios
- rendered type scale ratios (flat hierarchy)
- words per viewport
- image-area share
- section-gap variance
- alignment of icons to text baselines
- horizontal overflow
- broken images and links
- tap-target size
- JS errors on load
- content stuck at `opacity:0`
- a greyscale render to check whether hierarchy survives
- the section-sequence fingerprint (hero, 3-up cards, pricing, CTA, footer)

**Scoring:** follow Krebs and count co-occurring patterns per page (0-1 low, 2-3 medium, 4+ high) rather than failing on any single tell. People clock sameness from the combination, and almost every single pattern has defenders.

#### 5.2 Checks that need judgement (a reviewer agent with screenshots, or the human)

- Is the numbering a real sequence? Is the stat or testimonial real? Is the badge or status dot wired to state?
- Does the page say what this product is, for whom, in the customer's words? Would it still be recognisable without the logo? ([r/SaaS](https://reddit.com/r/SaaS/comments/1xvuox7/most_vibecoded_websites_just_look_the_same/))
- Hierarchy: where does the eye land? Is one element the memorable thing, with the rest quiet?
- Information architecture in apps: one primary task per screen, no everything-on-one-screen dashboard.
- Is the style right for the audience? (The dark, technical look on a product for non-technical users: [r/vibecoding](https://reddit.com/r/vibecoding/comments/1vnc06s/every_ai_landing_page_looks_the_same_mine_did_too/).)
- Copy that is fluent but says nothing; repeated headings and descriptions; chat context in copy.
- Error, empty and loading states: are they designed?
- Was a flagged pattern chosen on purpose? Only the repo's records or the human can say.

#### 5.3 Fixing without overriding the repo's design system

1. **Read the system first.** Collect the tokens (CSS variables, `tailwind.config`/`@theme`, theme files), a DESIGN.md or design-system docs, brand assets (logo, font files), the component library and its theme. Hallmark: a brand is "a logo, a colour or a face the project names"; "a framework default... is not a brand" ([redesign.md](https://github.com/Nutlope/hallmark/blob/main/skills/hallmark/references/redesign.md)).
2. **Classify each finding** as *chosen* (defined in project tokens, docs or brand files, or marked with an ignore comment) or *default* (a framework default, or a literal that matches a known default cluster with no project record). Report chosen findings at most as notes; never "fix" them. OpenAI's own guide defers to "the existing design system", and Anthropic's says "the brief's own words always win".
3. **Respect explicit opt-outs.** Support an ignore marker like `unslop-ignore` / `data-impeccable-ignore`. Hallmark's waivers carry evidence and a reason. After repeated waivers, suggest writing the choice into DESIGN.md.
4. **Fix inside the system:**
   - Swap literals for existing tokens.
   - Reuse existing components rather than making new ones.
   - Prefer removal (eyebrow, stripe, glow, emoji, reveal) over replacement.
   - Change tokens only with the human's approval.
5. **Offer depths, defaulting to the smallest.** polish = only the named tells, contrast and states; restyle = the system changes, the layout stays; full = the composition changes (Hallmark). The default is polish, because the command runs on existing repos.
6. **Never break wiring or content.**
   - Record links, ids, `data-testid`, handlers, routes and every fact on the page before changing anything.
   - Do not invent content.
   - List every changed line of copy, before and after.
   - Leave legal and consent text alone.
   - Leave a slot for missing facts rather than making them up.

   (Hallmark redesign.md; the Hallmark test noted "Anything I didn't give it... stayed as a visible empty slot" ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/)).)
7. **Audit first, then the human decides, then fix one screen at a time with screenshots, then persist** the agreed direction to DESIGN.md referenced from CLAUDE.md ([Nelson Lee](https://nelsonxlee.substack.com/p/how-to-unslop-your-vibe-coded-site)).

#### 5.4 Not swapping one generic look for another

The research shows this failure clearly: unslop-ui's "after" (top comment, 278 pts), frontend-design-pro's presets, Hallmark's blackletter choice and Impeccable's own busy site.

1. **Detect old and new defaults together.** The detector must flag the 2024 cluster (purple, gradient, Inter, dark neon, three cards) *and* the 2025-26 cluster (cream paper, serif display, terracotta or sage, eyebrows, mono labels, middle dots, 01/02 numbering, left stripes, hairline broadsheet), and must not suggest either as a fix. OpenAI's guide limits purple/blue, beige/cream/sand, slate and espresso palettes together ([OpenAI](https://developers.openai.com/api/docs/guides/frontend-prompt)).
2. **Never prescribe a palette, font or layout from the command itself.** unslop-ui's rule: "Prescribing one is how you become next year's slop." Every replacement must trace to a source the repo or the human supplied: the brand, the subject matter, a reference site the human named, an existing token. If none exists, ask for a reference or present two or three distinct directions for the human to choose; do not pick silently. Reference sites are the most-upvoted fix in the threads.
3. **Ground choices in the subject.** Anthropic: "The subject's industry, subject matter, materials, and vernacular are where distinctive visual choices come from."
4. **Self-check against the median.** Before applying a direction, ask whether it is what the model would produce for any similar page (Anthropic's two-pass plan review), and check it against the detector itself so the fix cannot score as slop.
5. **Keep a ledger.** Like Hallmark's `.hallmark/log.json`, record the structural fingerprint of each unslopified screen, so a team's pages don't all converge on the command's own look.
6. **Prefer subtraction.** Most well-supported fixes in the catalogue are removals (eyebrow, glow, emoji, stripe, reveal, box, badge, filler line) or a swap to real content (screenshot, real quote, customer words). Removals carry little risk of a new monoculture.
7. **Date and refresh the catalogue.** The look moved from purple to cream within about a year, according to HN and Reddit ([HN](https://news.ycombinator.com/item?id=50576012), [r/SaaS](https://reddit.com/r/SaaS/comments/1wa2e1r/the_importance_of_not_having_a_vibe_coded_looking/p8ib3vw/)). Keep the rule list in data with a "last reviewed" date, and re-mine threads periodically, as the JCarterJohnson repo's scripts show how to do with Arctic Shift.
8. **Be honest about the ceiling.** A linter removes tells but "can't pick a direction" ([r/ClaudeAI](https://reddit.com/r/ClaudeAI/comments/1xihh3t/i_tested_the_hallmark_antiaislop_skill_in_claude/19rtv3ftjbjsz/)). The command's report should say what it removed, what it left as chosen, and what needs a human's taste. It should not claim the result is "designed".


# Part 2

## AI UI slop: a cited catalogue for an `unslopify` command

Researched 2026-11-25. Every claim links to its source. Sources are numbered `[S#]`. The full list, with URLs, is at the end.

**How the human evidence was gathered**

- **Hacker News.** The comment threads themselves were read through the public HN Algolia API. That covers the full threads [S29] [S30] [S31] [S32] [S33] [S34] [S35] [S36], plus a keyword search over all HN comments since mid-2024. Counts in the "Humans" column are distinct HN usernames naming the pattern in an AI/vibe-coding context.
- **Reddit.** reddit.com and old.reddit.com refuse automated fetching from this environment (HTTP 403, a login wall, and "unable to fetch"). The Arctic Shift archive API timed out on every query. So the Reddit evidence comes from a public, MIT-licensed dataset that mined Reddit through Arctic Shift [S26]. It covers 3,033 comments from 125 threads such as "why do AI sites all look the same", across 47 subreddits. Its quote bank gives a permalink for each quote [S27].
  - Reddit counts below are that dataset's "comments mentioning" figures.
  - Reddit quotes come from its quote bank. The Reddit permalinks were not opened, for the access reason above.
- **"Widely cited"** means 3 or more independent sources name the pattern, where an HN commenter, a Reddit comment, a blog and a tool each count as one source.

---

### 1. What the sources agree on

1. **The cause is defaults.** Models produce the most likely look unless told otherwise.
   - Anthropic says so itself: without guidance, a landing page "will almost always conform to Inter fonts, purple gradients on white backgrounds, and minimal animations" [S1]. Its prompt calls this converging on "on distribution" outputs, "what users call the 'AI slop' aesthetic" [S4].
   - Humans say the same in plainer words: "these LLMs have a design vocabulary of like 15 traits… composed of some subset of 10 such traits" (applfanboysbgon, HN [S34]).
2. **No single trait is the tell; the combination is.**
   - "Individually most of these things are fine… it's the aggregate that makes things feel LLM-y" (InexSquirrel, HN [S29]).
   - pixelslop scores a page by how many patterns co-occur, and says single traits "are legitimate on their own" [S5].
   - Adrian Krebs scored 1,590 Show HN pages: 22% hit 4 or more patterns and 46% hit 0 or 1 [S22].
3. **The look moves, and anti-slop rules create the next look.**
   - 2025 slop was purple/indigo gradients, Inter, a centred hero and three cards [S1] [S18].
   - By 2026, people name cream/beige backgrounds with a serif and an orange/terracotta accent, plus thick left borders and tracked all-caps eyebrows. "The slop standard now is Claude or whatever's small type sizing, serif fonts and beige / tan color schemes" (ChrisArchitect, HN [S29]). "It's not the Tailwind purple anymore… more of the same beige scheme" (ChrisArchitect, HN [S30]).
   - Anthropic's own skill now lists the cream + serif + terracotta (#D97757) look as a cliché, along with near-black + acid green and the "SaaS-card kit" [S2].
   - One writer warns that avoiding purple "just produces another common cluster" [S21]. HN users report that anti-slop skills "all seem to converge on the same thing" (mstkllah, HN [S35]).
4. **Purple/violet gradients are still the single most-named visual tell.** The Reddit dataset puts them just behind "shadcn/Tailwind defaults" [S26]. More than 20 distinct HN users name them. Sources trace them to Tailwind UI's `bg-indigo-500` and Adam Wathan's 2025 semi-joking apology [S18] [S14].
5. **Slop is also broken UX, not only looks.** The cited failures are:
   - only the happy path designed [S7]
   - missing hover, focus and disabled states [S17] [S10]
   - low contrast and tiny text [S15]
   - fake social proof, testimonials and metrics [S23] [S10]
   - forms that say "thanks" without sending [S24]
   - status dots wired to nothing [S23]
6. **Some humans push back.** Many argue these patterns came from Tailwind UI, shadcn and Bootstrap before AI. Others say they are fine in moderation, or that AI output has *better* defaults than many human sites (see "Disagreement" below). A fix must not just swap one house style for another.

---

### 2. The catalogue

**Columns**

- **Detect:** **Script** means a deterministic check can find it (method given). **Judge** means a reviewer has to decide. **Both** means a script can flag candidates for a reviewer.
- **Humans:** distinct HN commenters (HN) and Reddit dataset comment counts (R). "—" means the pattern came from articles and tools only.
- **WIDE** means widely cited (3 or more independent sources).

#### 2.1 Colour

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Purple/violet-to-blue gradients** (WIDE) | `linear-gradient`/`bg-gradient-to-*` with `from-purple|violet|indigo|fuchsia` and `to-blue|cyan|pink`. The hero, CTA or headline background has hue stops around 250–300° | Called the "default 'AI product' palette" [S5], and "decoration standing in for a real colour system… meaningless" [S7] | Colour by role, tied to the brand. Use one solid accent [S12]. A gradient only marks one focal point [S8] | **Script.** Parse gradient stops, convert to HSL/OKLCH, and flag when 2 or more stops fall at hue 230–320° with saturation above 40%. Also grep Tailwind `from-(purple|violet|indigo)` and `to-(blue|cyan|pink)` [S5] [S20] | HN 22+ (e.g. jstanley: "The blue/purple gradient is a Claude favourite" [S48a]); R 71 | [S1] [S3] [S5] [S7] [S8] [S9] [S14] [S18] [S20] [S22] [S26] |
| **Indigo/violet as the primary accent** (WIDE) | Primary is `#6366f1`, `#8b5cf6`, `#7c3aed`, or Tailwind `bg-indigo-600`/`violet-*` buttons, with no brand reason | The colour comes from "a billion tutorials" [S9] and Tailwind UI's `bg-indigo-500` [S18] | Use the brand's own hue. Blue, teal or another colour chosen for meaning [S11] | **Script.** Grep for those hexes and classes. Resolve the primary token and flag it when its hue is 240–290° | HN 10+ (sen: "purple-on-purple-with-glowing-purple mess" [S30]) | [S9] [S11] [S14] [S18] [S22] |
| **Gradient text on headings or metrics** (WIDE) | `background-clip:text` or `bg-clip-text text-transparent` on h1–h3 or stat numbers | "Decoration replaces communication" [S5]. It often fails AA contrast [S27] | Solid colour. Get emphasis from size, weight or position [S12] | **Script.** Computed style or grep for `background-clip: text` on headings and stat elements [S5] | HN 5 (gkolli, skyberrys, PennRobotics…); R 60 (shared with gradients) | [S5] [S10] [S12] [S13] [S6] [S23] |
| **Dark mode by default, with neon/cyan glow** (WIDE) | Body background at or below rgb(45,45,45), saturated `box-shadow` glows, cyan/lime accents on near-black | The "AI dashboard" look, nicknamed the "Nightclub palette" [S5]. Chosen regardless of audience [S12] | Choose the theme from audience and brief. Light by default unless the brief asks for dark [S11]. Reserve glow for real states | **Script.** pixelslop thresholds: dark body plus more than 2 saturated shadows; cyan text with R<50, G>180, B>200 [S5] | HN 8+ (hankbond: "nearly every LLM website seems to be dark mode" [S48b]); R 22 | [S5] [S11] [S12] [S22] [S26] |
| **Cream/beige + serif + terracotta/orange accent** (the newer Claude look) (WIDE) | Background near `#F4F1EA`, a high-contrast serif display, an accent near `#D97757` | Anthropic: "Anthropic's own Claude-interaction accent, so on a user's brief it reads as a tell" [S2] | Pick a direction from the subject's own world [S2]. Don't swap purple for this | **Both.** Flag a background with lightness above 93% and a warm hue (30–60°) paired with an accent at hue 10–30°. A reviewer decides if the brief justifies it | HN 12+ (lagrange77: "the classical beige/serif AI slop website" [S48c]; jjcm, baubino, ChrisArchitect, monk_grilla) | [S2] [S11] [S25] [S29] [S30] [S33] |
| **Near-black + one acid-green/vermilion accent; retro terminal** | `#0B0B0B`/`#111` background, lime or neon green text, terminal styling | Listed by Anthropic as a generated-page cliché [S2]. HN calls it the "Wargames-like UX" [S36] | As above | **Script** for the colour pair. **Judge** for the terminal styling | HN 4 (beatthatflight, harrisonpage, gkolli, Wpnx330); R quote: "Black background, neon and lime green text" [S27] | [S2] [S27] [S31] [S36] |
| **Low-contrast grey body text, worst on dark themes** (WIDE) | Secondary text below 4.5:1, or grey on coloured backgrounds | Fails WCAG. One audited vibe-coded site had more than 50 low-contrast instances, with ratios of 1.7–3.17 [S15]. "Barely passing body-text contrast in dark themes" [S22] | Pick secondary text per background and verify the ratio. Tint grey toward the background hue [S12] | **Script.** Compute contrast on rendered pages with axe-core or a custom check. Impeccable has `low-contrast` and `gray-on-color` rules [S47] | HN 8+ (vunderba, computerphage, nottorp, meshweaver…); R "grey on dark grey making it unreadable" [S27] | [S5] [S12] [S15] [S22] [S30] [S47] |
| **Pure `#000`/`#fff` base** | Body background exactly #000000 or #ffffff | "Suggests no palette was designed" [S5] | Tint neutrals slightly toward the brand hue [S12] | **Script.** Grep, or read the computed body background | — | [S5] [S12] |
| **Rainbow of arbitrary accent colours** | Side tabs, status pills and borders in many unrelated hues | Overused colour "reduces the usefulness of semantically important coloration" (NewJazz, HN [S29]) | 4–6 named colours, each with a stated role [S2] | **Both.** Count distinct accent hues in use. Flag more than about 5 that are not from tokens | HN 3 (NewJazz, InexSquirrel, meshweaver) | [S2] [S29] [S11] |

#### 2.2 Typography

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Inter (or Roboto/Arial/system) for everything** (WIDE) | One sans-serif family for body and display. `font-family: Inter`, or the default Tailwind/shadcn stack | Inter is a good typeface, so seeing it everywhere signals that "no one chose a font" [S7]. Anthropic names it first [S1] [S3] | One distinct display face plus a readable text face, chosen for a reason [S3] [S7] | **Script.** Resolve the primary families and flag when both body and heading are in {Inter, Roboto, Arial, Open Sans, Helvetica, system-ui, Segoe UI, -apple-system} [S5] | HN 7+ (sph, RomanHauksson, EForEndeavour, roundabout-host…); R 13. **Contested** (see §2.13) | [S1] [S3] [S5] [S7] [S9] [S12] [S13] [S20] [S22] [S26] |
| **The "AI-favoured" second-wave fonts** | Space Grotesk, Geist, Instrument Serif, Syne, Fraunces, JetBrains Mono | Anthropic notes Claude still converges on Space Grotesk [S1]. Krebs lists the "slop fonts" [S22] | Choose type from the subject, not from a list of trendy fonts | **Both.** Flag these as weak signals that count only in combination. Geist causes false positives on human-built sites [S13] | HN 2 (kneco jokes "not enough space grotesk"); **defended** by flexagoon and bstsb [S30] | [S1] [S13] [S22] [S23] |
| **Tracked-out ALL-CAPS eyebrow/kicker above every heading** (WIDE) | Small uppercase label with wide letter-spacing above each h2, often in the accent colour | Anthropic: one of "the commonest tells of a generated page" [S2]. Hallmark bans it [S24] | Drop it unless it carries information. Use sentence case [S10] | **Script.** Find an element just before an h1–h3 with `text-transform: uppercase`, `letter-spacing` of 0.1em or more and a size of 14px or less. Impeccable has `tracked-caps`, `kicker-above-heading` and `hero-eyebrow-chip` [S47] | HN 7 (bryanhogan, lanewinfield, jaakkonen, tao_oat, EForEndeavour, f3408fh, whywhywhywhy) | [S2] [S8] [S13] [S22] [S24] [S47] |
| **One word in a headline set in italic serif, or recoloured** (WIDE) | `<em>`/`<span>` with a different family, style or colour on one word of an h1 | Anthropic: "Accenting just a single word or phrase in a headline" [S2]. Refero: "decorative one-word headline treatment" [S11] | Contrast through scale, weight or layout [S11] | **Script.** An h1/h2 child span with a different `font-family`/`font-style`/`color` covering fewer than 3 words. Impeccable has `italic-serif-display` and `accent-bold` [S47] | HN 6 (InexSquirrel, fantasizr, ericpauley, f3408fh, lanewinfield, joshellington) | [S2] [S11] [S22] [S23] [S24] [S47] |
| **Monospace for small labels / "tech theatre"** (WIDE) | Monospace on badges, meta and labels outside code | "Fakes a technical tone" [S5]. Named by Anthropic [S2] | Reserve mono for code, IDs and tabular data [S12] | **Script.** Monospace computed on non-code elements, flagged when there are more than 2 [S5] | HN 3 (tao_oat, whywhywhywhy, sheept) | [S2] [S5] [S12] |
| **Timid or flat hierarchy** | One or two weights, sizes in a narrow 1.2–1.5× band, near-duplicate sizes (12px and 12.8px) | "Everything is shouting at the same volume" [S7]. The near-duplicate sizes make the UI look disjointed [S15] | Extreme contrast: weights 200 vs 800, size jumps of 3× or more [S3]. A clear scale [S2] | **Script.** Collect font sizes and weights. Flag fewer than 3 weights, a max/min ratio below 2.5, or sizes within 1px of each other. Impeccable has `flat-type-hierarchy` [S47] | HN 1 (meshweaver, small fonts) | [S3] [S7] [S10] [S12] [S15] [S47] |
| **Tiny text** | Body text under 16px, 12px CTAs, 10px meta | One audit found body copy at 12.8px and the CTA at 12px [S15]. "Fonts are too small" (meshweaver, HN [S48d]) | 16px minimum for body [S15] | **Script.** Computed font sizes | HN 4 (meshweaver, ChrisArchitect, g-b-r, WorldMaker) | [S15] [S29] [S48d] |
| **Title Case and all-caps everywhere** | Title Case on all copy. Uppercase on paragraphs | Ban-list item [S10]. Anthropic: "Using all caps for labels" [S2] | Sentence case [S10] | **Script.** Text-case analysis | — | [S2] [S10] |

#### 2.3 Layout

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Centred hero with a badge, headline, subhead and two CTAs** (WIDE; the maintainer's example) | Full-width centred block: pill badge, then h1, then p, then "Get started" plus "Learn more" | "Template execution" [S5]. The hero pair has "identical visual weight" [S10] | Left-aligned editorial or 60/40 split hero. One primary CTA and one secondary [S10]. Open with the most characteristic thing in the subject's world [S2] | **Script.** pixelslop's "4 of 5 signals": width ≥90% of viewport, height >40%, an h1, a p, 1–3 CTAs [S5]. polydraft: a centred h1 with two generic CTAs [S20] | R 7 ("Same hero: huge headline + 2 buttons"); HN 2 | [S5] [S9] [S10] [S13] [S18] [S20] [S22] [S26] |
| **Three identical icon-topped feature cards** (WIDE) | Grid of 3 (or 4×n) same-size cards: icon tile, h3, two lines of text | "Cookie-cutter feature sections" [S5]. "The visual equivalent of beige carpet" [S9] | A list, table or asymmetric layout that fits the content [S12]. Vary size by importance | **Script.** 3+ grid/flex siblings, equal size, descendant counts within ±2 [S5]. polydraft `card-grid-3` [S20] | HN 5 (dematz, podgietaru, PennRobotics…); R 13 | [S5] [S9] [S10] [S12] [S13] [S18] [S20] [S22] [S26] |
| **Cards wrapping everything; nested cards** (WIDE) | Every section is a bordered, rounded, shadowed box. Cards sit inside cards | "The interface is more container than content" [S5]. "Cardocalypse" [S12] | Let content sit on the page. Use cards only for interaction containers [S11] | **Script.** Count containers with radius >4px plus border/shadow and padding >8px. Flag more than 6, or any nesting [S5] | HN 6 (tao_oat, dematz, vitorfblima, meshweaver…); R: "the urge to put a box around everything" [S27] | [S2] [S5] [S6] [S11] [S12] [S27] |
| **Everything centred** (WIDE) | More than 70% of headings and paragraphs are `text-align:center` | "Safe default with no layout decisions" [S5] | Left-align body text. Use asymmetry where it helps reading [S5] [S12] | **Script.** The pixelslop ratio [S5] | R 7 | [S5] [S10] [S12] [S18] |
| **The fixed section order** | Hero, features, social proof, pricing, FAQ, footer, every time | Models pattern-match on shadcn, Tailwind UI and Vercel templates [S9] | Structure the page from the content and the visitor's task [S24] | **Judge.** A script can flag a match against the canonical order | HN 2 (lispisok, anonzzzies) | [S9] [S21] [S24] |
| **Stat banner / hero metric row** (WIDE) | A row of big numbers with small labels ("10,000+ users", "99.9% uptime"), often counting up | Anthropic: "a big number with a small label, supporting stats, and a gradient accent is the default" [S2] | Lead with the insight in a sentence. Give each metric a comparison [S12] | **Script.** 2+ numeric nodes at 24px or larger with under 15 characters [S5] | HN 3 (loufe: "those interactive 'stats' cards scream LLM-written" [S48e]; applfanboysbgon; nomdep) | [S2] [S5] [S12] [S13] [S22] [S23] |
| **Numbered 01/02/03 steps on non-sequences** (WIDE) | Big numerals on items that have no order | Anthropic: only valid "if the content actually is a sequence" [S2] | Use bullets unless the order matters [S10] | **Both.** Detect the numeral markers. A reviewer judges whether the items form a sequence | HN 1 (joegibbs: "superfluous numbers") | [S2] [S10] [S13] [S22] |
| **Bento grid** | 12-column asymmetric tile mosaic | Satirised by Slopstrap [S23]. Listed by Krebs-style checkers | Use it only when tiles really differ in weight | **Judge** | HN 2 (jasonjei, bryanhogan); R 4. **Defended** ("I love Bento grids" [S27]) | [S23] [S26] [S27] |
| **Logo marquee / "Trusted by" strip** | Greyed, endlessly scrolling logo row | Often unverified. "You can put any logos you want this way" (nojs, HN [S29]) | Show real customers only, and link them | **Script** to find it (polydraft `logo-bar` [S20]). **Judge** whether it is real | HN 3 (jen729w, NewsaHackO, nojs) | [S20] [S23] [S29] |
| **Mobile: `h-screen` heroes, a shrunk desktop layout, missing actions** | 100vh hero on phones. Core actions hidden on mobile | Ban list: cap mobile heroes at 70–80vh [S10]. "Mobile Amputation" [S12] | Recompose the layout for narrow screens [S12] | **Script.** Render at 390px. Check hero height and that primary actions are present | — | [S10] [S12] [S17] |

#### 2.4 Spacing and sizing

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Values off the spacing scale** (maintainer's example) | Padding, margin, gap and radius values that are not multiples of 4/8, or not in the repo's scale (13px, 18px, 22px, arbitrary `p-[13px]`) | "Spacing drift: looks slightly 'off'… no single element clearly wrong" [S17]. The thoughtbot fix was rebuilding on a 4px grid [S15] | Use the repo's own spacing tokens. With no tokens, use a 4/8px scale [S15] | **Script.** Parse CSS, Tailwind arbitrary values and inline styles. Flag lengths whose px value is not in the project's scale, or not divisible by 4 when no scale exists. Stylelint plugins already do this [S40] [S41] [S42] | HN 2 (sourweasel: "text boxes with zero padding"; lagrange77 on "subtle misalignments"). **Counterpoint:** lxe says AI spacing is "too deliberate" [S29] | [S15] [S17] [S40] [S41] [S42] |
| **Same spacing everywhere** (WIDE) | Every section has identical vertical padding. Only 1–2 distinct values | "No visual rhythm" [S5]. Nothing leads the eye [S7] | Tighter spacing inside groups and larger gaps between them [S12] | **Script.** 6+ spacing values with 2 or fewer unique values after rounding to 4px [S5]. polydraft `same-rhythm`: 75% or more of sections sharing one padding value [S20] | — | [S5] [S7] [S10] [S12] [S20] |
| **One border-radius on everything; `rounded-2xl shadow-lg p-6`** (WIDE) | Cards, buttons, inputs and images all share the same large radius | "Every AI-generated component has rounded-2xl shadow-lg p-6 somewhere" [S9]. "When every element has identical corners, nothing stands out" [S8] | A radius scale tied to component role. Full pills only where needed [S8] [S10] | **Script.** Histogram of radius values. Flag when one value covers more than 80% of rounded elements, or when `rounded-(2xl|3xl)` appears [S9] | HN 10 (roundabout-host, sph, applfanboysbgon, NewJazz, henriquegodoy, kavith…); R 23 | [S2] [S8] [S9] [S10] [S21] [S26] |
| **Broken sizing** | Narrow buttons whose label wraps onto two lines. Zero-padding inputs. Off-centre elements | "It's the 'brokenness' aspect of AI generated UIs" (sourweasel, HN [S48f]). "Multiple elements are off centered" [S27] | Visual QA at several widths [S17] | **Script.** Render, then check for text wrapping inside buttons, padding of 0 next to a border, and overflow | HN 1; R 1 | [S17] [S27] [S48f] |

#### 2.5 Components

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Untouched shadcn/Tailwind default kit** (WIDE) | Default shadcn tokens (zinc/slate neutrals, default `--radius`), stock components with no theme changes | The Reddit dataset's #1 feature tell (76 comments) [S26]. v0 "is specifically trained on the default implementations of the shadcn/ui components" [S21] | Theme it: your own palette, radius, type and density [S39]. Swap the palette rather than extending it [S9] | **Script.** Compare `components.json` and the CSS variables against shadcn's default theme values | HN 5+ (ignaciosoffia, dalemhurley, jjcm, stevenhubertron, nomdep); R 76 | [S9] [S21] [S26] [S39] [S22] |
| **Thick coloured border on one side of a rounded card** (WIDE) | `border-left: 3–4px solid <accent>` with other sides at 1px or less, on a rounded box | "Colored left borders are almost as reliable a sign of AI-generated design as em-dashes" (designer quoted by Krebs [S22]). "Thick left border will become the visual 'you're absolutely right!'" (trueno, HN [S48g]) | Use a side stripe only for status, priority or selection, with a meaning you can state in one word [S11] | **Script.** One side 3px or more and two sides under 2px, more than 2 times [S5]. Impeccable `border-accent-on-rounded`/`side-tab` [S47] | HN 11 (skerit, trueno, InexSquirrel, aleksiy123, hdjrudni, precompute, monk_grilla, tao_oat, f3408fh, whywhywhywhy, joegibbs); R 2 quotes. **Defended** by merelysounds, kykat, richard_chase | [S5] [S8] [S11] [S12] [S22] [S23] [S27] [S29] [S30] |
| **Pill badges with a pulsing status dot** (WIDE) | "● Live", "✨ v2.0 Now Available", "NEW" pills. Green dot not tied to any state | "Looks like status information but conveys none" [S8]. "Those dots usually denote some kind of status… By default nearly every LLM website seems to be dark mode with that dang status pill" (hankbond [S48b]) | Show a badge only for a real state [S8] | **Both.** Find small elements with `animate-pulse`/`ping` and a dot plus a label. A reviewer checks the dot is wired to data | HN 8 (hankbond, meshweaver, tao_oat, Zopieux, applfanboysbgon, EForEndeavour, nlh, anony-123) | [S8] [S13] [S22] [S23] [S29] |
| **Every button primary / no action hierarchy** (WIDE) | 3 or more filled buttons with the same style in one view | "No action hierarchy" [S5] | One primary per view. Secondary, ghost or text styles for the rest [S12] | **Script.** pixelslop: button style uniformity above 0.6 [S5] | — | [S5] [S10] [S12] |
| **Modal for everything** | Every add, edit or detail opens a dialog | "Modals as the default for every task" [S5] | Inline editing, a side panel or a page, chosen by task size [S12] | **Script.** Count dialog components and roles [S5] | — | [S5] [S12] |
| **Fake macOS terminal / code window** | A rounded box with red/yellow/green dots showing a code snippet | "A container representing a macOS-styled terminal with code" (sph, HN [S48h]) | Show the real product or real output | **Script.** Three small circles in #ff5f56/#ffbd2e/#27c93f, or the class names | HN 1; Slopstrap | [S23] [S48h] |
| **Decorative sparklines and fake charts** | Tiny unlabeled SVG lines | "Charts that look like data but carry none" [S5] | Remove them, or label real data [S12] | **Script.** SVGs 20–120px wide and under 60px tall with 1–4 paths [S5] | — | [S5] [S12] |
| **Default stock components (toasts, spinners, charts, avatars)** | Library-default toast, spinner, chart colours | Ban list: style them to the brand [S10] | Brand them, or use skeletons [S10] | **Judge** | — | [S10] [S16] |

#### 2.6 Effects

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Glassmorphism everywhere** (WIDE) | `backdrop-filter: blur` on navs, cards and buttons, with translucent white | "Frosted layers become the default container style" [S5] | One deliberate glass layer at most [S10] | **Script.** Count `backdrop-filter`/`backdrop-blur`. Flag 3 or more [S5] | R 7; HN 1. **Defended** ("I'm personally a fan of glassmorphism" [S27]) | [S5] [S10] [S12] [S13] [S20] [S22] |
| **Glow on everything / coloured shadows** (WIDE) | Saturated `box-shadow`, `text-shadow` glows, glow rings | "AI loves this glowing shit. for no reason." [S27] | Reserve glow for a single emphasis [S10] | **Script.** Box-shadow colour saturation [S5]. Impeccable `dark-glow` [S47] | HN 3 (Wpnx330, bstsb, sen); R 22 | [S5] [S10] [S22] [S27] [S31] [S47] |
| **Same soft grey shadow under every card** (WIDE) | `shadow-md/lg/xl`, `rgba(0,0,0,.1)` everywhere | Anthropic's "SaaS-card kit" [S2]. "Default depth" [S5] | Shadows only for real elevation. Otherwise borders or tone shifts [S12] | **Script.** Shadow-value histogram. Flag more than 4 rounded boxes sharing one shadow [S5] | HN 1 (Wpnx330) | [S2] [S5] [S10] [S12] |
| **Blurred orbs, mesh/aurora blobs, grid backgrounds** | Absolutely positioned blurred circles, `bg-grid` | "Abstract blob backgrounds" [S11]. Satirised as `.slop-orb` [S23] | Use imagery that carries meaning [S10] | **Script.** Large elements with `filter: blur()` and radial gradients | R 8 (flagged by the dataset as noisy) | [S11] [S23] [S26] |
| **Rotating conic / rainbow borders, shimmer sweeps** | `conic-gradient` with an animation on borders. A shimmer on hover | Ban list: "Animated rainbow borders" [S10]. Shimmer is borrowed from the AI "thinking" state [S25] | Static borders [S10] | **Script.** Grep `conic-gradient` plus `@keyframes` rotate | HN 1 (xg15) | [S10] [S23] [S25] |

#### 2.7 Icons and imagery

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Emoji as icons or heading decoration** (WIDE) | 🚀 ✨ 💡 🎯 in h2s, feature cards and nav | "Emojis as icons. If I see them, I instantly doubt the creators ability to even vibe-code properly." (r/ClaudeAI [S27]) | One SVG icon set, or nothing [S10] | **Script.** Unicode emoji ranges inside headings, buttons and nav. Watch for false positives such as ★ (U+2605) [S20] | HN 6 (wolandark, sunaookami, Bishonen88, Wpnx330, dematz, k0morebi); R 16 | [S10] [S11] [S13] [S20] [S22] [S23] [S27] |
| **Icon in a rounded tinted square above every heading** (WIDE) | `div.rounded-lg.bg-primary/10 > svg` before each h3 | "The universal feature-list template" [S5]. "Iconitis" [S12] | Drop decorative icons. Keep only icons that carry meaning [S12] | **Script.** 3+ headings preceded by an icon-like sibling [S5]. Impeccable `icon-tile-stack` [S47] | HN 2 (podgietaru, dematz) | [S5] [S6] [S12] [S20] [S47] |
| **Lucide everywhere** | `lucide-react` as the only set, at default stroke and size | shadcn made Lucide its default. Advice: "avoid the default Lucide icons" [S39] | A set that matches the brand (Phosphor, Iconoir…), or custom icons [S39] | **Both.** Detect the dependency. A reviewer decides | HN 2 (EForEndeavour, jjcm) | [S13] [S20] [S39] |
| **Sparkles ✨ to mean "AI"** | ✨ next to AI features or before muted text | Ambiguous meaning [S38]. "The telltale sign of 'buttons not to click'" (ajkjk, HN [S33]) | Label what the feature does | **Script** (emoji/icon name `Sparkles`) | HN 4 (ajkjk, eddythompson80, NicuCalcea, 40four); Jim Nielsen | [S23] [S25] [S33] [S38] |
| **No real imagery; CSS stand-ins for photos** | Text-only pages, or gradients and blobs where product shots belong | "The biggest tell is the lack of images." [S27] | Real product UI, photos, or an honest placeholder with a fixed aspect ratio [S11] [S19] | **Judge** (a script can count `<img>`/`<video>` against section count) | R 1+ | [S11] [S19] [S27] |
| **Stock "diverse team" imagery and generic alt text** | Stock alt such as "diverse team, professional" | Generic descriptions [S5] | Describe the actual image [S5] | **Script.** Grep alt text against a stock-phrase list [S5] | R 7 (stock illustrations) | [S5] [S16] [S26] |

#### 2.8 Copy and content

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Filler marketing verbs and headlines** (WIDE) | "Empower / Unlock / Transform / Elevate / Seamless / Supercharge your workflow", "Built for modern teams", "Scale without limits" | "Averages of every headline the model has seen" [S7]. The copy equivalent of the purple gradient [S9] | Specific claims, at least one number, said in the founder's voice [S7] [S9] | **Script.** A phrase lexicon (polydraft `buzzwords` [S20]). Flag sentences starting with Empower/Unlock/Transform [S9] | HN 4 (techpression, pennomi, lanewinfield, Bishonen88); R "hero section with gradient text that says 'transform your X'" [S27] | [S7] [S9] [S10] [S20] [S21] [S23] [S27] |
| **"It's not just X — it's Y", em dashes, "load-bearing"** | Those constructions in UI and marketing copy | Satirised by Slopstrap [S23]. "Em dashes throughout the content" [S31] | Plain declarative sentences | **Script** for the patterns. **Judge** in context (many humans use em dashes) | HN 4+ in design threads (wbnns, Wpnx330, readthenotes1, EForEndeavour) | [S23] [S31] [S29] |
| **Explaining the obvious; walls of helper text** | Descriptions under every control. Section intros that repeat the heading | "Claude's just littering the screen with explanations that don't make sense" (trueno [S48g]). "Redundant information" [S5] | Cut the subhead, or make it add information [S5] | **Script.** Heading/next-sibling word overlap above 40% [S5]. **Judge** the rest | HN 3 (roundabout-host, trueno, lanewinfield) | [S5] [S12] [S29] [S31] |
| **Meta strings and arrows** | "A · B · C" metadata, "WORD — fragment" labels, "→" appended to every link or button | Anthropic "template chrome" [S2] | Write the labels plainly | **Script.** Grep for ` · ` joins, ` — ` in labels, and trailing `→` in buttons and links | HN 1 (lanewinfield: "Eyebrows like 'Newer demos · newest first'") | [S2] [S48i] |
| **Fake social proof: testimonials, names, round-number stats** (WIDE) | "Sarah Chen, CEO", "John Doe", "Acme", pravatar avatars, "10,000+ users", "▲ +420%" | Fabricated, which erodes trust. The Slopstrap examples are fake by design [S23] | Real customers or nothing. Exact figures [S10] | **Script.** Name, avatar-URL and brand lexicon (polydraft `stock-proof` [S20]). Flag round numbers with "+". **Judge** whether it is real | HN 3 (NewsaHackO, nojs, Bishonen88) | [S10] [S20] [S23] [S5] |
| **Placeholders left in** | Lorem ipsum, "Coming soon", "[Insert…]", TODOs, `<!-- Main Content -->` comments | Unfinished scaffolding [S5]. Section comments are a "Claudeism" (RomanHauksson [S48j]) | Write real copy. Strip the scaffolding comments | **Script.** Grep [S5] | HN 2 (RomanHauksson, roundabout-host) | [S5] [S10] [S19] [S48j] |
| **Generic CTAs and labels** | "Learn More / Get Started" 3+ times. "Submit / OK / Click here". "Something went wrong" | "Write action labels specific to each context" [S5]. Verb plus object [S12] | "Create account", "Save changes". Errors that say what failed and how to fix it [S12] | **Script.** Lexicon counts [S5] [S12] | — | [S5] [S12] [S16] |

#### 2.9 Motion

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Fade-and-slide-up on every section; hover lift on every card** (WIDE) | `whileInView` / `IntersectionObserver` fade-up on all sections. `hover:scale-105` or a lift on all cards | Anthropic: these "are the generic default and read as AI-generated" [S2]. "Content fades in as you scroll" (insin, HN [S48k]) | One orchestrated moment, with motion that responds to user actions [S2] [S3] | **Script.** Count elements with scroll-reveal hooks or classes. Flag when they cover more than about 50% of sections | HN 7 (jstanley, sph, insin, RomanHauksson, vouaobrasil, sheo, dawnerd); R 34 | [S2] [S3] [S7] [S10] [S12] [S26] |
| **Bounce/elastic easing** | `cubic-bezier` with y2 of 1.3 or more, `animate-bounce`, spring overshoot | "Dated overshoot effects" [S5] | ease-out / ease-in-out, short durations [S5] | **Script** [S5]. Impeccable `bounce-easing` [S47] | — | [S5] [S12] [S47] |
| **`transition-all`; animating layout properties** | Transitions on width, height, top or margin | Animates unintended properties [S5]. Causes jank [S12] | Animate transform and opacity only [S10] | **Script.** Grep [S5] [S12] | — | [S5] [S10] [S12] |
| **Always-on motion** | Pulsing dots, marquees, count-up stats, bouncing arrows | "Stop motion when nothing changes" [S10] | Static by default | **Script.** Infinite animations | HN 2 (LoganDark on late-popping content; lxgr on the blinking dot) | [S10] [S23] [S29] |
| **No `prefers-reduced-motion`** | No reduced-motion media query in a codebase that has motion | Part of Anthropic's quality floor [S2]. Fixed in the thoughtbot audit [S15] | Disable non-essential motion under that query | **Script.** Grep | — | [S2] [S15] |

#### 2.10 UX states and behaviour

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Happy path only: missing empty, loading and error states** (WIDE) | Lists with no empty state, spinners or nothing while loading, no error boundary | "The demo always has data" [S7]. A blank whole-app crash with no fallback [S37] | Design the unhappy paths. Empty states that invite action. Plain-language errors [S7] [S12] | **Both.** For each data-fetching component, check for loading, error and empty branches; grep for error boundaries. A reviewer judges quality | — | [S7] [S10] [S12] [S16] [S18] [S37] |
| **Missing hover, focus, active and disabled states** (WIDE) | Buttons and inputs with no `:focus-visible`, identical states | Makes keyboard use hard [S17] | Design all five states [S10] | **Script.** Interactive elements without focus-visible styles. Impeccable `focus-visible` rule [S47] | — | [S2] [S10] [S17] [S47] |
| **Non-functional UI: fake status, forms that do nothing, dead buttons** (WIDE) | `onClick` handlers that are empty or only `console.log`. A form whose "thanks" message is shown without a request. A status dot not bound to data | Hallmark bans "a form that shows 'thanks' without sending anything" [S24]. Slopstrap: "Blinking status dots connected to no backend" [S23]. Silent failures [S37] | Wire it, or remove it | **Both.** Static analysis for empty or no-op handlers and submit handlers with no network call. **Judge** the rest | HN 2 (markdown and rf15 on contact forms "into the void") | [S23] [S24] [S37] |
| **Disabled button as the only validation** | Empty submit is blocked only by greying out the button, with no message | Seen in 3 of 6 tested apps [S37] | Inline validation messages | **Both** | — | [S37] |
| **Everything visible at once** | Every panel and tool shown regardless of the user's step | The model "assumes users might need everything" [S7] | Progressive disclosure [S7] | **Judge** | — | [S7] |
| **Inconsistent styles across pages ("design drift")** | One page purple-gradient, another different. Several primary-button styles | Breaks consistency (MatveyF, HN [S48l]). Ban list: "Every component looks like a different design system" [S10] | One token source [S17] | **Script.** Cluster button and colour styles across pages | HN 2 (MatveyF, fibonachos: "I mostly wish I could get Claude and friends to use a consistent style") | [S10] [S17] [S29] |

#### 2.11 Accessibility

| Pattern | How to recognise it | Why it reads as slop | Better alternative | Detect | Humans | Sources |
|---|---|---|---|---|---|---|
| **Low contrast** (WIDE) | See §2.1. An AIM score of 2.7/10 on an audited vibe-coded site [S15] | Legal exposure under the EAA, the UK Equality Act and the ADA [S15] | 4.5:1 for body text [S14] | **Script.** axe-core or similar on rendered pages [S43] | HN 8+ | [S15] [S14] [S43] [S30] |
| **Missing or broken labels and alt text** | 12 label issues on one audited site [S15] | Fails screen readers | Associated labels, descriptive alt [S15] | **Script** (axe) | — | [S15] [S17] [S43] |
| **Hover-only interaction; no visible focus** | Tooltips and menus that need hover | Breaks touch and keyboard use [S10] | Every interaction works without hover [S10] | **Script** (partial) | — | [S2] [S10] |
| **Display headings too long; tiny display type** | h1 wrapping to 5–6 lines. Display fonts under 24px | Ban-list blockers [S10] | Under 4 lines, 32px or more [S10] | **Script.** Rendered line count | — | [S10] |

#### 2.12 Process and code-level tells (useful as context, low weight)

| Pattern | Recognise | Detect | Sources |
|---|---|---|---|
| Very long utility class strings and inline styles | Class attributes over 200 characters. Inline styles over 100 characters | **Script** [S5] | [S5] [S48m] (gavb quotes one 300-character class string) |
| Builder fingerprints | `cdn.gpteng.co` asset URLs (Lovable) | **Script** [S13] | [S13] |

#### 2.13 Disagreement: patterns people defend

- **"These are pre-AI SaaS patterns, not AI patterns."** "What this article calls AI design traits are design patterns that were already very common before AI… You can blame most of them on TailwindUI and shadcn" (nomdep [S48n]). "These alleged vibe coded websites look identical to all the tech startup websites of the 2010s" (lispisok [S32]). Bootstrap analogies come from madrox [S32] and a Reddit commenter [S27].
- **"AI defaults beat many human sites."** "At least the AI slop designs have decent contrast and font sizes" (robbles). g-b-r disputes this in the same thread: "they typically have minuscule font sizes" [S29]. Others: "It's nice to get some decent typography and white spacing" (jaggs [S48o]), and "AI-generated look-feel… is basically fine" (tptacek [S30]).
- **Defended individual traits:**
  - Inter: "a very good typeface" (r/ClaudeAI [S27])
  - The slop fonts: "they are popular for a reason" (flexagoon [S30])
  - Left borders: kykat, richard_chase [S30], merelysounds ("fine in moderation and in the right place") [S29]
  - Bento and rounded corners: "leave Bento grids and rounded corners alone" [S27]
  - Glassmorphism and dark mode [S27]
  - Purple as a colour [S27]
- **"Be different" is not a goal in itself.** "Users benefit when their software fits-in with platform conventions" (DaiPlusPlus [S48p]). codemyspec notes familiar layouts work, so the goal is a deliberate choice [S21].
- **Prompting is said to fix it, or said not to.** "It's only generic when your prompt is generic." (r/vibecoding [S27]). Against that: anti-slop skills "all seem to converge on the same thing… unless you are extremely explicit" (mstkllah [S35]). A Reddit OP said "PROMPT BETTER" did not help across Lovable, v0 and Bolt [S28].

**What this means for unslopify:** treat single traits as weak signals and score combinations. Never flag a trait the repo's own design system declares on purpose.

---

### 3. What humans say, in their words

HN quotes are linked to the comment. Reddit quotes come via the dataset's quote bank [S27], which links each one.

- "these LLMs have a design vocabulary of like 15 traits. None of the websites they generate have every single trait, but they are composed of some subset of 10 such traits" (applfanboysbgon, HN [S34])
- "I tried to list all the traits I could think of: Orange/beige-ish colors, Rounded corners, Cards with a thin border, A thicker colored border on the left of cards, Serif font for headings, Monospace fonts for small text, Headings that often have an unnecessary subheading / pre-heading, Little badges, often with a 'status indicator' dot" (tao_oat, HN [S48q])
- "Most AI-generated sites have coopted the Inter font… a dark colour scheme, the rounded tiles, a container representing a macOS-styled terminal with code, and… divs that fade is as you scroll." (sph, HN [S48h])
- "Inter font, all caps section headers, Lucide icons, em dashes… bubble status badges (of course with all-caps 'IN PROGRESS' and 'COMING SOON' that mean the same thing)" (EForEndeavour, HN [S48r])
- "thick left border will become the visual 'you're absolutely right!'" (trueno, HN [S48g])
- "The slop standard now is Claude or whatever's small type sizing, serif fonts and beige / tan color schemes" (ChrisArchitect, HN [S29])
- "The number of dark-mode sites I've seen where the text (and subtext) are various shades of dark brown or beige is just awful." (vunderba, HN [S30])
- "Fonts are too small, secondary fonts have terrible contrast… overuse of blinking/glowing status dots, overuse of bordered elements, and overuse of accented elements." (meshweaver, HN [S48d])
- "it's the 'brokenness' aspect of AI generated UIs that annoys me: single word buttons that are so narrow that the word is split across two lines, or text boxes with zero padding" (sourweasel, HN [S48f])
- "Both have the same identical and unmistakable AI design with pills and tags and highlights and icons and all that." (nlh, HN [S32])
- "This style of site uses 1/3 of the page to display 3 icons." (podgietaru, HN [S32])
- "the purple-to-blue gradient is the biggest tell lol." (r/ClaudeAI [S27])
- "Purple gradients and the urge to put a box around everything." (r/ClaudeAI [S27])
- "Black background, neon and lime green text. Inter font. 3 cards with thick border on left only." (r/ClaudeAI [S27])
- "The border on one side of a rounded corner card is so annoying." (r/ClaudeAI [S27])
- "the inter font gradient CTA combo is basically a fingerprint at this point" (r/ClaudeAI [S27])
- "Emojis as icons. If I see them, I instantly doubt the creators ability to even vibe-code properly." (r/ClaudeAI [S27])
- "Tiny text, lots of whitespace, grey on dark grey making it unreadable." (r/ClaudeAI [S27])
- "use tweakcn. generic default shadcn themes are just as bad as the purple gradient AI slop" (r/cursor [S27])
- "What triggers me is the grow animation on hover." (r/ClaudeCode [S27])
- "I have used skills like impeccable, ui-ux-max, and many, many others and they all seem to converge on the same thing." (mstkllah, HN [S35])

**Scale of the conversation.** In the Reddit dataset, "screams AI / slop" and "all looks the same" each appear in about 6% of the 3,033 on-topic comments. The feature tells rank in this order: shadcn/Tailwind defaults (76), purple (71), gradients (60), animations (34), rounded/pill (23), dark + glow (22), emoji (16), Inter/Geist (13), three cards (13), glass (7), two-button hero (7), centred (7), bento (4) [S26]. On HN, Krebs found 22% of 1,590 Show HN pages hit 4 or more of his patterns [S22].

---

### 4. Existing tools, skills and prompts

| Tool | URL | What it does | What to learn or reuse | Licence |
|---|---|---|---|---|
| **Anthropic frontend-design skill** | [S2] | Prompt guidance: subject first, a tokens plan, a calibration list of named clichés (cream/terracotta, acid green on black, broadsheet, the SaaS-card kit, template chrome), and a quality floor (responsive, focus, reduced motion, accessibility). The `<frontend_aesthetics>` system prompt [S4] [S3] | Its point that **naming specific looks** works better than "avoid AI look", and that all these traits "are defaults rather than choices" which are legitimate for some briefs. Reuse the calibration list as judgement prompts | Apache-2.0 (LICENSE.txt in the skill folder; anthropics/skills repo has no top-level licence) |
| **Impeccable** (pbakaus) | [S6] [S47] | 24 agent commands (critique, audit, polish…). A deterministic detector (`npx impeccable detect`) with about 60 rules over files or rendered URLs, with JSON, SARIF and GitHub annotation output. A hook that scans each UI file an agent edits. **It reads project tokens and DESIGN.md** (`project_tokens.rs`, `design_system.rs`) so it doesn't flag the repo's declared values | The closest prior art. Rule ids to mirror: `ai-color-palette`, `gradient-text`, `dark-glow`, `border-accent-on-rounded`, `side-tab`, `tracked-caps`, `kicker-above-heading`, `hero-eyebrow-chip`, `italic-serif-display`, `icon-tile-stack`, `flat-type-hierarchy`, `low-contrast`, `gray-on-color`, `bounce-easing`, `focus-visible` [S47]. We could call it rather than reimplement it. Its token and DESIGN.md allowlisting is the model for "respect the repo" | Apache-2.0 (about 116k stars) |
| **pixelslop** | [S5] | A published catalogue of 26 visual patterns with exact DOM/CSS thresholds and 16 source-grep patterns, plus a severity band (CLEAN 0–1, MILD 2–3, SLOPPY 4–6, TERMINAL 7+) | Thresholds are ready to port. Its scoring-by-count idea fits the "aggregate" finding. Its notes list two bugs in its own snippets, so port the logic, not the code | npm package; check the licence before copying code |
| **Hallmark** (Nutlope) | [S24] | Pre-flight reads the project's fonts, palette, framework and a locked `design.md`. Redesign, "keep the layout" (restyle only) and "polish" (fix tells only) modes. `audit` only reports. Keeps a log of past builds and fails a run that repeats recent structures or themes [S35] | **Scoped fix modes** and **anti-repetition memory** to avoid swapping one look for another. The browser lint plus a fresh-context reviewer | MIT |
| **Taste Skill** (Leonxlnx) | [S19] | Classifies the business, deals palettes and type pairings per trade from JSON libraries, a headless-Chrome checker at 5 widths, a copy linter, a finish gate with up to 3 fix rounds | Multi-width render checks and a gate loop. Palettes chosen by trade rather than freely | MIT |
| **JCarterJohnson/vibecoded-design-tells** | [S26] [S27] | Reddit-mined ranking of tells with scripts, CSVs and quote banks with permalinks | Use it to weight checks by how much humans notice them | MIT for the code; Reddit text belongs to its authors |
| **Laith0003/ux-skill ban list** | [S10] | About 80 banned patterns with blocker, major and minor severities, plus "meta-fingerprints" (combinations) | A severity model and combination fingerprints | No licence visible; use the ideas only |
| **Refero anti-ai-slop** | [S11] | 10 core patterns, including "reference averaging" and "token role drift" | **Token role drift**: check tokens are used for their stated role, which matters when fixing within a design system | Repo licence not checked; use the ideas only |
| **wystack agent-kit anti-patterns** | [S12] | 33 named anti-patterns with detection hints, including UX-writing rules (vague errors, blame copy, OK/Submit) | The copy and UX-writing checks | npm; check before copying |
| **polydraft sameness linter** | [S20] | About 140 lines of stdlib Python, regex only, 10 weighted rules (total 100), per-file `sameness-lint-disable` comments | A cheap first pass. Suppression comments let users keep a deliberate choice | Not stated |
| **uislop** (Go CLI) | [S13] | Fetches a URL plus its JS, regex signals, scores 0–100. Reports Geist false positives | Scoring output format. URL mode | Not stated |
| **Krebs Show HN scorer** | [S22] | Playwright plus deterministic DOM/CSS checks for about 16 patterns, roughly 5–10% false positives | Evidence that rendered-DOM checks are accurate enough | Source on GitHub (per post) |
| **Slopstrap** | [S23] | A satirical CSS framework of every trope, with an "agents" page listing them. HN users plan to use it "as an anti-style guide" | A ready negative-example gallery for reviewer calibration | Not checked |
| **Design-token linters** | [S40] [S41] [S42] | `stylelint-declaration-strict-value` requires variables for chosen properties. Mozilla `use-design-tokens`. `rhythmguard` enforces a spacing scale for CSS and Tailwind | The spacing and colour "off-token" checks already exist. Wrap them rather than rewrite them | Open-source npm packages |
| **axe-core / Deque** | [S43] | Automated accessibility checks on rendered pages, including contrast and labels | The accessibility floor. Repo: https://github.com/dequelabs/axe-core | MPL-2.0 (GitHub API) |

---

### 5. What an `unslopify` command needs

#### 5.1 Pipeline

1. **Read the repo's design system first.** Look for tokens: CSS custom properties, `tailwind.config`/`@theme`, shadcn `components.json`, `DESIGN.md`/`design.md`, Style Dictionary or other token JSON. Hallmark [S24] and Impeccable [S47] both do this.
   - Build an allowlist of declared colours, fonts, radii, spacing and shadows.
   - Anything declared on purpose is **not slop by itself**, even if it is Inter or purple. Report it at most once as "your system's own choice" and don't auto-change it.
2. **Run source checks** (fast, no browser). These cover the "Script" rows above.
3. **Run rendered checks** with Playwright at 390, 768 and 1440px. Use computed styles for contrast, font sizes, centring ratio, card uniformity, hero shape, button hierarchy, scroll-reveal coverage, emoji in headings and broken wrapping. Krebs [S22] and pixelslop [S5] show this works at roughly 5–10% false positives.
4. **Score combinations, not single hits.** Use pixelslop-style bands [S5]. Only call a page "slop" at about 4 or more co-occurring patterns, matching Krebs' "high" tier [S22]. Weight each pattern by human salience, using the Reddit and HN counts in §2.
5. **Run a reviewer agent** for the "Judge" rows. Give it screenshots plus the brief, the design system, and the calibration lists from Anthropic [S2] and Slopstrap [S23]. Use a fresh context, as Hallmark does [S24].
6. **Fix in scoped modes** (from Hallmark [S24]):
   - `audit`: report only
   - `polish`: fix tells within the existing system; the default
   - `restyle`: change tokens, keep layout and content
   - `redesign`: explicit opt-in only

#### 5.2 Script checks (deterministic)

- **Colour**
  - Gradient stops in the violet/indigo/blue band (hue 230–320°, saturation above 40%).
  - Tailwind `from-/via-/to-(purple|violet|indigo|fuchsia)` and `bg-(indigo|violet|purple)-[5-7]00` [S9].
  - Indigo hexes such as `#6366f1`, `#8b5cf6`, `#7c3aed` used as the primary [S11].
  - `background-clip:text` on headings or metrics.
  - Pure #000/#fff body backgrounds.
  - Saturated glows on a dark body.
  - The cream + terracotta pair (background near `#F4F1EA` with an accent near `#D97757`) [S2].
  - More than about 5 untokenised accent hues.
- **Type**
  - Body and heading both in the generic list.
  - Second-wave fonts as a weak signal.
  - Tracked uppercase kicker before a heading.
  - A one-word style or colour switch inside an h1/h2.
  - Monospace outside code.
  - Fewer than 3 weights, or near-duplicate sizes.
  - Body text under 16px or CTA text under 14px [S15].
- **Spacing**
  - Lengths not in the repo scale. With no scale, lengths not divisible by 4.
  - Tailwind arbitrary values such as `p-[13px]` or `gap-[22px]`. Wrap stylelint-declaration-strict-value or rhythmguard [S40] [S42].
  - 2 or fewer unique section paddings [S5].
  - One radius on more than 80% of rounded elements, or `rounded-(2xl|3xl)` everywhere [S9].
- **Layout**
  - The pixelslop hero "4 of 5" check plus two CTAs of equal weight [S5] [S10].
  - 3+ equal sibling cards with an icon-first structure.
  - Nested cards.
  - More than 6 card containers.
  - More than 70% of text centred.
  - A stat row of numeric nodes.
  - 01/02/03 markers.
  - Canonical section order.
- **Components**
  - Unmodified shadcn default variables.
  - One-side borders 3px or wider with other sides under 2px, on rounded boxes.
  - Pulsing dot plus pill.
  - Button style uniformity above 0.6.
  - More than 2 modals.
  - Traffic-light terminal mock.
  - Small decorative SVG sparklines.
- **Effects**
  - `backdrop-filter` 3 or more times.
  - Same shadow on more than 4 boxes.
  - Blurred orbs.
  - Animated `conic-gradient`.
- **Icons**
  - Emoji in headings, buttons and nav (exclude ★ and similar) [S20].
  - Icon-in-tinted-square before 3+ headings.
  - Lucide as the only set (weak signal).
  - Sparkles next to AI features.
- **Copy**
  - Buzzword lexicon (Empower, Unlock, Transform, Elevate, Seamless, Supercharge, "Built for modern teams").
  - "It's not just X — it's Y".
  - Generic CTAs used 3+ times.
  - OK/Submit/Click here.
  - "Something went wrong".
  - Lorem ipsum, TODOs and `<!-- Section -->` comments.
  - Stock names, pravatar avatars, Acme, round "10,000+" stats.
  - ` · ` meta joins and trailing `→`.
- **Motion**
  - Scroll-reveal on more than half the sections.
  - `hover:scale` on every card.
  - Bounce or overshoot easing.
  - `transition-all`.
  - Transitions on layout properties.
  - Infinite animations.
  - No `prefers-reduced-motion`.
- **States and accessibility**
  - axe-core run.
  - Missing `:focus-visible` styles.
  - Data components with no loading, error or empty branch.
  - No error boundary.
  - Empty or no-op click handlers.
  - Submit handlers with no request.
  - Hero at 100vh on mobile.

#### 5.3 Reviewer (judgement) checks

- Does the page open with something from the subject's own world, or with the generic hero [S2]?
- Is any gradient, glow, badge, dot, border stripe or number carrying meaning that can be stated in one word [S11] [S8]?
- Are the testimonials, logos, stats and status indicators real and wired to something [S23] [S24]?
- Is there one clear primary action per view [S12]?
- Is the hierarchy visible: what is biggest, closest and heaviest [S7]?
- Does the copy say anything only this product could say [S7] [S9]?
- Are the unhappy paths designed (empty, loading, error, invalid input) [S7]?
- Is everything shown at once when progressive disclosure would serve better [S7]?
- Does the fixed section order fit this content [S9]?
- Is the design consistent across pages [S10]?
- Does it fit the platform's conventions where that helps users [S48p]?

#### 5.4 Fixing without destroying the design system

- **Never introduce raw values.** Every fix must use an existing token. If no token fits, propose a new token in the token file and use it, so the system grows rather than forks. Refero's "token role drift" check applies: a CTA-only accent must not become a background [S11].
- **Allowlist the repo's declared choices.** A purple brand token or Inter declared in `DESIGN.md` is intent. Impeccable reads DESIGN.md and project tokens for exactly this reason [S47]. Support per-file or per-line suppressions, as polydraft does [S20].
- **Prefer subtraction to substitution.** Most fixes are removals:
  - drop the eyebrow, the one-side stripe, the decorative icon tile, the glow and the scroll fade [S12]
  - flatten nested cards
  - demote a second CTA to secondary
  - cut the redundant subhead
  
  Removing a default can't add a new default.
- **Scope by mode.** `polish` fixes tells only and never changes palette, fonts or layout. Palette and font changes need `restyle` and an explicit yes. That follows Hallmark's modes [S24].
- **Fix states and accessibility first.** They are objective, have no taste risk, and carry legal weight [S15].

#### 5.5 Avoiding swapping one generic look for another

- **Don't encode "anti-purple" as "use cream/serif/terracotta".** Anthropic itself now lists that look as a tell [S2]. HN users name it the current slop [S29] [S30]. codemyspec warns anti-slop prompts just move output to another cluster [S21].
- **Ban specific named looks rather than "the AI look".** Anthropic's guidance names specific defaults for this reason [S2]. Treat the whole calibration list as off-limits unless the brief or repo chooses one: purple gradient, cream/terracotta, acid green on black, broadsheet hairlines, the SaaS-card kit and template chrome.
- **Derive choices from the subject and the repo, not from a house style.** Anthropic: "visual choices should come from the subject's industry and vernacular" [S2]. Taste Skill deals palettes per trade [S19].
- **Keep memory across runs.** Hallmark logs past builds and fails a run that repeats recent themes or structures [S35]. unslopify should log what it changed per repo, and refuse to apply the same replacement font or palette it applied in other recent repos.
- **Re-run the detector on the fix.** A fix that scores slop under the newer patterns (cream/serif, left border, eyebrows) fails.

---

### Sources

- [S1] Anthropic, "Improving frontend design through Skills": https://claude.com/blog/improving-frontend-design-through-skills
- [S2] Anthropic `frontend-design` SKILL.md: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md (licence: https://raw.githubusercontent.com/anthropics/skills/main/skills/frontend-design/LICENSE.txt)
- [S3] Anthropic cookbook, prompting for frontend aesthetics: https://platform.claude.com/cookbook/coding-prompting-for-frontend-aesthetics
- [S4] Anthropic, Prompting best practices, "Frontend design": https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- [S5] pixelslop AI Slop Pattern Catalog: https://cdn.jsdelivr.net/npm/pixelslop@0.3.8/dist/skill/resources/ai-slop-patterns.md
- [S6] Impeccable: https://github.com/pbakaus/impeccable
- [S7] Kosta Canatselis, "Spot the slop": https://world.hey.com/kostac/spot-the-slop-a-ui-designer-s-guide-to-fixing-ai-defaults-4c448c9c
- [S8] Noqta, AI design slop patterns: https://noqta.tn/blog/ai-design-slop-overused-ui-patterns-fix-2026
- [S9] Alan West, "How to fix the AI-generated look": https://dev.to/alanwest/how-to-fix-the-ai-generated-look-in-your-frontend-1ahh
- [S10] Laith0003 ux-skill, Anti AI slop ban list: https://github.com/Laith0003/ux-skill/wiki/Anti-AI-slop-ban-list
- [S11] Refero anti-ai-slop reference: https://raw.githubusercontent.com/referodesign/refero_skill/f78b4eccf112d7a179b92afeafdd7e8684560ac2/references/anti-ai-slop.md
- [S12] wystack agent-kit anti-patterns: https://cdn.jsdelivr.net/npm/@wystack/agent-kit@0.12.0/wystack-agent-kit/references/anti-patterns.md
- [S13] Alexander Mia, uislop Go CLI: https://dev.to/alexander_mia_9/i-got-sick-of-my-claude-code-ui-slop-so-i-crystallized-it-into-a-go-cli-2hni
- [S14] "AI purple problem": https://dev.to/jaainil/ai-purple-problem-make-your-ui-unmistakable-3ono
- [S15] thoughtbot, "Your vibe coded website is going to get you fined": https://thoughtbot.com/blog/your-vibe-coded-website-is-going-to-get-you-fined
- [S16] Built In, "AI Makes Bad Design Look Good Enough": https://builtin.com/articles/ai-design-slop-era
- [S17] "7 visual bugs AI code generators always ship": https://dev.to/oqa/vibe-coding-problems-7-visual-bugs-ai-code-generators-always-ship-37mf
- [S18] "Why your AI keeps building the same purple gradient website": https://prg.sh/ramblings/Why-Your-AI-Keeps-Building-the-Same-Purple-Gradient-Website
- [S19] Taste Skill: https://github.com/Leonxlnx/taste-skill
- [S20] polydraft sameness linter: https://dev.to/polydraft/every-vibe-coded-site-looks-the-same-i-wrote-a-linter-for-the-default-look-2g0p
- [S21] CodeMySpec, "Why vibe coded websites all look the same": https://codemyspec.com/blog/vibe-coded-websites-look-the-same
- [S22] Adrian Krebs, scoring Show HN pages for design slop: https://www.adriankrebs.ch/blog/design-slop/
- [S23] Slopstrap: https://slopstrap.mikelacher.com/ and https://slopstrap.mikelacher.com/agents/
- [S24] Hallmark: https://github.com/Nutlope/hallmark
- [S25] Jim Nielsen, "The AI Aesthetic": https://blog.jim-nielsen.com/2026/ai-aesthetic/
- [S26] Reddit-mined tells dataset: https://github.com/JCarterJohnson/vibecoded-design-tells (counts: https://raw.githubusercontent.com/JCarterJohnson/vibecoded-design-tells/HEAD/unslop-ai-ui/comment_tell_counts.csv)
- [S27] Its Reddit quote bank with permalinks: https://raw.githubusercontent.com/JCarterJohnson/vibecoded-design-tells/HEAD/unslop-ai-ui/comment_tell_examples.md (main thread quoted: https://reddit.com/r/ClaudeAI/comments/1s6mm8o/what_are_dead_giveaways_for_ai_slop_websites/)
- [S28] Duply, "what Reddit actually says": https://duply.ai/blog/why-ai-generated-apps-look-the-same-reddit
- [S29] HN, Slopstrap thread: https://news.ycombinator.com/item?id=50576012
- [S30] HN, "Scoring Show HN submissions for AI design patterns": https://news.ycombinator.com/item?id=47864393
- [S31] HN, Ask HN, how can you tell a site is vibe coded: https://news.ycombinator.com/item?id=49290499
- [S32] HN, "Every vibe-coded website is the same page": https://news.ycombinator.com/item?id=45622944
- [S33] HN, "The AI Aesthetic" thread: https://news.ycombinator.com/item?id=49117099
- [S34] HN, joinedanthropic.com thread (design comments): https://news.ycombinator.com/item?id=48931588
- [S35] HN, Hallmark thread: https://news.ycombinator.com/item?id=49058547
- [S36] HN, "What's with the Wargames-like UX lately?": https://news.ycombinator.com/item?id=47774003
- [S37] TestMu AI, vibe coding risks (6 apps tested): https://www.testmuai.com/blog/vibe-coding-risks/
- [S38] NN/g, the AI sparkles icon problem: https://www.nngroup.com/articles/ai-sparkles-icon-problem/
- [S39] Tomilola on X, avoid default Lucide and shadcn grey: https://x.com/tomilola_ng/status/2080615247686017170
- [S40] stylelint-declaration-strict-value: https://npmjs.com/package/stylelint-declaration-strict-value
- [S41] Mozilla stylelint `use-design-tokens`: https://firefox-source-docs.mozilla.org/code-quality/lint/linters/stylelint-plugin-mozilla/rules/use-design-tokens.html
- [S42] rhythmguard spacing-scale stylelint plugin: https://dev.to/petrilahdelma/enforcing-your-spacing-standards-with-rhythmguard-a-custom-stylelint-plugin-1ojj
- [S43] Deque, "Vibe fixing": https://www.deque.com/blog/vibe-fixing-how-to-validate-ai-generated-code-and-achieve-accessibility-at-the-speed-of-ai/
- [S47] Impeccable detector source: rules https://github.com/pbakaus/impeccable/blob/HEAD/crates/core/src/checks/rules.rs, project tokens https://github.com/pbakaus/impeccable/blob/HEAD/crates/detect/src/project_tokens.rs, DESIGN.md handling https://github.com/pbakaus/impeccable/blob/HEAD/crates/detect/src/design_system.rs

**Individual HN comments**

- [S48a] jstanley: https://news.ycombinator.com/item?id=45551558
- [S48b] hankbond: https://news.ycombinator.com/item?id=49368848
- [S48c] lagrange77: https://news.ycombinator.com/item?id=50348572
- [S48d] meshweaver: https://news.ycombinator.com/item?id=49035980
- [S48e] loufe: https://news.ycombinator.com/item?id=49034935
- [S48f] sourweasel: https://news.ycombinator.com/item?id=50591995
- [S48g] trueno: https://news.ycombinator.com/item?id=50588193
- [S48h] sph: https://news.ycombinator.com/item?id=48932801
- [S48i] lanewinfield: https://news.ycombinator.com/item?id=50523668
- [S48j] RomanHauksson: https://news.ycombinator.com/item?id=47992825
- [S48k] insin: https://news.ycombinator.com/item?id=47656658
- [S48l] MatveyF: https://news.ycombinator.com/item?id=45295254
- [S48m] gavb: https://news.ycombinator.com/item?id=45763161
- [S48n] nomdep: https://news.ycombinator.com/item?id=47865416
- [S48o] jaggs: https://news.ycombinator.com/item?id=47825373
- [S48p] DaiPlusPlus: https://news.ycombinator.com/item?id=49330562
- [S48q] tao_oat: https://news.ycombinator.com/item?id=48932661
- [S48r] EForEndeavour: https://news.ycombinator.com/item?id=47668467

[S1]: https://claude.com/blog/improving-frontend-design-through-skills
[S2]: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md
[S3]: https://platform.claude.com/cookbook/coding-prompting-for-frontend-aesthetics
[S4]: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
[S5]: https://cdn.jsdelivr.net/npm/pixelslop@0.3.8/dist/skill/resources/ai-slop-patterns.md
[S6]: https://github.com/pbakaus/impeccable
[S7]: https://world.hey.com/kostac/spot-the-slop-a-ui-designer-s-guide-to-fixing-ai-defaults-4c448c9c
[S8]: https://noqta.tn/blog/ai-design-slop-overused-ui-patterns-fix-2026
[S9]: https://dev.to/alanwest/how-to-fix-the-ai-generated-look-in-your-frontend-1ahh
[S10]: https://github.com/Laith0003/ux-skill/wiki/Anti-AI-slop-ban-list
[S11]: https://raw.githubusercontent.com/referodesign/refero_skill/f78b4eccf112d7a179b92afeafdd7e8684560ac2/references/anti-ai-slop.md
[S12]: https://cdn.jsdelivr.net/npm/@wystack/agent-kit@0.12.0/wystack-agent-kit/references/anti-patterns.md
[S13]: https://dev.to/alexander_mia_9/i-got-sick-of-my-claude-code-ui-slop-so-i-crystallized-it-into-a-go-cli-2hni
[S14]: https://dev.to/jaainil/ai-purple-problem-make-your-ui-unmistakable-3ono
[S15]: https://thoughtbot.com/blog/your-vibe-coded-website-is-going-to-get-you-fined
[S16]: https://builtin.com/articles/ai-design-slop-era
[S17]: https://dev.to/oqa/vibe-coding-problems-7-visual-bugs-ai-code-generators-always-ship-37mf
[S18]: https://prg.sh/ramblings/Why-Your-AI-Keeps-Building-the-Same-Purple-Gradient-Website
[S19]: https://github.com/Leonxlnx/taste-skill
[S20]: https://dev.to/polydraft/every-vibe-coded-site-looks-the-same-i-wrote-a-linter-for-the-default-look-2g0p
[S21]: https://codemyspec.com/blog/vibe-coded-websites-look-the-same
[S22]: https://www.adriankrebs.ch/blog/design-slop/
[S23]: https://slopstrap.mikelacher.com/
[S24]: https://github.com/Nutlope/hallmark
[S25]: https://blog.jim-nielsen.com/2026/ai-aesthetic/
[S26]: https://github.com/JCarterJohnson/vibecoded-design-tells
[S27]: https://raw.githubusercontent.com/JCarterJohnson/vibecoded-design-tells/HEAD/unslop-ai-ui/comment_tell_examples.md
[S28]: https://duply.ai/blog/why-ai-generated-apps-look-the-same-reddit
[S29]: https://news.ycombinator.com/item?id=50576012
[S30]: https://news.ycombinator.com/item?id=47864393
[S31]: https://news.ycombinator.com/item?id=49290499
[S32]: https://news.ycombinator.com/item?id=45622944
[S33]: https://news.ycombinator.com/item?id=49117099
[S34]: https://news.ycombinator.com/item?id=48931588
[S35]: https://news.ycombinator.com/item?id=49058547
[S36]: https://news.ycombinator.com/item?id=47774003
[S37]: https://www.testmuai.com/blog/vibe-coding-risks/
[S38]: https://www.nngroup.com/articles/ai-sparkles-icon-problem/
[S39]: https://x.com/tomilola_ng/status/2080615247686017170
[S40]: https://npmjs.com/package/stylelint-declaration-strict-value
[S41]: https://firefox-source-docs.mozilla.org/code-quality/lint/linters/stylelint-plugin-mozilla/rules/use-design-tokens.html
[S42]: https://dev.to/petrilahdelma/enforcing-your-spacing-standards-with-rhythmguard-a-custom-stylelint-plugin-1ojj
[S43]: https://www.deque.com/blog/vibe-fixing-how-to-validate-ai-generated-code-and-achieve-accessibility-at-the-speed-of-ai/
[S47]: https://github.com/pbakaus/impeccable/blob/HEAD/crates/core/src/checks/rules.rs
[S48a]: https://news.ycombinator.com/item?id=45551558
[S48b]: https://news.ycombinator.com/item?id=49368848
[S48c]: https://news.ycombinator.com/item?id=50348572
[S48d]: https://news.ycombinator.com/item?id=49035980
[S48e]: https://news.ycombinator.com/item?id=49034935
[S48f]: https://news.ycombinator.com/item?id=50591995
[S48g]: https://news.ycombinator.com/item?id=50588193
[S48h]: https://news.ycombinator.com/item?id=48932801
[S48i]: https://news.ycombinator.com/item?id=50523668
[S48j]: https://news.ycombinator.com/item?id=47992825
[S48k]: https://news.ycombinator.com/item?id=47656658
[S48l]: https://news.ycombinator.com/item?id=45295254
[S48m]: https://news.ycombinator.com/item?id=45763161
[S48n]: https://news.ycombinator.com/item?id=47865416
[S48o]: https://news.ycombinator.com/item?id=47825373
[S48p]: https://news.ycombinator.com/item?id=49330562
[S48q]: https://news.ycombinator.com/item?id=48932661
[S48r]: https://news.ycombinator.com/item?id=47668467
