---
name: frontend-design
description: >
  Create distinctive, production-grade frontend interfaces with exceptional design quality,
  professional animations, and strict WCAG accessibility. Use this skill for ANY request
  involving UI — web components, pages, dashboards, landing pages, SaaS apps, design system
  components, HTML/CSS/JS interfaces, or React/Next.js screens. Triggers when the user says
  things like "build me a UI", "create a component", "design a dashboard", "make a landing
  page", "improve my interface", "style this", "make it look good", or anything related to
  visual frontend work. ALWAYS use this skill before writing any frontend code — it prevents
  generic AI aesthetics and ensures the output is genuinely creative, animated, and accessible.
---

# Frontend Design Skill

This skill produces **distinctive, production-grade** UIs that are visually memorable, animated with intention, and fully accessible (WCAG 2.1 AA minimum). The goal is never "a good-looking UI" — it's a UI someone will **remember**.

Stack coverage: **React / Next.js** and **HTML/CSS/JS puro**. All outputs must be production-ready and functional, not just decorative.

---

## Phase 1 — Design Thinking (ALWAYS do this before writing code)

Before touching any code, define these explicitly in your internal plan:

### 1.1 Context
- **Who uses this?** (developer tools feel different from consumer apps)
- **What emotion should it produce?** (confidence, delight, calm, excitement?)
- **What's the main action?** (one call-to-action must dominate)

### 1.2 Aesthetic Direction — Pick ONE and commit fully

| Direction | Feel | Best for |
|---|---|---|
| **Editorial / Magazine** | Bold typography, asymmetric grid, strong hierarchy | Landing pages, portfolios |
| **Brutalist / Raw** | Hard edges, monospace, high contrast, exposed structure | Developer tools, technical apps |
| **Soft Luxury** | Cream/warm neutrals, generous whitespace, refined serif | SaaS, premium products |
| **Glassmorphism 2.0** | Frosted layers, light refraction, depth — but tasteful | Dashboards, modern apps |
| **Data-Forward** | Grid density, micro-typography, information hierarchy | Admin panels, analytics |
| **Neo-Retro** | Pixel touches, warm palettes, nostalgic but polished | Creative tools, consumer apps |
| **Organic / Fluid** | Curved shapes, gradient meshes, flowing motion | Marketing, wellness, consumer |

**Critical rule**: Choose one direction and execute it with conviction. A timid hybrid of two aesthetics always looks worse than a fully committed single direction.

### 1.3 The One Thing
What is the **single visual element** someone will remember? (a bold headline treatment, an unusual hover effect, a signature color, an unexpected layout break). Name it before coding.

---

## Phase 2 — Typography

Typography is where generic AI UIs fail most visibly. **Never default to system fonts.**

### Font Pairing Strategy
- **Display / Hero**: A distinctive, characterful font
- **Body / UI**: A refined, readable companion
- **Mono** (if needed for code/data): Something with personality

### Approved font pairings (Google Fonts)
```css
/* Editorial / Luxury */
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700;900&family=DM+Sans:wght@300;400;500&display=swap');

/* Brutalist / Technical */
@import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=IBM+Plex+Sans:wght@300;400;600&display=swap');

/* Modern / Geometric */
@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=Literata:wght@300;400&display=swap');

/* Elegant / Editorial */
@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@300;400;600&family=Plus+Jakarta+Sans:wght@400;500;600&display=swap');

/* Creative / Expressive */
@import url('https://fonts.googleapis.com/css2?family=Syne:wght@400;700;800&family=Nunito:wght@300;400;600&display=swap');
```

**NEVER use**: Inter, Roboto, Arial, Helvetica, system-ui alone, or any font without a clear personality.

### Fluid type scale
```css
:root {
  --text-xs:   clamp(0.7rem,  1vw,   0.75rem);
  --text-sm:   clamp(0.85rem, 1.2vw, 0.9rem);
  --text-base: clamp(1rem,    1.5vw, 1.1rem);
  --text-lg:   clamp(1.1rem,  2vw,   1.3rem);
  --text-xl:   clamp(1.3rem,  3vw,   1.8rem);
  --text-2xl:  clamp(1.8rem,  4vw,   2.8rem);
  --text-3xl:  clamp(2.5rem,  6vw,   4.5rem);
  --text-hero: clamp(3rem,    9vw,   8rem);
}
```

---

## Phase 3 — Color System

