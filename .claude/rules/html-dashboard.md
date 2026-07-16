# HTML Research Dashboard

Every research project gets a single-page HTML dashboard (`research_overview.html`) that tracks the full pipeline state. It is regenerated after every pipeline-related interaction.

---

## Format: Long Scrollable Page

The dashboard is a **single long scrollable page** with two levels of sticky navigation. No tabs that hide content — every section is always visible.

### Navigation Architecture

```
┌─────────────────────────────────────────────────────┐
│  .main-nav (sticky, top: 0)                         │
│  Overview  Data  Identification  Literature  ...    │
│  ─────────────────────────────────────────────────  │
└─────────────────────────────────────────────────────┘

  ... section content scrolls ...

┌─────────────────────────────────────────────────────┐
│  .section-nav (sticky, top: 46px)                   │
│  [Inventory] [Treatment & IV] [Outcomes] [Wind] ... │
│  ─────────────────────────────────────────────────  │
└─────────────────────────────────────────────────────┘

  ... sub-section content scrolls ...
```

- **Main nav** (`.main-nav`): sticky at `top: 0`, `z-index: 10`. Links to each `<section id="...">`. Active section highlighted in clay via IntersectionObserver.
- **Section sub-nav** (`.section-nav`): inline within each section, below the `<h2>`. Sticky at `top: 46px`, `z-index: 5`. Pill-style links to `<h3 id="...">` anchors within that section. Active sub-section highlighted in clay via a second IntersectionObserver.

### Active State Highlighting

Both navs highlight the current position as the user scrolls. This uses two simple IntersectionObservers:

```javascript
// Main nav: highlight active section
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('.main-nav a');
const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      navLinks.forEach(a => a.classList.toggle('active',
        a.getAttribute('href') === '#' + entry.target.id));
    }
  });
}, { rootMargin: '-50px 0px -60% 0px' });
sections.forEach(s => observer.observe(s));

// Sub-nav: highlight active sub-section
const subHeadings = document.querySelectorAll('h3[id]');
const subLinks = document.querySelectorAll('.section-nav a');
const subObserver = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const href = '#' + entry.target.id;
      subLinks.forEach(a => a.classList.toggle('active',
        a.getAttribute('href') === href));
    }
  });
}, { rootMargin: '-100px 0px -60% 0px' });
subHeadings.forEach(h => subObserver.observe(h));
```

### CSS for Navigation

```css
/* Main nav: sticky at top */
.main-nav { position: sticky; top: 0; z-index: 10; background: var(--ivory);
  padding: 12px 0 0; border-bottom: 2px solid var(--g300); margin: 28px 0 0;
  display: flex; gap: 6px; flex-wrap: wrap; }
.main-nav a { font-size: 13px; font-weight: 500; padding: 8px 16px 12px;
  color: var(--g500); text-decoration: none; border-bottom: 3px solid transparent;
  margin-bottom: -2px; transition: color 0.12s, border-color 0.12s; }
.main-nav a:hover { color: var(--slate); text-decoration: none; }
.main-nav a.active { color: var(--clay); border-bottom-color: var(--clay); }

/* Section sub-nav: sticky below main nav */
.section-nav { position: sticky; top: 46px; z-index: 5; background: var(--ivory);
  display: flex; gap: 6px; flex-wrap: wrap; padding: 10px 0;
  border-bottom: 1px solid var(--g200); margin: 0 0 24px; }
.section-nav a { font-size: 12.5px; font-weight: 500; padding: 6px 14px;
  border: 1.5px solid var(--g300); border-radius: 999px; color: var(--g500);
  text-decoration: none; transition: border-color 0.12s, color 0.12s; }
.section-nav a:hover { border-color: var(--slate); color: var(--slate); }
.section-nav a.active { border-color: var(--clay); color: var(--clay); }
```

### Scroll Margins

