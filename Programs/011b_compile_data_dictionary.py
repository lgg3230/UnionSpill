"""
011b_compile_data_dictionary.py
================================
Converts corrected_turnover_data_dictionary.md to a formatted PDF
using reportlab. Parses markdown headings, paragraphs, code blocks,
bullet lists, and tables.
"""

import re
import os
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Preformatted,
    Table, TableStyle, HRFlowable, KeepTogether,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
MD_FILE  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/corrected_turnover_data_dictionary.md")
PDF_FILE = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/corrected_turnover_data_dictionary.pdf")

# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
BASE = getSampleStyleSheet()

H1 = ParagraphStyle("H1", parent=BASE["Heading1"],
                    fontSize=16, spaceAfter=8, spaceBefore=16,
                    textColor=colors.HexColor("#1a1a2e"))
H2 = ParagraphStyle("H2", parent=BASE["Heading2"],
                    fontSize=13, spaceAfter=6, spaceBefore=14,
                    textColor=colors.HexColor("#16213e"),
                    borderPad=2)
H3 = ParagraphStyle("H3", parent=BASE["Heading3"],
                    fontSize=11, spaceAfter=4, spaceBefore=10,
                    textColor=colors.HexColor("#0f3460"),
                    fontName="Helvetica-Bold")
BODY = ParagraphStyle("Body", parent=BASE["Normal"],
                      fontSize=9.5, leading=14, spaceAfter=4,
                      fontName="Helvetica")
BODY_BOLD = ParagraphStyle("BodyBold", parent=BODY,
                            fontName="Helvetica-Bold")
CODE = ParagraphStyle("Code", parent=BASE["Code"],
                      fontSize=8, leading=11, leftIndent=20,
                      fontName="Courier", backColor=colors.HexColor("#f5f5f5"),
                      spaceAfter=6, spaceBefore=4, borderPad=4)
BULLET = ParagraphStyle("Bullet", parent=BODY,
                         leftIndent=24, bulletIndent=12,
                         spaceAfter=2, bulletFontSize=9.5)
META = ParagraphStyle("Meta", parent=BODY,
                      fontSize=8.5, textColor=colors.HexColor("#555555"),
                      spaceAfter=2)

# Table header style
TH = ParagraphStyle("TH", parent=BODY, fontName="Helvetica-Bold",
                    fontSize=8.5, leading=11)
TD = ParagraphStyle("TD", parent=BODY, fontSize=8.5, leading=11)

# ---------------------------------------------------------------------------
# Inline markdown → reportlab XML
# ---------------------------------------------------------------------------
def inline(text):
    """Convert inline markdown (bold, code, italic) to reportlab XML."""
    # Escape XML special chars first
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Bold+italic ***text*** or ___text___
    text = re.sub(r'\*\*\*(.+?)\*\*\*', r'<b><i>\1</i></b>', text)
    # Bold **text** or __text__
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    # Italic *text* or _text_  (avoid underscore in identifiers)
    text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', text)
    # Inline code `text`
    text = re.sub(r'`([^`]+)`', r'<font name="Courier" size="8.5">\1</font>', text)
    return text

# ---------------------------------------------------------------------------
# Parse markdown into flowables
# ---------------------------------------------------------------------------
def parse_md(path):
    with open(path, "r") as f:
        lines = f.readlines()

    flowables = []
    i = 0

    def add_spacer(h=4):
        flowables.append(Spacer(1, h))

    while i < len(lines):
        line = lines[i].rstrip("\n")

        # --- Horizontal rule ---
        if re.match(r'^---+\s*$', line):
            flowables.append(HRFlowable(width="100%", thickness=0.5,
                                        color=colors.HexColor("#cccccc"),
                                        spaceAfter=6, spaceBefore=6))
            i += 1
            continue

        # --- H1 ---
        if line.startswith("# ") and not line.startswith("## "):
            flowables.append(Paragraph(inline(line[2:].strip()), H1))
            i += 1
            continue

        # --- H2 ---
        if line.startswith("## ") and not line.startswith("### "):
            flowables.append(Paragraph(inline(line[3:].strip()), H2))
            i += 1
            continue

        # --- H3 ---
        if line.startswith("### "):
            flowables.append(Paragraph(inline(line[4:].strip()), H3))
            i += 1
            continue

        # --- Code block ---
        if line.startswith("```"):
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i].rstrip("\n"))
                i += 1
            i += 1  # skip closing ```
            code_text = "\n".join(code_lines)
            flowables.append(Preformatted(code_text, CODE))
            add_spacer(4)
            continue

        # --- Pipe table ---
        if line.startswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].startswith("|"):
                table_lines.append(lines[i].rstrip("\n"))
                i += 1
            # Parse rows, skip separator rows (|----|)
            rows = []
            is_header = True
            for tl in table_lines:
                cells = [c.strip() for c in tl.strip("|").split("|")]
                if all(re.match(r'^[-: ]+$', c) for c in cells):
                    continue  # separator row
                style = TH if is_header else TD
                rows.append([Paragraph(inline(c), style) for c in cells])
                is_header = False

            if rows:
                col_count = len(rows[0])
                avail = 6.5 * inch  # usable width
                col_width = avail / col_count
                t = Table(rows, colWidths=[col_width] * col_count,
                          repeatRows=1)
                t.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e8eaf6")),
                    ("GRID",       (0, 0), (-1, -1), 0.4, colors.HexColor("#bbbbbb")),
                    ("VALIGN",     (0, 0), (-1, -1), "TOP"),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1),
                     [colors.white, colors.HexColor("#f9f9f9")]),
                    ("LEFTPADDING",  (0, 0), (-1, -1), 5),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                    ("TOPPADDING",   (0, 0), (-1, -1), 3),
                    ("BOTTOMPADDING",(0, 0), (-1, -1), 3),
                ]))
                flowables.append(t)
                add_spacer(8)
            continue

        # --- Bullet list item ---
        m = re.match(r'^(\s*)[-*]\s+(.*)', line)
        if m:
            indent_lvl = len(m.group(1)) // 2
            bullet_style = ParagraphStyle(
                f"Bullet{indent_lvl}", parent=BULLET,
                leftIndent=24 + indent_lvl * 16,
                bulletIndent=12 + indent_lvl * 16,
            )
            flowables.append(Paragraph(
                f"• {inline(m.group(2))}",
                bullet_style
            ))
            i += 1
            continue

        # --- Blank line ---
        if line.strip() == "":
            add_spacer(3)
            i += 1
            continue

        # --- Meta lines (bold-key: value pattern after # lines, like **Generated by:** ...) ---
        # treated as normal body text
        flowables.append(Paragraph(inline(line), BODY))
        i += 1

    return flowables

# ---------------------------------------------------------------------------
# Build PDF
# ---------------------------------------------------------------------------
print(f"Parsing {MD_FILE} ...")
story = parse_md(MD_FILE)

print(f"Writing PDF to {PDF_FILE} ...")
doc = SimpleDocTemplate(
    PDF_FILE,
    pagesize=LETTER,
    leftMargin=1.0 * inch,
    rightMargin=1.0 * inch,
    topMargin=1.0 * inch,
    bottomMargin=1.0 * inch,
    title="Data Dictionary: corrected_turnover_sample.csv",
    author="Luis de Azevedo-Gomes and Guilherme Neri",
)
doc.build(story)
print("Done.")
