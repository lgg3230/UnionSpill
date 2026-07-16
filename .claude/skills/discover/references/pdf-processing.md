# PDF Processing Workflow

Safe workflow for reading and extracting content from reference papers uploaded to `master_supporting_docs/`.

## Step 1: Receive PDF Upload
- User uploads PDF to `master_supporting_docs/supporting_papers/` or `supporting_slides/`
- Do NOT attempt to read the full PDF directly -- large PDFs will fail

## Step 2: Check PDF Properties
```bash
pdfinfo paper_name.pdf | grep "Pages:"
ls -lh paper_name.pdf
```

## Step 3: Create Subfolder and Split
```bash
mkdir -p paper_name/

for i in {0..9}; do
  start=$((i*5 + 1))
  end=$(((i+1)*5))
  gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER \
     -dFirstPage=$start -dLastPage=$end \
     -sOutputFile="paper_name/paper_name_p$(printf '%03d' $start)-$(printf '%03d' $end).pdf" \
     paper_name.pdf 2>/dev/null
done
```

## Step 4: Process Chunks Intelligently
- Read chunks ONE AT A TIME using the Read tool
- Extract key information from each chunk
- Build understanding progressively
- Don't try to hold all chunks in working memory

## Step 5: Selective Deep Reading
- After scanning all chunks, identify the most relevant sections
- Only read those sections in detail
- Skip appendices, references, or less relevant sections unless needed

## Error Handling

**If a chunk fails to process:**
1. Note the problematic chunk (e.g., "Chunk p021-025 failed")
2. Try splitting into 1-2 page pieces
3. If still failing, skip and document the gap

**If splitting fails:**
1. Check if Ghostscript is installed: `gs --version`
2. Try alternative: `pdftk paper.pdf burst output paper_%03d.pdf`
3. If all else fails, ask user to upload specific page ranges manually

**If memory/token issues persist:**
1. Process only 2-3 chunks per session
2. Focus on specific sections user identifies as most important

## Page Limit Reminder
The Read tool supports PDF files with a `pages` parameter (e.g., `pages: "1-5"`). For large PDFs (more than 10 pages), always specify page ranges. Maximum 20 pages per request.