```css
html { scroll-behavior: smooth; }
section { scroll-margin-top: 52px; }     /* clears main nav */
h3[id] { scroll-margin-top: 100px; }     /* clears main nav + section nav */
```

### Structure

```
Header (title, stats row: target journal, word limit, counties, panel years)
Main nav (sticky, anchor links to each section)

Section: Overview
  Section sub-nav: [Question] [Causal Chain] [Contributions] [Risks]
  - Abstract / research question
  - Causal chain diagram
  - Contributions (grid of cards)
  - Risk matrix (table with status pills)

Section: Data
  Section sub-nav: [Inventory] [Treatment & IV] [Outcomes] [Mechanism] [Wind] [Downloads]
  - Master inventory table
  - Treatment & IV details (cards)
  - Outcomes (cards per variable)
  - Mechanism variables
  - Wind/instrument deep-dive
  - Download queue

Section: Identification
  Section sub-nav: [Design] [Threats] [Fallback] [Prediction]
  - First/second stage equations
  - Exclusion restriction threats
  - Fallback design
  - Key prediction

Section: Literature
  Section sub-nav: [Where We Sit] [Scooping Risk] [Closest] [Related] [Gaps] [Critic] [Titles]
  - Three-literature positioning table
  - Contribution statement
  - Scooping risk cards
  - Papers by proximity
  - Gaps we fill
  - Critic score
  - Title options

Section: Results
  - Empty state until estimation runs

Section: Paper
  - Figure/table budget
  - Word allocation by section
```

### Design System

Use the clo-author design system from `templates/html/base/styles.css`:
- Palette: ivory/clay/serif (light) with automatic dark mode
- Components: cards, pills, stat rows, report tables, collapsibles, alerts
- Self-contained: all CSS inline, no external dependencies
- Print-friendly: both navs hidden, all content visible

### Rules

1. **Long page, no tabs.** All sections visible as you scroll.
2. **Smooth scroll everywhere.** `html { scroll-behavior: smooth; }` — clicking any link fluidly rolls, never jumps.
3. **Two levels of sticky nav.** Main nav at `top: 0`, section sub-nav at `top: 46px`. Both inside `.page` (not outside it).
4. **Both navs highlight active position.** Main nav underlines the current section in clay. Sub-nav pills highlight the current sub-section in clay. Both via IntersectionObserver.
5. **No `overflow-x: auto`** on navigation — causes ugly scrollbars.
6. **Collapsibles only for genuinely optional detail.**
7. **Every section keeps full detail** — long page doesn't mean less content.
8. **Status pills on everything** — IN HAND, READY, FOUND, PARTIAL, NEEDS AGG, GAP.
9. **Self-contained HTML** — one file, no dependencies. Shareable as email attachment.
10. **No complex JS.** Two simple IntersectionObservers for highlighting + collapsible toggles. Nothing else.

---

## When to Regenerate

The dashboard is updated after any interaction that changes pipeline state:

| Trigger | What updates |
|---------|-------------|
| `/discover data` completes | Data section: new sources, status pills |
| `/discover lit` completes | Literature section: papers, positioning, gaps |
| `/strategize` completes | Identification section: equations, threats, prediction |
| `/analyze` produces results | Results section: tables, figures |
| `/write` drafts sections | Paper section: word counts, completion status |
| `/paper-review` scores paper | Critic scores throughout |
| Data files added/verified | Data section: status pills updated |
| Risk resolved | Overview: risk matrix updated |

### How to regenerate

After any pipeline skill completes, rebuild `research_overview.html` by:
1. Reading current project state (CLAUDE.md, quality_reports/, Data/, git status)
2. Preserving all existing content
3. Updating only the sections affected by the latest change
4. Opening the file in the browser for the user

---

## Empty States

Sections that haven't been populated yet show an empty state card:
```html
<div class="empty-state">
  <p><strong>Not yet started.</strong></p>
  <p>This section will populate when [specific action] runs.</p>
</div>
```