### Token Architecture
```css
:root {
  /* Brand */
  --color-brand:  #[PRIMARY];
  --color-accent: #[SHARP_CONTRAST];

  /* Surfaces — 3 levels of depth */
  --surface-0: #[PAGE_BG];
  --surface-1: #[CARD_BG];
  --surface-2: #[ELEVATED_BG];

  /* Text — 3 levels */
  --text-primary:   #[MAIN_TEXT];
  --text-secondary: #[MUTED_TEXT];
  --text-disabled:  #[VERY_MUTED];

  /* Borders */
  --border-subtle: rgba(255,255,255,0.06);
  --border-strong: rgba(255,255,255,0.15);

  /* Semantic */
  --color-success: #22c55e;
  --color-warning: #f59e0b;
  --color-danger:  #ef4444;
}
```

### Non-generic starting palettes
- **Obsidian + Electric**: `#0a0a0f` bg · `#e2ff3d` accent · white text
- **Warm Ivory + Forest**: `#f5f0e8` bg · `#2d4a3e` primary · `#c4622d` accent
- **Deep Navy + Coral**: `#0d1b2a` bg · `#ff6b6b` accent · `#e8f4f8` text
- **Chalk + Ink**: `#fafaf7` bg · `#1a1a2e` text · `#6c5ce7` accent
- **Slate + Amber**: `#1e2132` bg · `#fbbf24` accent · `#e2e8f0` text
- **Blush + Charcoal**: `#fff5f5` bg · `#2d2d2d` text · `#e11d48` accent

---

## Phase 4 — Motion Design

Animation is **not decoration** — it communicates state, hierarchy, and feedback.

### The Three Laws of Good Animation
1. **Purposeful**: Every animation answers "why does this help the user?"
2. **Respectful**: Honor `prefers-reduced-motion` — always, without exception
3. **Fast-to-useful**: Entrances ≤ 400ms · Exits ≤ 250ms · Never delay content visibility

### CSS Animation Primitives (HTML/CSS/JS)
```css
/* Reduced motion — ALWAYS first */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* Staggered reveal — the signature entrance pattern */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(24px); }
  to   { opacity: 1; transform: translateY(0); }
}
.reveal            { animation: fadeUp 0.5s cubic-bezier(0.16, 1, 0.3, 1) both; }
.reveal-delay-1    { animation-delay: 80ms; }
.reveal-delay-2    { animation-delay: 160ms; }
.reveal-delay-3    { animation-delay: 240ms; }
.reveal-delay-4    { animation-delay: 320ms; }

/* Card scale-in */
@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.96); }
  to   { opacity: 1; transform: scale(1); }
}

/* Skeleton shimmer */
@keyframes shimmer {
  from { background-position: -200% center; }
  to   { background-position:  200% center; }
}
.skeleton {
  background: linear-gradient(90deg,
    var(--surface-1) 25%,
    var(--surface-2) 50%,
    var(--surface-1) 75%
  );
  background-size: 200% auto;
  animation: shimmer 1.5s linear infinite;
  border-radius: 6px;
}
```

### Framer Motion Patterns (React)
```jsx
import { motion } from 'framer-motion';

// Staggered list — use for every repeating element (cards, rows, items)
const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.07 } }
};
const item = {
  hidden: { opacity: 0, y: 20 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] } }
};
<motion.ul variants={container} initial="hidden" animate="show">
  {items.map(i => <motion.li key={i.id} variants={item}>{i.label}</motion.li>)}
</motion.ul>

// Page transition wrapper
const page = {
  initial: { opacity: 0, y: 8 },
  enter:   { opacity: 1, y: 0, transition: { duration: 0.35, ease: 'easeOut' } },
  exit:    { opacity: 0,       transition: { duration: 0.2 } }
};

// Layout animation — nav active indicator slides between items
<motion.div layoutId="nav-pill" className="active-indicator" />

// Animated metric counter (dashboards)
import { useMotionValue, animate } from 'framer-motion';
// Animate from 0 to target value on mount — creates the "counting up" effect users love
```

### Anime.js Patterns (HTML/CSS/JS — and React via CDN or npm)

**When to choose Anime.js over CSS or Framer Motion:**
- SVG path drawing, morphing, or stroke animations
- Complex timelines with precise sequencing across multiple elements
- Scroll-linked animations with fine-grained progress control
- Advanced text effects (letter-by-letter, word-by-word)
- Looping ambient animations (backgrounds, decorative elements)

**Install / import**
```html
<!-- HTML -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/animejs/3.2.1/anime.min.js"></script>
```
```js
// React / Next.js
import anime from 'animejs';
```

**Staggered entrance — cards or list items**
```js
anime({
  targets: '.card',
  opacity: [0, 1],
  translateY: [32, 0],
  duration: 500,
  easing: 'cubicBezier(0.16, 1, 0.3, 1)',
  delay: anime.stagger(80),  // 80ms between each element
});
```

