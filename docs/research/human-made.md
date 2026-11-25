# Human-made: a calibration set of sites that read as crafted by people

Research date: 2026-11-25

Companion to `ui-slop.md`. That file lists what reads as generated; this one collects sites that design publications, award juries and curated galleries hold up for craft. It is meant to calibrate a reviewer's sense of the feel, not to give them a look to copy.

## Method

- Sources: web searches for designer-portfolio round-ups, award galleries (site-of-the-day and annual awards), curated showcases and lists of influential designers. Each source was opened and its date recorded. Only sources from the last three years were used, with one exception (Maggie Appleton's list, undated, roughly 2024), which is marked as such.
- References: 42 candidate sites named by those sources were fetched with `curl` on 2026-11-25. The fetch recorded reachability, page title, meta description, the web fonts declared and the visible text. Each site was then loaded in a headless Chromium (Playwright) at 1280×1600. A screenshot of the first viewport was taken after about 3.5 seconds, and the computed font families were read from the page. Observations below come from that screenshot plus the page text and markup. Where the screenshot caught only a preloader, the note says so and the observations rest on the markup and text.
- Limits: one desktop viewport per site and no scrolling interaction; motion was not recorded, and mobile was not checked. Observations about motion come from markup (canvas and video counts) or page text. They are not watched behaviour. Three candidates were dropped because their content could not be observed (listed at the end of section 2).
- No designer was contacted, and no claim about who made a site goes beyond what the cited source states.

## 1. Sources

| # | Source | What it is | Date | URL |
|---|---|---|---|---|
| S1 | Colorlib, "web designer portfolios" | Round-up of 20 web designers' own sites, each with the reason it works; states every site was opened before inclusion | 2026-09-25 | https://colorlib.com/wp/web-designer-portfolios/ |
| S2 | Muzli, "100 Best Designer Portfolio Websites" (Eyal Zuri) | Ranked list of designer and studio portfolios | 2025-10-12 | https://muz.li/blog/top-100-most-creative-and-unique-portfolio-websites-of-2025/ |
| S3 | Typewolf, Site of the Day | Daily pick of a site chosen for its typography, with the typefaces named | entries Sep–Dec 2025 | https://www.typewolf.com/site-of-the-day |
| S4 | Siteinspire (curated by Daniel Howells) | Hand-curated web design gallery, with the designer credited per entry | entries Oct–Nov 2026 | https://www.siteinspire.com/ (curator: https://www.creativebloq.com/design/site-inspire-relaunch-offers-dev-lessons-1135862) |
| S5 | Maggie Appleton, "Design Engineers" | List of ten people whose public work blends design and engineering | undated ("planted over 2 years ago", so about 2024; not verified more precisely) | https://maggieappleton.com/design-engineers |
| S6 | Webby Awards, Best Visual Design – Aesthetic | Winners and nominees 2024–2026 | 2024–2026 | https://winners.webbyawards.com/winners/websites-and-mobile-sites/features-design/best-visual-design-aesthetic |
| S7 | Awwwards Annual Awards, winners | Site of the Year, E-commerce of the Year, Agency and Studio of the Year | 2025 awards | https://www.awwwards.com/annual-awards/winners |

Sources on the fuzzy boundary (used in section 3):

| # | Source | Date | URL |
|---|---|---|---|
| F1 | Vanessa Porter, "Everything looks the same. Now what?", Creative Bloq | 2026-06-06 | https://www.creativebloq.com/ai/everything-looks-the-same-now-what |
| F2 | Noah Davis, "AI Didn't Kill Web Design — Templates Did It First", Web Designer Depot | 2025-07-02 | https://webdesignerdepot.com/ai-didnt-kill-web-design-templates-did-it-first/ |
| F3 | Tanya Donska, "AI Makes Bad Design Look Good Enough", Built In | 2026-06-11 | https://builtin.com/articles/ai-design-slop-era |
| F4 | Shin, Gao, Pang, Lee, Reinecke, Tseng, "Interrogating Design Homogenization in Web Vibe Coding", arXiv 2603.13036 | 2026-03-13 | https://arxiv.org/html/2603.13036v1 |

## 2. References

39 sites kept. "Fonts" are the computed families the page rendered or the web-font files it declared on 2026-11-25. They are listed as evidence, not as a recommendation.

### Personal portfolios and designers' own sites

1. **Stuff & Nonsense**, https://stuffandnonsense.co.uk/. Made by Andy Clarke (his own studio). Named in S1.
   - The hero is a commissioned cartoon illustration of a row of cowboys in a desert. The service headings are hand-lettered: a script line over a condensed all-caps word.
   - The copy is specific: "my website design studio in North Wales", "almost thirty years", and a landline number with a WhatsApp option on the first screen.
   - A client logo row is present (Disney Store UK, Greenpeace Poland, WWF UK). It is a common pattern, set among very particular content.
2. **Kus—Studio**, https://mikekus.com/. Made by Mike Kus. Named in S1.
   - Hairline blueprint grid lines with plus-sign corner marks frame the hero. Small monospaced labels ("KUS-STUDIO", "FORM & FUNCTION", "20–25") sit in the corners.
   - The work is shown as real client mockups (posters and branding for named clients) right below the fold.
   - It uses Inter, Manrope and Geist Mono, faces the slop catalogue flags as defaults. The page still reads as authored because of the grid device and the work shown. The single testimonial is repeated in a marquee.
3. **Lynn Fisher**, https://lynnandtonic.com/. Made by Lynn Fisher. Named in S1, which notes her archive of past redesigns.
   - The homepage is a book-style table of contents with dot leaders and Roman numerals (I–VI), set in an antique display face (Sydonia Atramentiqua) on a paper-textured ground.
   - It carries the label "v. XIX", the nineteenth version of the site. The yearly redesign is part of the site's identity.
   - There are almost no other elements on the page.
4. **Dennis Snellenberg**, https://dennissnellenberg.com/. Made by Dennis Snellenberg. Named in S1.
   - The screenshot caught the preloader, a greeting cycling through languages ("Hello Bonjour स्वागत हे Ciao …" in the markup).
   - The page renders in "Dennis Sans", a face named for the site. The footer reads "© Code by Dennis Snellenberg".
   - S1 notes project pages state his role, link to live sites and credit collaborators. This was not checked page by page.
5. **Eva Sánchez**, https://evasanchez.info/. Made by Eva Sánchez. Named in S1.
   - The screenshot caught a large numeric preload counter ("090") with a small monospaced caption.
   - S1 says the site credits both its designer and the developer of the WordPress theme, and treats sound as equal to visuals in a case study. The credit was not seen in the captured viewport.
6. **Karim Saab — Playground**, https://karim-saab.com/. Made by Karim Saab. Named in S1 and S2.
   - The copy is unusually candid: "Portfolio under construction… Most of my work is UX and product, and it isn't on this page."
   - A pixel-noise WebGL background (one canvas) sits behind a torn-paper "PLAYground" lockup that mixes a heavy sans with a condensed serif.
   - It shows a dark ground with neon-tinted imagery, a palette the slop catalogue associates with generated pages. Here it does not read that way.
7. **Irene Butenko**, https://www.irene-butenko.com/. Made by Irene Butenko. Named in S1, which praises the awards table that links each claim to its source.
   - The screenshot caught a "100%" preloader bar.
   - The intro copy is generic ("I specialize in crafting user-centric designs that are visually striking and intuitive"). This is a counter-example within the set: an award-judged portfolio whose copy would not pass a voice test.
8. **Paco Coursey**, https://paco.me/. Made by Paco Coursey. Named in S5.
   - A narrow text column at small sizes, with no imagery and no hero. Söhne is paired with an italic serif (Newsreader) for single phrases ("Crafting interfaces", "everything around me is someone's life work").
   - The personal detail is specific: a "Now" paragraph about dance music, and the sign-off "Shine, constantly and steadily."
   - It is entirely restrained. The craft shows in the spacing, the alignment and the linked projects (⌘K, Next Themes), not in decoration.
9. **Emil Kowalski**, https://emilkowal.ski/. Made by Emil Kowalski. Named in S5.
   - A single left-aligned list of projects and essays in small grey sans, with no images.
   - The copy is first-person and plain: "Currently taking a break from work." The essay titles take positions ("You Don't Need Animations").
   - The markup records no web fonts, and the type renders in a system sans stack.
10. **Rauno Freiberg**, https://rauno.me/. Made by Rauno Freiberg. Named in S5.
    - A large bio sentence is set with staggered indents over a flat yellow circle, with a tick-mark scrubber at the top.
    - The page ends with a short manifesto: "Make it fast. Make it beautiful. … Make it soulful. Make it."
    - Interaction is the subject (S5 quotes him on "sound & interaction design"). It was not exercised in a static capture.
11. **Amelia Wattenberger**, https://wattenberger.com/. Made by Amelia Wattenberger. Named in S5.
    - A heavy display serif name (Parclo) runs a dark-green-to-teal gradient into the last letters. A hand-drawn flower sticker reads "this site is WIP / go to the old one".
    - The bio sets key phrases in bold italic ("create things on the web", "turn data into meaning").
    - The page has 29 video elements, mostly previews of her interactive essays.
12. **Steve Ruiz**, https://www.steveruiz.me/. Made by Steve Ruiz. Named in S5.
    - The blog index uses hand-drawn marker sketches as post thumbnails, made in his own drawing tool's style.
    - It is plain otherwise: Fira Sans, dated posts, narrow column.
13. **Bartosz Ciechanowski**, https://ciechanow.ski/. Made by Bartosz Ciechanowski. Named in S5.
    - Observed from markup and text only, because the headless load timed out. The latest entry is a long interactive article ("Moon", 17 December 2024) that opens in a narrating voice: "to experience that journey first-hand, we have to enter the cosmos itself."
    - The site is built around bespoke explanatory interactives, not a layout. S5 cites him for "blending design and engineering for educational content".
14. **Type Darkroom**, https://typedarkroom.com/. Made by Amanda Guo, a Parsons student project. Named in S4.
    - It is framed as a film strip: red ground, sprocket-like black blocks down both edges, and scanline type (Sixtyfour, Workbench) for the title.
    - The concept comes from the subject, typography as a darkroom process. The footer credits the designer, the course and every typeface used.

### Studios and agencies

15. **basement.studio**, https://basement.studio/. Named in S2; also the maker of the Daylight Computer store (S6, 2025 nominee).
    - The screenshot caught a black preloader with a small "HUMAN / MACHINE" toggle.
    - The voice is blunt: "We make cool shit that performs."
    - The type is Geist and Geist Mono, a common default face, used by a studio celebrated for craft.
16. **Drexler**, https://drxlr.com/. Named in S2.
    - A giant cropped "Dr" wordmark fills the black viewport and runs off the right edge.
    - The copy is specific: "A few skilled humans doing the work of many.™" It names a contact person and gives a street address in Baltimore with a phone number.
17. **Thingy & Thingy**, https://www.thingyandthingy.com/. Named in S2.
    - A full-bleed archival photograph of a 1970s couple is overlaid with "A MULTINATIONAL NETWORK OF IDIOTS" in condensed lime type.
    - The tagline is "INSPIRING BRANDS TO FART ABOUT A BIT". The irreverence is the brand, with no hedging.
18. **Studio Herrström**, https://www.studioherrstrom.com/. Named in S2.
    - Below a centred serif statement, the page is a mosaic of client tiles of mixed sizes (Spotify "Discover Weekly", Back Market), each in that client's own identity.
    - It uses custom families ("SH-SANS", "SH-MIX") and nine video elements.
19. **Studio Null**, https://www.madebynull.com/. Named in S2.
    - The screenshot shows a near-empty white page with a single faceted blue 3D pyramid and a live London clock ("London, 04:49:07").
    - It publishes prices and durations ("Landing page … 3–5 weeks … $13k+"), which is rare and concrete.
    - The About copy is generic agency language ("nimble, craft-focused multidisciplinary team creating delightful and compelling experiences"), a counter-example on voice.
20. **Reform Collective**, https://www.reformcollective.com/. Named in S2.
    - The screenshot caught a full red preloader with a heavy "REFORM CO" wordmark.
    - The copy has quirks ("All pinkies up, We live in the details!", "( Scroll Down Scroll Down )"). Editorial New and Founders Grotesk are mixed with a raster grotesk.
21. **Made Thought**, https://www.madethought.com/. Named in S4 (credit: Kaleido Grafik).
    - The capture is blank apart from a menu icon and a cookie bar; the content loads late. The markup has 159 images and 32 videos of client work. London and New York clocks ("00:00:00") appear beside the street addresses.
    - The serif and sans pairing (Futura PT with Items) is in the markup. Visual observation is limited.
22. **Immersive Garden**, https://immersive-g.com/. Webby 2025 winner, Best Visual Design – Aesthetic (S6); Awwwards Agency of the Year 2025 (S7).
    - The screenshot caught a plain grey loading state. The markup has six canvases, and the copy names real client work (Louis Vuitton VIA, a David Whyte poetry piece).
    - The headline copy is grandiose and generic ("Transcend anything seen or felt before"). Craft here is in the WebGL work, which a static capture cannot judge.

### Product, SaaS and app marketing

23. **Speakeasy**, https://www.speakeasy.com/. Named in S3 (Typewolf, 8 December 2025: Tobias, Diatype, Diatype Mono).
    - A light serif headline ("Securely scale your AI.") is paired with a mono UI face. Dithered, halftone renderings of a reaching hand are drawn for the page.
    - It also uses several patterns the slop catalogue lists: a "NEW …" pill above the headline, a "Trusted by" logo wall, and a primary plus secondary CTA pair. Typography and illustration are what separate it.
24. **Every**, https://every.to/. Named in S3 (Typewolf, 28 September 2025: Signifier, Switzer).
    - A newspaper-like three-column front page with bylines, dates and section names ("Context Window").
    - Commissioned illustrations combine classical statues with collage. The headlines swap single letters into an alternate italic glyph ("M ultitask", "W rite"), a typographic signature.
25. **Berry eReader**, https://berryreader.com/. Named in S4.
    - The hero is a soft-focus leaf shadow on a pale ground, with "Meet *Berry*, a calmer screen for reading" set in Literata, a reading face, for a reading app.
    - The page lets you try the product's own settings: Paper, Dusk and Ink themes and warmth, contrast and grain sliders. The sample text is real literature (Hesse's *Siddhartha*, Thoreau's *Walden*).
26. **!Boring Software**, https://www.notboring.software/ (redirects to notbor.ing). Made by Andy Allen. Named in S5.
    - A huge periwinkle "!BORING" wordmark sits over a grey band with "Most apps help you save time. We help you savor it 😊".
    - Product names follow a catalogue numbering ("APPx006", "SKNx009"). Artist-collaboration skins are credited by name (Eran Hilleli, Andy x Presstube).
    - S5 quotes Allen on drawing an accurate moon phase in code rather than using a static icon, an example of care invisible at first glance.
27. **Daylight Computer**, https://daylightcomputer.com/. Store by basement.studio; Webby 2025 nominee (S6).
    - The hero is a product photograph of the tablet lying on grass with fallen leaves, showing a botanical pencil drawing on its screen. The scene is shot for the product's "calm computer" claim.
    - A manifesto line is letter-spaced character by character ("We refuse to accept a future where our devices are exhausting, addictive, and distracting").
    - The type is ABC Room with Arizona Flare. Stock status is stated plainly ("In stock · Ships in 3-5 business days").

### Editorial, publishing and cultural institutions

28. **Stripe Press**, https://stripe.press/. Named in S4.
    - The homepage is a horizontal shelf of book titles, each set in that book's own cover typeface (italic serif, condensed sans and so on), on a warm grey ground.
    - The interface text is small mono brackets ("[ NEW & FEATURED RELEASES ]", "[ CART 0 ]"). It renders in Cardinal Fruit, Ivar Headline, Suisse and Suisse Mono.
    - There is also a plain note for AI agents pointing to `/llms.txt` and a catalogue JSON.
29. **Josef & Anni Albers Foundation**, https://www.albersfoundation.org/. Made by Bureau for Visual Affairs (S4).
    - "We exist to open eyes." in a light serif is followed by a staggered, off-grid arrangement of artworks. Each carries a museum-style caption (artist, italic title, year).
    - The design steps back so the artwork carries the page. It has a skip-to-content link.
30. **Collective Gallery**, https://www.collective-edinburgh.art/. Made by The Touch Agency (S4).
    - A photograph of the gallery's actual building, the City Observatory on Calton Hill, carries a heavy red condensed wordmark across its base.
    - Practical facts come first: opening hours by day, "Opens today at 10am", the full address and directions. Cabinet Grotesk is paired with PP Right Grotesk.
31. **MOXIE Theatre**, https://moxietheatre.com/. Made by REUNION (S4).
    - A full-width ultra-condensed wordmark fills the top. Below it sits a row of show posters, each with its own typographic treatment.
    - The voice is theirs ("UNAPOLOGETICALLY BOLD for voices that refuse to be silenced"), with real dates and playwrights' names. It uses a salmon-pink ground.
32. **LED Boise**, https://ledboise.com/. Made by Kyle Morck (S4).
    - Performance photographs are masked inside giant letterforms ("ART"). A yellow "THE RAT KING" card is set at a slight rotation. Ticket dates sit in a dark rounded panel.
    - The copy states place and purpose: "A group of artists and creatives translating movement, music, stories, and visuals into cinematic worlds. Boise · Garden City, ID".

### E-commerce

33. **Dirty Vine**, https://dirtyvine.com/. Named in S3 (Typewolf, 12 December 2025: Swear, DM Mono).
    - An age gate with a green flower mark sits over food photography. The headline is set in Swear, a display serif with sharp, quirky terminals.
    - Product listings name each producer and vintage ("Juliénas Bessay 2022, Sylvain Martel, $49.00"). Small words show the voice: "bevs", "good for the soul and good to the soil".
34. **KARO**, https://www.karocrafts.com/. Named in S2.
    - The loading screen is a winking smiley mark between bracketed labels ("[ NYC. EST. ] [ 2023 ]"). A blue progress line runs across the top.
    - The copy is personal and odd: "I live in my head / You live there too". It uses Helvetica and a custom "Nautica".
35. **Scout Motors**, https://www.scoutmotors.com/. Awwwards E-commerce of the Year 2025 (S7); maker not named on the winners page.
    - A full-bleed photograph of the actual vehicle on rock, with a line in the brand's voice ("Scouts always come back.").
    - Facts sit right beside the marketing: "Entry-model pricing expected to start under $60,000. Initial production targeted for 2027, subject to change." It uses a custom "scout-sans" family.

### Small business and hospitality

36. **Heart & Soil Flowers**, https://www.heartandsoilflowers.com/. Named in S3 (Typewolf, 13 December 2025: Cardinal, Sweet Sans, Baskerville).
    - A split layout: a dark-green panel with letter-spaced nav and a circular "INQUIRE NOW" stamp, beside the studio's own photograph of white wildflowers.
    - The copy names the founder (Kelsey) and real venues (Blue Hill at Stone Barns, Inness, Hudson Valley). One testimonial says "if … what you want doesn't exist on Pinterest yet, hire Kelsey."
37. **Chambres d'Amis**, https://chambresdamis.be/. Made by Salt&Bits (S4).
    - A high-contrast didone wordmark is split: "CHAMBRES" at top left, "d'AMIS" at bottom right, framing the restaurant's own food photography.
    - The copy names the chef and his son the sommelier and says "there are no tasting menus." It is trilingual (en, fr, nl), as a Kortrijk restaurant would need.
38. **Atera**, https://atera.spa/. Made by Theo Plawinski (S4).
    - The screenshot caught a dark loading veil, so the visual is not verified. The fonts declared are HW Atlantic and Lettera Text.
    - The copy carries place and an origin story: an address on Oswald Street, Glasgow, opening hours, "from 'terra', meaning land or earth", and "Below the city streets, time flows differently."

### Award showpieces (craft of a different kind)

39. **Lando Norris**, https://landonorris.com/. Awwwards Site of the Year 2025 (S7). The maker, OFF+BRAND, is named only in search-result snippets of Awwwards listings, not verified on the winners page.
    - Observed from markup and text only, because the headless load timed out. The markup has 21 canvases and 133 images, a custom face ("Brier"), and interface copy written for the subject ("Please rotate your device, This is a vertical drive", "tap to lock").

Dropped:
- **Igloo Inc** (https://www.igloo.inc/), Webby 2026 winner (S6). It returned 1.4 KB of markup and rendered only a loader glyph in the capture, so there was nothing to observe.
- **Grit Pictures** (https://grit.pictures/), from S2. `curl` received a bot-verification page, and the browser capture showed a black screen with a menu button.
- **Royal Sites of Ireland** (https://royalsites.ie/), from S4. The screenshot timed out, and the markup showed only splash and cursor scripts.

## 3. Synthesis

### Traits that recur

Counts are out of the 39 references kept. A site is counted only where the trait was seen in the screenshot or the page text; preloader-only captures were counted on text evidence alone. Counts are approximate and come from one viewport per site.

| Trait | Count | Examples |
|---|---|---|
| **Copy that is specific to this business or person**: names, places, prices, dates, an origin story, an opinion, a joke the owner would make. This is the most consistent separator. | ~27 | 1, 6, 8, 16, 17, 19 (prices), 25, 31, 33, 35, 36, 37, 38 |
| **Typefaces chosen for the subject, or custom**: a reading serif for a reader app, book-cover faces for a publisher, a didone for a French restaurant, scanline type for a type-process project, faces named after the owner | ~31 use a distinct licensed or custom family; ~8 rely mainly on Inter, Geist, Fira or system stacks (2, 7, 9, 12, 13, 15, and partly 8 and 11) | 3, 4, 14, 24, 25, 28, 33, 37 |
| **Imagery made for this site**: own photography of the product, venue, building or work; commissioned illustration; artworks; hand-drawn sketches. No stock "team at laptop" images. | ~22 | 1, 12, 24, 27, 29, 30, 31, 32, 36, 37 |
| **Composition that departs from centred hero, then feature-card grid**: cropped or split wordmarks, staggered grids, type masking photos, table-of-contents homepages, rotated cards | ~20 | 3, 10, 14, 16, 28, 29, 32, 36, 37 |
| **A visible author or people**: designer or chef credited, bylines, the founder named, a credits line for typefaces | ~16 | 4, 8, 14, 16, 24, 36, 37 |
| **An interaction or detail that only this site would have**: reader settings you can try, a multilingual hello loader, a HUMAN/MACHINE toggle, live city clocks, versioned redesigns, a vertical-drive scroll | ~14 | 3, 4, 15, 19, 21, 25, 39 |
| **Restraint**: very few elements, small type, no decoration, content carries the page | ~10 | 8, 9, 12, 25, 28, 29 |

Underneath most of these sits one idea: the design choices follow from the subject. Type, imagery and copy point back to what is being sold or shown. This fits F3's description of generated work as "technically correct in the same way that a hotel room is technically furnished… none of it is specific to anything" (https://builtin.com/articles/ai-design-slop-era).

### Where the references contradict each other, or the slop catalogue

- **Minimal and maximal both read as human.** Paco, Emil and Albers (8, 9, 29) are almost empty; Thingy & Thingy, MOXIE and LED (17, 31, 32) are loud. Visual density is not a signal either way.
- **"Default" fonts appear on crafted sites.** Mike Kus (Inter, Manrope), basement.studio (Geist) and Emil Kowalski (system sans) are all praised by S1, S2 and S5. A font list alone does not separate them from generated pages.
- **Catalogue patterns appear on curated sites.** Speakeasy (23, a Typewolf pick) has the "NEW" pill, a logo wall and a two-CTA hero. Stuff & Nonsense (1) has a client logo row. A logo row or a pill does not decide the matter; what decides it is everything around it.
- **Generic copy appears on award-praised sites.** Butenko (7), Studio Null's About text (19) and Immersive Garden's headline (22) use the vague, superlative language the catalogue flags in generated copy. People write that way too.
- **Preloaders and heavy WebGL.** About 11 of the 39 captures (mostly from S2 and the award sources) showed only a loader at 3.5 seconds. Award galleries reward this showpiece craft. A reviewer judging feel would see nothing in a first glance. It is craft, but of a kind that does not transfer to an app or a small-business page.

### Colour

Colour did not differentiate. The references cover dark with neon accents (6, 15, 16), saturated red (14, 20), salmon pink (31), periwinkle (26), warm paper beige (3, 28), deep green (36), cobalt and pink (32), and plain white or grey (8, 9, 12, 29). Several use combinations the slop catalogue associates with generated pages: dark plus neon, a purple-blue wordmark, gradient text in Wattenberger's name (11). None of that made them read as generated. The colour of a crafted site usually comes from its subject's own material: the client's identity (18), the product photograph (27), a building or artwork (29, 30). The subject-specificity trait above therefore covers colour without needing a separate palette check.

### Why the boundary is fuzzy

- Sameness predates AI. F2 argues that "Templates didn't just streamline web development. They rewired what people expect a website to be" and that "AI didn't templatify the web—we did" (https://webdesignerdepot.com/ai-didnt-kill-web-design-templates-did-it-first/). F1 says "The internet was already converging on a single aesthetic before AI arrived, and AI is its high-speed photocopier" (https://www.creativebloq.com/ai/everything-looks-the-same-now-what). A human-made template site and a generated page can therefore look the same.
- Generated pages are "correct". F3 notes that "The architecture is right, the hierarchy is right, the copy is clear" and that "The baseline for acceptable design has quietly shifted to whatever AI produces" (https://builtin.com/articles/ai-design-slop-era). No single rule a generated page breaks would catch it.
- The research names the mechanism but not the line. F4 describes homogenization as "a convergence toward the mean, dominant aesthetic" and says LLMs "tend to favor familiar, widely adopted patterns" (https://arxiv.org/html/2603.13036v1). It offers no operational definition or measure of distinctiveness (summary of the paper's first 100k characters; the remainder was not read).
- The references themselves show the overlap: generic copy on award winners, catalogue patterns on curated picks, default fonts on design engineers' sites (see contradictions above). A trait count can raise or lower confidence. It cannot settle a borderline case.

### Craft and taste

- **Craft** is execution that can be checked whatever the style: copy and imagery that are true to this subject, type set with care (spacing, measure, italics used for meaning, credits), a composition that holds together at its grid, real states and facts (hours, prices, stock, dates), skip links and readable sizes. Albers, Collective Gallery, Atera, Every, Speakeasy, LED and Scout all ship a skip-to-content link (seen in page text). A reviewer can judge craft against any style.
- **Taste** is the choice of style: minimal or loud, serif or grotesk, irreverent or solemn, dark or light, WebGL or plain HTML. The references disagree on every taste axis, so taste should not count as evidence of human or generated work. Only how consistently and deliberately a taste is carried through says anything.
- The traits in the table are mostly craft (specific copy, made-for-it imagery, credits, subject-led type). Composition departures and restraint sit between craft and taste.

## 4. Notes on use

- Use these references to calibrate a judgement: open a few, then look at the page under review and ask whether its choices come from its own subject the way these do. They are not a target look.
- Do not copy their surface. If a fix gives every page a split-didone wordmark, a film-strip frame or a book-title shelf, the result is a new sameness. F4's point about convergence toward a dominant aesthetic applies to converging on references just as much as on model defaults (https://arxiv.org/html/2603.13036v1).
- Most references were chosen by juries that reward showpieces (S2, S6, S7). For app UIs and ordinary business pages, weight the quieter references (8, 9, 25, 28, 29, 30, 36, 37) and the traits over the award winners.
- Never treat one trait as decisive, colour included. The counts above come from single-viewport captures on one date. Sites change, and several entries (4, 5, 7, 15, 19–22, 38) were judged partly from text because a preloader hid the page.
