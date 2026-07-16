# Style Extraction Protocol

How to extract a personal writing voice from a corpus of the user's prior papers and produce `.claude/references/personal-style-guide.md`.

This protocol is activated by `/write style-guide [paper-dir]`.

---

## Protocol

### 1. Discover Corpus

Glob `.tex` and `.pdf` files in the target directory. If fewer than 2 papers, stop and flag -- one paper overfits.

### 2. Sample Strategically

For each paper:
- Full introduction
- First two paragraphs of each major section (Strategy, Data, Results, Conclusion)
- Abstract and conclusion
- 5--10 randomly sampled results-section paragraphs

This keeps context usage bounded while capturing voice variation across sections.

### 3. Extract Patterns

Compute or observe:

- **Sentence length:** median, 10th percentile, 90th percentile (in words)
- **Voice:** passive-voice frequency, first-person-plural frequency
- **Punctuation signatures:** em dash rate per paragraph, semicolon usage, parenthetical frequency
- **Paragraph openings:** the 3--5 most common opening patterns, with quoted examples
- **Paragraph closings:** same
- **Section openings:** how introductions open, how strategy sections open, how results sections open
- **Lexicon used:** recurring content words and phrases (not function words) -- quote examples
- **Lexicon avoided:** scan for words the author never uses that other economists commonly use (e.g., "delve", "leverage", "nuanced", "robust")
- **Hedging patterns:** what hedges appear and in what contexts
- **Comparison patterns:** how the author compares their estimate to prior estimates
- **Citation split:** textual vs. parenthetical ratio, papers-per-claim
- **Tone markers:** self-deprecating? bold? dry? confident? -- with quoted evidence

### 4. Write to `.claude/references/personal-style-guide.md`

Fill every section of the template. For each pattern, include at least one quoted example from the corpus. If a section has no evidence, write `[insufficient corpus evidence]`.

### 5. Self-Citation Check

Scan the sampled papers for `\cite{}`, `\citet{}`, `\citep{}` commands referencing the author's own prior work. List any citation keys found. Cross-check each against `UnionSpill-paper/bib.bib` in the current project. If any self-citation keys are missing from the bib, include a `## Self-Citation Gaps` appendix in the style guide output listing them -- so future `/write` calls don't invent or drop those references.

### 6. Present Summary

One paragraph to the user summarizing the extracted voice, plus a note if the self-citation check surfaced missing bib entries.

---

## Rules for Style Extraction

- **Ground every claim in the corpus.** No invented patterns.
- **Quote, don't paraphrase.** Examples are verbatim excerpts with paper filename.
- **Extract, don't prescribe.** Record what the author does, not what you think is good style.
- **Don't duplicate `domain-profile.md`.** Voice, not field conventions.
- **Stay under context.** If the corpus is large (>5 papers), subsample to stay within budget -- note which papers were sampled.

---

## What Extraction Mode Does NOT Do

- Does NOT draft any paper content
- Does NOT edit any paper files
- Does NOT invent style rules the corpus does not support
- Does NOT apply the guide -- that happens on the next `/write` call in drafting mode