**SVG path draw — signature line / checkmark / logo reveal**
```js
// First set stroke-dasharray and stroke-dashoffset to path length in CSS
anime({
  targets: '.path-to-draw',
  strokeDashoffset: [anime.setDashoffset, 0], // auto-measures path length
  duration: 1200,
  easing: 'easeInOutSine',
  delay: anime.stagger(200),
});
```

**Timeline — orchestrated multi-element sequence**
```js
const tl = anime.timeline({
  easing: 'easeOutExpo',
  duration: 500,
});

tl.add({ targets: '.hero-label',   opacity: [0,1], translateY: [16,0] })
  .add({ targets: '.hero-title',   opacity: [0,1], translateY: [24,0] }, '-=300') // overlap by 300ms
  .add({ targets: '.hero-sub',     opacity: [0,1], translateY: [16,0] }, '-=250')
  .add({ targets: '.hero-cta',     opacity: [0,1], scale:       [0.9,1] }, '-=200');
```

**Metric counter — number animates up on load**
```js
const counter = { value: 0 };
anime({
  targets: counter,
  value: 84320,             // target number
  duration: 1800,
  easing: 'easeOutExpo',
  round: 1,                 // no decimals
  update: () => {
    document.querySelector('.metric-value').textContent =
      counter.value.toLocaleString();
  }
});
```

**Scroll-triggered animation (Intersection Observer + Anime.js)**
```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      anime({
        targets: entry.target,
        opacity: [0, 1],
        translateY: [40, 0],
        duration: 600,
        easing: 'cubicBezier(0.16, 1, 0.3, 1)',
      });
      observer.unobserve(entry.target); // animate once
    }
  });
}, { threshold: 0.15 });

document.querySelectorAll('.scroll-reveal').forEach(el => observer.observe(el));
```

**Ambient loop — subtle background element (non-distracting)**
```js
anime({
  targets: '.bg-orb',
  translateX: () => anime.random(-30, 30),
  translateY: () => anime.random(-30, 30),
  scale: [0.95, 1.05],
  opacity: [0.4, 0.7],
  duration: () => anime.random(3000, 5000),
  easing: 'easeInOutSine',
  loop: true,
  direction: 'alternate',
});
```

**Respect `prefers-reduced-motion` with Anime.js**
```js
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (!prefersReduced) {
  anime({ targets: '.animated', /* ... */ });
} else {
  // Make elements immediately visible without animation
  document.querySelectorAll('.animated').forEach(el => {
    el.style.opacity = '1';
    el.style.transform = 'none';
  });
}
```

### Micro-interaction Catalog
| Trigger | Effect | CSS / Motion |
|---|---|---|
| Button hover | Scale up + deepen shadow | `scale(1.02)` + shadow transition |
| Button press | Scale down | `scale(0.97)` on `:active` |
| Card hover | Lift + accent glow | `translateY(-4px)` + `box-shadow` |
| Input focus | Brand border + soft halo | `outline` with color + `box-shadow` |
| Link hover | Underline draws left→right | `scaleX` on `::after` pseudo |
| Toggle | Spring physics snap | Framer `spring` transition |
| Nav active | Pill slides behind item | `layoutId` Framer animation |
| Metric load | Number counts up | `useMotionValue` (Framer) · Anime.js counter |
| Success | Checkmark draws in | Anime.js `strokeDashoffset` timeline |
| Error shake | Horizontal wobble | CSS `@keyframes` · Anime.js `translateX` |
| Section reveal on scroll | Fade + lift | Anime.js + IntersectionObserver |
| Hero sequence | Staggered multi-element | Anime.js timeline with overlaps |

---

## Phase 5 — Layout & Spatial Composition

**Break the grid occasionally.** Predictable layouts are forgettable layouts.

### Principles
- CSS Grid for macro layout · Flexbox for micro alignment
- At least one element per design should **escape its container** (overlap, bleed, diagonal)
- Negative space is a design element, not wasted space
- Headlines should carry 3–5× more visual weight than body text

### Patterns by Interface Type

#### Dashboard
```css
.dashboard {
  display: grid;
  grid-template-columns: 240px 1fr;
  grid-template-rows: 64px 1fr;
  min-height: 100vh;
}
.metrics-row {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr; /* varied = visual interest */
  gap: 1rem;
}
```

#### Landing — Asymmetric Hero
```css
.hero {
  display: grid;
  grid-template-columns: 1fr 1fr;
  align-items: center;
  min-height: 90vh;
}
.hero-text   { padding: 0 10% 0 8%; }
.hero-visual { height: 100%; overflow: hidden; } /* bleeds to edge */
```

#### Component Grid — Organic feel
```css
.card-grid {
  columns: 3;
  column-gap: 1.5rem;
  /* Cards flow naturally across columns — more human than uniform rows */
}
```

