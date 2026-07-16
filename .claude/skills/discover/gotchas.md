# Discover Skill -- Gotchas

Known failure points and edge cases for research discovery.

- Interview mode works best when the user has a vague idea -- if they already have a clear question, skip to `/strategize`.
- Literature search favors recent papers (last 5 years). Explicitly ask for seminal/foundational papers if the field has important older work.
- Data assessment grades are relative to the research question -- an A-grade dataset for one project may be C-grade for another.
- PDF processing has page limits -- for large papers, specify page ranges rather than reading the full document.
- Web search results can include retracted or predatory journal papers. Always verify journal quality.
- The librarian and explorer agents run in parallel during discovery -- they don't coordinate. Synthesis happens after both complete.
- Never fabricate citations. If you cannot verify a citation, mark the BibTeX entry with `% UNVERIFIED`.
- Citation chains (forward and backward) are often the most productive search vector -- don't skip them.
- Always assign proximity scores (1-5) to every paper found. This is not optional.
