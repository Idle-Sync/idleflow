#!/usr/bin/env bash
# The static tier of /idleflow:unslopify: finds, in a repo's UI source, the catalogue patterns
# (procedures/slop.md) that can be read from code without rendering it.
#
#   slop-scan.sh [--repo <dir>] [<file>...]
#
# Scans the tracked UI source files of the repo (the current directory unless --repo), or only the
# files named. Prints one hit per line, tab-separated: <pattern id> <path:line> <the line, trimmed>.
# A pattern found for the whole repo rather than one line prints `-` as its place, and one found
# for a whole file prints line 0. Prints nothing
# when nothing is found. A hit is a lead for the auditor, never a verdict: whether the repo chose it
# is decided against its design system.
#
# A line holding `slop-ignore` is skipped; a file holding `slop-ignore-file` is skipped whole.
# Exit 0 after a scan, 2 on a usage error.
set -euo pipefail
export LC_ALL=C

repo=.
if [ "${1:-}" = --repo ]; then repo="${2:?--repo needs a folder}"; shift 2; fi
cd "$repo" 2>/dev/null || { echo "slop-scan: no folder $repo" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "slop-scan: $repo is not a git repository; the scan reads its tracked files" >&2; exit 2; }

is_ui_file() {
  case "$1" in
    *node_modules/*|*/dist/*|dist/*|*/build/*|build/*|*/vendor/*|vendor/*|.idleflow/*|*.min.*) return 1 ;;
    *.test.*|*.spec.*|*.stories.*|*__tests__/*|*__mocks__/*|test/*|*/test/*|tests/*|*/tests/*|*fixtures/*|e2e/*|*/e2e/*) return 1 ;;
    *.html|*.htm|*.css|*.scss|*.sass|*.less|*.js|*.jsx|*.ts|*.tsx|*.vue|*.svelte|*.astro|*.mdx) return 0 ;;
  esac
  return 1
}

files=()
if [ "$#" -gt 0 ]; then
  for f in "$@"; do [ -f "$f" ] && is_ui_file "$f" && files+=("$f"); done
else
  while IFS= read -r -d '' f; do is_ui_file "$f" && files+=("$f"); done < <(git ls-files -z 2>/dev/null)
fi
[ "${#files[@]}" -gt 0 ] || exit 0
skip="$(printf '%s\0' "${files[@]}" | xargs -0 grep -l 'slop-ignore-file' 2>/dev/null || true)"
kept=()
for f in "${files[@]}"; do
  case "
$skip
" in *"
$f
"*) ;; *) kept+=("$f") ;; esac
done
[ "${#kept[@]}" -gt 0 ] || exit 0
# whether the project has a reduced-motion rule is a fact about the whole repo, even when only some
# files are scanned
all=()
while IFS= read -r -d '' f; do is_ui_file "$f" && all+=("$f"); done < <(git ls-files -z)
rm_hits=""
[ "${#all[@]}" -eq 0 ] || rm_hits="$(printf '%s\0' "${all[@]}" | xargs -0 grep -lE 'prefers-reduced-motion|motion-reduce|motion-safe|useReducedMotion|reducedMotion' 2>/dev/null || true)"
reduced=0; [ -z "$rm_hits" ] || reduced=1

awk -v q="'" -v reduced="$reduced" '
BEGIN {
  re_ord = ">[ ]*0[1-9][ ]*<"
  re_ordq = "[\"" q "]0[1-9][.]?[\"" q "]"
  re_reb = "Not [^.<]+, (it" q "s|it is) "
  re_dead = "href=[\"" q "]#[\"" q "]|on[A-Z][a-z]+=\\{\\(\\) => \\{\\}\\}"
}
function hit(id, where, text) {
  gsub(/\t/, " ", text); sub(/^[ ]+/, "", text)
  if (length(text) > 120) text = substr(text, 1, 117) "..."
  printf "%s\t%s\t%s\n", id, where, text
}
function hexval(c) { return index("0123456789abcdef", tolower(c)) - 1 }
# hue (0-360), saturation and lightness (0-1) of an RGB colour, as HSL
function hsl(r, g, b,    mx, mn, d) {
  r /= 255; g /= 255; b /= 255
  mx = r; if (g > mx) mx = g; if (b > mx) mx = b
  mn = r; if (g < mn) mn = g; if (b < mn) mn = b
  L = (mx + mn) / 2; d = mx - mn
  if (d == 0) { H = 0; S = 0; return }
  S = (L > 0.5) ? d / (2 - mx - mn) : d / (mx + mn)
  if (mx == r) H = (g - b) / d + (g < b ? 6 : 0)
  else if (mx == g) H = (b - r) / d + 2
  else H = (r - g) / d + 4
  H *= 60
}
function bucket(where, text) {
  if (H >= 235 && H <= 290 && S >= 0.35 && L >= 0.3 && L <= 0.8) { hit("violet-accent", where, text); return }
  if (L >= 0.9 && L < 0.985 && H >= 30 && H <= 60 && S >= 0.15) { hit("cream-paper", where, text); return }
  if (H >= 5 && H <= 35 && S >= 0.45 && L >= 0.45 && L <= 0.75) { hit("terracotta-accent", where, text); return }
  if (H >= 65 && H <= 100 && S >= 0.7 && L >= 0.45 && L <= 0.7) { hit("acid-accent", where, text); return }
}
# hex colours: 3, 4, 6 or 8 digits (the alpha is ignored), never after `&` (an entity) or a word character
function colours(line, where,    s, hx, n, r, g, b, seen) {
  s = " " line; seen = 0
  while (match(s, /[^&0-9A-Za-z_]#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*([^0-9a-zA-Z_-]|$)/)) {
    hx = substr(s, RSTART + 2, RLENGTH - 2); sub(/[^0-9a-fA-F]+$/, "", hx)
    s = substr(s, RSTART + RLENGTH - 1)
    n = length(hx)
    if (n == 3 || n == 4) { r = hexval(substr(hx,1,1)) * 17; g = hexval(substr(hx,2,1)) * 17; b = hexval(substr(hx,3,1)) * 17 }
    else if (n == 6 || n == 8) { r = hexval(substr(hx,1,1)) * 16 + hexval(substr(hx,2,1)); g = hexval(substr(hx,3,1)) * 16 + hexval(substr(hx,4,1)); b = hexval(substr(hx,5,1)) * 16 + hexval(substr(hx,6,1)) }
    else continue
    hsl(r, g, b); bucket(where, line); seen = 1
  }
  return seen
}
# oklch(L C H): violet when its chroma shows a real colour and its hue sits in the violet band
function oklch_violet(line,    s, inner, p, k) {
  s = line
  while (match(s, /oklch\([^)]*\)/)) {
    inner = substr(s, RSTART + 6, RLENGTH - 7); s = substr(s, RSTART + RLENGTH)
    gsub(/deg|%/, "", inner); k = split(inner, p, /[ ,\/]+/)
    if (k >= 3 && p[1] == "") { p[1] = p[2]; p[2] = p[3]; p[3] = p[4] }
    if (k >= 3 && p[2] + 0 >= 0.08 && p[3] + 0 >= 272 && p[3] + 0 <= 320) return 1
  }
  return 0
}
function props(seg) {
  if (seg ~ /text-transform:[ ]*uppercase/) up = 1
  if (seg ~ /letter-spacing:[ ]*[0-9.]*[1-9]/) ls = 1
  if (seg ~ /border-(left|right|top):[ ]*([2-9]|[1-9][0-9])px/ || seg ~ /border-(left|right|top)-width:[ ]*([2-9]|[1-9][0-9])px/) side = 1
  if (seg ~ /border-radius:/) rad = 1
  if (seg ~ /(linear|radial|conic)-gradient\(/ && grad == "") grad = where
  if (seg ~ /background-clip:[ ]*text/) clip = 1
}
function endrule() {
  if (up && ls) hit("eyebrow-label", rstart, "uppercase with letter-spacing in one rule")
  if (side && rad) hit("side-stripe", rstart, "a thick one-side border on a rounded box in one rule")
  if (grad != "" && !clip) hit("gradient-surface", grad, "a gradient on a surface in one rule")
  inrule = 0
}
FNR == 1 {
  css = (FILENAME ~ /\.(css|scss|sass|less)$/)
  view = (FILENAME ~ /\.(html|htm|jsx|tsx|vue|svelte|astro|mdx)$/); markup = !css
  tokens = (FILENAME ~ /(^|\/)(tailwind|theme|tokens|design-tokens)[^\/]*$/) || (FILENAME ~ /(^|\/)_?(globals|variables|tokens|theme|colou?rs)\.(css|scss|sass|less)$/)
  inrule = 0
}
/slop-ignore/ { next }
{
  where = FILENAME ":" FNR; line = $0
  comment = (line ~ /^[ ]*(\/\/|\/\*|\*|<!--)/)
  cl = line; sub(/[ \t]\/\/[^"`]*$/, "", cl)
  # in CSS a colour is read only inside a rule: outside one, a line is a selector, which can spell hex
  if (css) { if (cl ~ /\{/) { while (match(cl, /\{/)) cl = substr(cl, RSTART + 1) } else if (!inrule) cl = "" }
  lit = comment ? 0 : colours(cl, where)
  if (lit && !tokens && line !~ /--[A-Za-z0-9_-]+[ ]*:/ && line !~ /^[ ]*[$@][A-Za-z0-9_-]+[ ]*:/) hit("design-drift", where, line)
  if (line ~ /(bg|text|from|via|to|border|ring|shadow|fill|stroke)-(indigo|violet|purple)-[0-9]/) hit("violet-accent", where, line)
  if (!comment && oklch_violet(cl)) hit("violet-accent", where, line)
  if (line ~ /bg-clip-text|background-clip:[ ]*text|-webkit-background-clip:[ ]*text/) hit("gradient-text", where, line)
  # a CSS gradient is judged per rule (the clip that makes it gradient text may sit on another line)
  if (!comment && !css && line !~ /bg-clip-text|background-clip:[ ]*text/ && line ~ /(linear|radial|conic)-gradient\(|bg-gradient-to-|bg-linear-|bg-radial|bg-conic/) hit("gradient-surface", where, line)
  if (line ~ /box-shadow:[ ]*0(px)?[ ]+0(px)?[ ]+[0-9][0-9]+px/ || line ~ /shadow-[a-z]+-[0-9]+\/[0-9]+/ || line ~ /drop-shadow-\[0_0_/) hit("neon-glow", where, line)
  if (line ~ /blur-(2xl|3xl)/ || line ~ /filter:[ ]*blur\(([4-9][0-9]|[1-9][0-9][0-9])px\)/) hit("blur-orbs", where, line)
  if (line ~ /backdrop-blur|backdrop-filter:[ ]*blur/) hit("glass-cards", where, line)
  if (line ~ /font-family:[^;]*(Inter|Geist|Roboto)/ || line ~ /(^|[^A-Za-z])(Inter|Geist|Roboto)\(/ || line ~ /fontFamily.*(Inter|Geist|Roboto)/) hit("stock-display-face", where, line)
  if (line ~ /uppercase/ && line ~ /tracking-(wide|wider|widest|\[)/) hit("eyebrow-label", where, line)
  if (line ~ /<h[12][ >]/ && line ~ /<(em|i)[ >]|<span[^>]*(text-[a-z]+-[0-9]|font-serif|italic)/) hit("accent-word", where, line)
  if (line ~ /font-mono/ && line !~ /<(code|pre|kbd|samp)[ >]/) hit("mono-costume", where, line)
  if (line ~ /border-[lrt]-([2-9]|\[[2-9]px\])/ && line ~ /rounded/) hit("side-stripe", where, line)
  if (line ~ /<(button|Button)[ >]/ && line ~ /rounded-full/) hit("pill-everything", where, line)
  jsx = view || line ~ /<[A-Za-z][^>]*>|className=/
  if (markup && (line ~ re_ord || (jsx && line ~ re_ordq))) hit("ordinal-numbering", where, line)
  if (markup && line ~ /-\[[0-9]+px\]/) hit("off-scale-spacing", where, line)
  if (line ~ /\360\237/ && line !~ /^[ ]*(\/\/|\/\*|\*|#)/) hit("emoji-icons", where, line)
  if (line ~ /\342\234\250/) hit("sparkle-ai", where, line)
  if (markup && (line ~ /\302\267[^\302]*\302\267/ || line ~ /\342\206\222[ ]*<\/(a|Link|button)/)) hit("template-punctuation", where, line)
  if (line ~ /marquee/) hit("logo-marquee", where, line)
  if (line ~ /whileInView|IntersectionObserver|data-aos|fadeInUp|fade-in-up|animate-fade|useInView/) hit("reveal-everything", where, line)
  if (line ~ /hover:-translate-y|hover:scale-|hover:shadow-(lg|xl|2xl)/) hit("hover-lift", where, line)
  if (line ~ /animate-bounce|shimmer/) hit("shimmer-bounce", where, line)
  if (line ~ /animate-(pulse|ping)/ && line ~ /rounded-full/) hit("pulse-dot", where, line)
  if (line ~ /prefers-reduced-motion|motion-reduce|motion-safe|useReducedMotion|reducedMotion/) reduced_seen = 1
  if (!anim && (line ~ /@keyframes|animate-[a-z]|(^|[^A-Za-z])transition([^A-Za-z]|$)|framer-motion|whileInView/)) anim = where
  # copy and honesty: text a page shows, so markup files only, and lines that hold text or an attribute
  if (markup && !comment && (line ~ />/ || line ~ /["`]/ || index(line, q))) {
    if (line ~ /(^|[^A-Za-z])(Build|Manage|Grow|Transform|Supercharge|Scale|Streamline) your /) hit("generic-hero", where, line)
    l = tolower(line)
    if (l ~ /(^|[^a-z])(elevate|seamless(ly)?|unlock|supercharge|empower|effortless(ly)?|next-generation|cutting-edge|game-chang(er|ing)|revolutioni[sz]e|leverage|unleash)([^a-z(]|$)/) hit("buzzwords", where, line)
    if (line ~ /No [A-Za-z]+\. No [A-Za-z]+\./ || line ~ re_reb) hit("rebuttal-cadence", where, line)
    if (line !~ /^[ ]*(\/\/|\/\*|\*)/) { t = line; dash[FILENAME] += gsub(/\342\200\224/, "", t) }
    if (l ~ /built with|powered by|never leaves? your/) hit("chat-leak", where, line)
    if (line ~ /Jane Doe|John Doe|Acme|[Ll]orem ipsum/) hit("fake-proof", where, line)
    if (line ~ re_dead) hit("fake-controls", where, line)
    if (line ~ /\{[ ]*(error|err|e)\.message[ ]*\}/ || (jsx && line ~ /(error|err)\.toString\(\)/)) hit("raw-errors", where, line)
  }
  # CSS rules that set two properties a single line cannot show together
  if (css) {
    # the braces in order, so a rule closed and another opened on one line are both seen
    rest = line; gsub(/#\{[^}]*\}/, "", rest)
    while (rest != "") {
      o = index(rest, "{"); c = index(rest, "}")
      if (!o && !c) { if (inrule) props(rest); break }
      if (o && (!c || o < c)) { if (inrule) props(substr(rest, 1, o - 1)); inrule = 1; rstart = where; up = 0; ls = 0; side = 0; rad = 0; grad = ""; clip = 0; rest = substr(rest, o + 1) }
      else { if (inrule) { props(substr(rest, 1, c - 1)); endrule() }; rest = substr(rest, c + 1) }
    }
  }

}
END {
  for (f in dash) if (dash[f] >= 3) hit("em-dash", f ":0", dash[f] " em dashes in its text")
  if (anim && !reduced && reduced_seen != 1) hit("no-reduced-motion", "-", "animation (first at " anim ") and no reduced-motion rule anywhere")
}
' "${kept[@]}"