---

## Phase 6 — Accessibility (WCAG 2.1 AA — Non-Negotiable)

### Checklist
- [ ] Color contrast ≥ 4.5:1 for body text · ≥ 3:1 for large text and UI components
- [ ] All interactive elements have styled `:focus-visible` ring
- [ ] Logical tab order · no keyboard traps
- [ ] Icon-only buttons have `aria-label`
- [ ] Images have meaningful `alt` text (or `alt=""` if decorative)
- [ ] Semantic HTML: `<nav>`, `<main>`, `<section>`, `<button>` — never `<div>` for interaction
- [ ] All animations use `prefers-reduced-motion` guard
- [ ] Body text ≥ 16px · nothing readable below 12px
- [ ] Touch targets ≥ 44×44px

### Required CSS baseline
```css
/* Focus ring — never remove; only restyle */
:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 3px;
  border-radius: 4px;
}

/* Skip link for screen readers */
.skip-link {
  position: absolute;
  transform: translateY(-100%);
  padding: 0.5rem 1rem;
  background: var(--color-brand);
  color: white;
  transition: transform 0.2s;
  z-index: 9999;
}
.skip-link:focus { transform: translateY(0); }

/* Reduce motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Essential ARIA Patterns
```html
<!-- Icon-only button -->
<button aria-label="Close dialog">
  <svg aria-hidden="true" focusable="false">...</svg>
</button>

<!-- Live region for dynamic updates -->
<div role="status" aria-live="polite" aria-atomic="true">3 results loaded</div>

<!-- Loading state -->
<div aria-busy="true" aria-label="Loading dashboard data">...</div>

<!-- Navigation landmark -->
<nav aria-label="Main navigation">...</nav>
```

---

## Phase 7 — Component Recipes

### Dashboard Sidebar
- Fixed 220–260px · full viewport height
- Section labels: overline style (small, uppercase, muted, tracking-wider)
- Active state: colored pill background — not just a color change on text
- Collapse: smooth width transition (not toggle)
- Icon + label pairing must be consistent throughout

### Data Table (Admin)
- Sticky header
- Row hover: `surface-1` bg + 3px left border in accent color
- Sortable: animated chevron (rotates, doesn't swap icons)
- Pagination: "Showing 1–25 of 342" style — minimal chrome

### Metric / KPI Card
- Large, bold number is the hero element (nothing competes with it)
- Trend: colored icon + delta value (green up / red down)
- Sparkline: 24px height max · no axes · pure signal
- Max 4 metrics per row on desktop

### CTA (Landing page)
- One primary action dominates · secondary is visually subordinate
- Button padding ratio: ~1:3 vertical:horizontal (not square)
- Never two primary CTAs side by side
- Hover: position shift + background deepening + shadow (not just color swap)

### Form (SaaS)
- Label always above input (never placeholder-only)
- Inline validation: icon + message adjacent to field
- Multi-step: explicit step indicator with current/total count
- Submit: disable + spinner during async · restore on error

---

## Phase 8 — Anti-Patterns Hall of Shame

These are the fingerprints of generic AI UI. Avoid every single one:

| Anti-pattern | The fix |
|---|---|
| Purple gradient hero on white | Choose a specific palette from Phase 3 |
| Inter or Roboto as the font | Use the approved pairing list |
| Cards with equal visual weight everywhere | Create hierarchy: one feature card, supporting cards |
| Everything center-aligned | Mix left, right, overlap — vary alignment |
| Flat, static buttons | Hover = transform + shadow, press = scale down |
| "Get Started" CTA copy | Specific action: "Launch your first dashboard" |
| Box shadow on every element | Reserve shadows for truly elevated elements only |
| Spinner as the only loading state | Skeleton screens that mirror real layout |
| Hover = color change only | Hover = position + color + shadow combo |
| Single background color throughout | Use 3 surface levels for depth |
| All animations fire simultaneously | Stagger them — sequence tells a visual story |
| `border-radius: 8px` everywhere | Vary: 4px inputs · 12px cards · 999px pills |
| Icon-only button without label | Always `aria-label` on interactive icons |
| Placeholder text as the label | Label above input, always |

---

## Output Checklist

Before delivering any UI, verify:
- [ ] Distinctive font pair chosen (not Inter/Roboto)
- [ ] CSS custom property token system in place
- [ ] At least one staggered entrance animation
- [ ] All interactive hover states defined
- [ ] `prefers-reduced-motion` handled
- [ ] `:focus-visible` styled
- [ ] Semantic HTML + ARIA where needed
- [ ] Contrast ratio checked for primary text/background pairs
- [ ] One layout element that breaks predictability
- [ ] "The One Thing" — the memorable element — is visible
