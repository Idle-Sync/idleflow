// The rendered tier of /idleflow:unslopify. One expression, evaluated inside a loaded page by a
// browser tool; it changes nothing on the page and returns the measures procedures/slop.md names,
// with `flags`: the catalogue patterns the measures show, each with its evidence.
(() => {
  const W = innerWidth, VH = innerHeight;
  const flags = [];
  const flag = (id, evidence) => flags.push({ id, evidence });
  const css = (el) => getComputedStyle(el);
  const visible = (el) => {
    const r = el.getBoundingClientRect(), s = css(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
  };
  // any computed colour (rgb, oklch, oklab, lab, color()) as sRGB: painted on one canvas pixel and read
  // back; null when the browser cannot paint it
  const probe = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
  const seen = new Map();
  const rgba = (c) => {
    if (!c) return null;
    if (seen.has(c)) return seen.get(c);
    let out = null;
    const m = c.match(/^rgba?\(([^)]+)\)$/);
    if (m) {
      const p = m[1].split(/[ ,/]+/).filter(Boolean).map(parseFloat);
      out = { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
    } else if (probe) {
      probe.clearRect(0, 0, 1, 1); probe.fillStyle = '#010203'; probe.fillStyle = c;
      if (probe.fillStyle !== '#010203') {
        probe.fillRect(0, 0, 1, 1);
        const d = probe.getImageData(0, 0, 1, 1).data;
        out = { r: d[0], g: d[1], b: d[2], a: d[3] / 255 };
      }
    }
    seen.set(c, out); return out;
  };
  const lum = ({ r, g, b }) => {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const bgOf = (el) => {
    for (let e = el; e; e = e.parentElement) {
      const c = rgba(css(e).backgroundColor);
      if (!c) return null; // a colour this browser cannot resolve: judged on the screenshot
      if (c.a > 0.5) return c;
      if (css(e).backgroundImage !== 'none') return null; // text over an image or gradient: judged on the screenshot
    }
    return { r: 255, g: 255, b: 255, a: 1 };
  };
  const hue = ({ r, g, b }) => {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn, l = (mx + mn) / 2;
    if (d === 0) return { h: 0, s: 0, l };
    const s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    let h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: h * 60, s, l };
  };

  // text: every visible element that holds its own text
  const texts = [...document.body.querySelectorAll('*')].filter((el) =>
    [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim()) && visible(el));
  const bodySize = (() => {
    const sizes = texts.filter((el) => el.tagName === 'P').map((el) => parseFloat(css(el).fontSize));
    if (!sizes.length) return parseFloat(css(document.body).fontSize);
    sizes.sort((a, b) => a - b); return sizes[Math.floor(sizes.length / 2)];
  })();

  let lowContrast = 0, tiny = 0, hidden = 0; const lowSamples = [];
  const bands = {}; const hues = new Set();
  for (const el of texts) {
    const s = css(el), size = parseFloat(s.fontSize), bold = parseInt(s.fontWeight, 10) >= 700;
    const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent).join(' ').trim();
    if (parseFloat(s.opacity) === 0) { hidden++; continue; }
    if (size < 12) tiny++;
    const fg = rgba(s.color), bg = bgOf(el);
    if (fg && bg) {
      const need = size >= 24 || (bold && size >= 18.66) ? 3 : 4.5, got = ratio(fg, bg);
      if (got < need) { lowContrast++; if (lowSamples.length < 5) lowSamples.push(`${own.slice(0, 40)} (${got.toFixed(2)}:1, needs ${need}:1)`); }
      const h = hue(fg); if (h.s > 0.4 && h.l > 0.2 && h.l < 0.85) hues.add(Math.floor(h.h / 30));
    }
    const top = el.getBoundingClientRect().top + scrollY, band = Math.floor(top / VH);
    bands[band] = (bands[band] || 0) + own.split(/\s+/).filter(Boolean).length;
  }
  if (lowContrast) flag('low-contrast', `${lowContrast} text elements under their contrast threshold: ${lowSamples.join('; ')}`);
  if (tiny > 3) flag('tiny-text', `${tiny} text elements under 12px`);
  if (hidden) flag('broken-basics', `${hidden} text elements still at opacity 0 after load`);
  const maxWords = Math.max(0, ...Object.values(bands));
  if (maxWords > 120) flag('text-wall', `${maxWords} words in one screen height`);
  if (hues.size > 4) flag('hue-clash', `${hues.size} distinct saturated text hues`);

  // hierarchy: rendered heading sizes against the body size
  const hs = {};
  for (const t of ['H1', 'H2', 'H3']) {
    const el = [...document.querySelectorAll(t)].find(visible);
    if (el) hs[t] = parseFloat(css(el).fontSize);
  }
  const largest = Math.max(0, ...Object.values(hs));
  if (largest && largest < bodySize * 1.6) flag('flat-hierarchy', `largest heading ${largest}px against ${bodySize}px body text`);
  if (hs.H2 && hs.H3 && Math.abs(hs.H2 - hs.H3) / hs.H2 < 0.1) flag('flat-hierarchy', `h2 ${hs.H2}px and h3 ${hs.H3}px read as one level`);

  // images: share of the page area that is a picture, video or canvas
  const pageArea = Math.max(1, document.documentElement.scrollWidth * document.documentElement.scrollHeight);
  let imgArea = 0, broken = 0;
  for (const el of document.querySelectorAll('img, picture, video, canvas, svg')) {
    if (!visible(el)) continue;
    const r = el.getBoundingClientRect();
    if (el.tagName === 'IMG' && el.complete && el.naturalWidth === 0) broken++;
    if (r.width >= 64 && r.height >= 64) imgArea += r.width * r.height;
  }
  const imageShare = imgArea / pageArea;
  if (imageShare < 0.02 && document.documentElement.scrollHeight > VH * 2) flag('no-images', `pictures cover ${(imageShare * 100).toFixed(1)}% of a page ${Math.round(document.documentElement.scrollHeight / VH)} screens long`);
  if (broken) flag('broken-basics', `${broken} images failed to load`);

  // basics
  if (document.documentElement.scrollWidth > W + 1) flag('broken-basics', `the page scrolls sideways: ${document.documentElement.scrollWidth}px wide in a ${W}px window`);
  const small = [...document.querySelectorAll('a, button, input, select, textarea, [role=button]')]
    .filter(visible)
    // a link inside a sentence is exempt from the target size, as WCAG 2.5.8 says
    .filter((el) => !(el.tagName === 'A' && css(el).display === 'inline' && el.parentElement && el.parentElement.textContent.trim().length > el.textContent.trim().length))
    .filter((el) => { const r = el.getBoundingClientRect(); return r.width < 24 || r.height < 24; }).length;
  if (small > 2) flag('broken-basics', `${small} controls smaller than 24px`);

  // boxes inside boxes: a bordered or filled rounded box holding another
  const isBox = (el) => {
    const s = css(el); if (parseFloat(s.borderTopLeftRadius) <= 0) return false;
    const filled = (rgba(s.backgroundColor) || { a: 0 }).a > 0.05, bordered = parseFloat(s.borderTopWidth) > 0 || parseFloat(s.borderLeftWidth) > 0;
    return (filled || bordered) && visible(el) && el.getBoundingClientRect().width > 120;
  };
  const boxes = [...document.body.querySelectorAll('div, section, article, li, aside')].filter(isBox);
  const nested = boxes.filter((b) => boxes.some((o) => o !== b && b.contains(o))).length;
  if (nested >= 3) flag('box-everything', `${nested} rounded boxes that hold another rounded box`);

  // sections: their sequence and their rhythm
  const root = document.querySelector('main') || document.body;
  const sections = [...root.children].filter((el) => visible(el) && el.getBoundingClientRect().height > 80);
  const kind = (el, i) => {
    if (i === 0 && el.querySelector('h1')) return 'hero';
    if (el.tagName === 'FOOTER' || el.querySelector('footer')) return 'footer';
    const kids = [...el.querySelectorAll('*')].filter((k) => k.parentElement && k.parentElement.children.length >= 3 && isBox(k));
    const counts = new Map();
    for (const k of kids) counts.set(k.parentElement, (counts.get(k.parentElement) || 0) + 1);
    const best = counts.size ? Math.max(...counts.values()) : 0;
    const text = el.textContent;
    if (best >= 2 && /[$€£¥₹]\s?\d/.test(text)) return 'pricing';
    if (best >= 3) return `cards-${best}`;
    if (el.querySelectorAll('h1, h2, h3').length <= 2 && el.querySelector('a, button') && text.trim().split(/\s+/).length < 40) return 'cta';
    return 'section';
  };
  const sequence = sections.map(kind);
  if (sequence[0] === 'hero' && sequence.some((k) => /^cards-3$/.test(k)) && /^(cta|footer)$/.test(sequence[sequence.length - 1] || ''))
    flag('template-sequence', sequence.join(' > '));
  const gaps = [];
  for (let i = 1; i < sections.length; i++) gaps.push(sections[i].getBoundingClientRect().top - sections[i - 1].getBoundingClientRect().bottom);
  const heights = sections.map((s) => s.getBoundingClientRect().height);
  if (heights.length >= 4) {
    const mean = heights.reduce((a, b) => a + b, 0) / heights.length;
    const sd = Math.sqrt(heights.reduce((a, b) => a + (b - mean) ** 2, 0) / heights.length);
    if (mean > 0 && sd / mean < 0.15) flag('same-rhythm', `${heights.length} sections within 15% of one height (${Math.round(mean)}px)`);
  }

  const fontOf = (sel) => { const el = [...document.querySelectorAll(sel)].find(visible); return el ? css(el).fontFamily : null; };
  return {
    url: location.href, width: W, height: VH,
    fonts: { heading: fontOf('h1, h2'), body: fontOf('p') || css(document.body).fontFamily, families: [...new Set(texts.map((el) => css(el).fontFamily.split(',')[0].trim()))].length },
    body_px: bodySize, headings_px: hs, image_share: Number(imageShare.toFixed(3)), words_max_per_screen: maxWords,
    sections: sequence, section_gaps_px: gaps.map(Math.round),
    flags,
  };
})()
