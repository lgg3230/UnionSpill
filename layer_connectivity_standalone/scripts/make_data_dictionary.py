#!/usr/bin/env python3
"""
Generate layer_connectivity_data_dictionary.pdf — three-dataset variable dictionary
matching the style of worker_panel_lagos_data_dictionary.pdf.

Datasets covered:
  1. totalflows_wide_2007_2011.csv
  2. firm_layer_outcomes_{layer}.dta   (edu2 / gender / race)
  3. firm_layer_connectivity_{layer}.dta  (edu2 / gender / race)

Usage:
    python make_data_dictionary.py
Output:
    /kellogg/proj/lgg3230/UnionSpill/layer_connectivity_data_dictionary.pdf
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

# ── Output path ───────────────────────────────────────────────────────────────
OUT = "/kellogg/proj/lgg3230/UnionSpill/layer_connectivity_data_dictionary.pdf"

# ── Colours (match existing dict) ────────────────────────────────────────────
NAVY      = colors.HexColor("#1B3A6B")
MID_NAVY  = colors.HexColor("#2E5FA3")
LIGHT_ROW = colors.HexColor("#EBF0F8")
WHITE     = colors.white
HEADER_TXT = colors.white

# ── Styles ────────────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()
base   = styles["Normal"]

S = {
    "title": ParagraphStyle("title", parent=base,
        fontName="Helvetica-Bold", fontSize=20, leading=24,
        alignment=TA_CENTER, textColor=NAVY, spaceAfter=4),
    "meta": ParagraphStyle("meta", parent=base,
        fontName="Helvetica", fontSize=9, leading=13,
        alignment=TA_LEFT, textColor=colors.black),
    "meta_bold": ParagraphStyle("meta_bold", parent=base,
        fontName="Helvetica-Bold", fontSize=9, leading=13,
        alignment=TA_LEFT, textColor=colors.black),
    "body": ParagraphStyle("body", parent=base,
        fontName="Helvetica", fontSize=8.5, leading=12,
        textColor=colors.black),
    "note": ParagraphStyle("note", parent=base,
        fontName="Helvetica", fontSize=8, leading=11,
        textColor=colors.HexColor("#333333")),
    "h1": ParagraphStyle("h1", parent=base,
        fontName="Helvetica-Bold", fontSize=13, leading=16,
        textColor=HEADER_TXT, backColor=NAVY,
        spaceAfter=0, spaceBefore=14,
        leftIndent=-6, rightIndent=-6,
        borderPad=4),
    "h2": ParagraphStyle("h2", parent=base,
        fontName="Helvetica-Bold", fontSize=10.5, leading=14,
        textColor=MID_NAVY, spaceBefore=10, spaceAfter=2),
    "cell": ParagraphStyle("cell", parent=base,
        fontName="Helvetica", fontSize=8, leading=10),
    "cell_bold": ParagraphStyle("cell_bold", parent=base,
        fontName="Helvetica-Bold", fontSize=8, leading=10),
    "footer": ParagraphStyle("footer", parent=base,
        fontName="Helvetica", fontSize=7.5, leading=10,
        alignment=TA_CENTER, textColor=colors.HexColor("#666666")),
    "construction_head": ParagraphStyle("construction_head", parent=base,
        fontName="Helvetica-Bold", fontSize=9, leading=12,
        textColor=MID_NAVY, spaceBefore=8),
}

# ── Helpers ───────────────────────────────────────────────────────────────────
def p(text, style="body"):
    return Paragraph(text, S[style])

def sp(h=6):
    return Spacer(1, h)

def hr():
    return HRFlowable(width="100%", thickness=1,
                      color=colors.HexColor("#C8D4E8"), spaceAfter=6)

def section_header(text):
    """Dark navy full-width section bar."""
    return p(f"&nbsp;&nbsp;{text}", "h1")

def subsection(text):
    return p(text, "h2")

# ── Table builders ────────────────────────────────────────────────────────────
_TS_BASE = [
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("TEXTCOLOR",  (0, 0), (-1, 0), HEADER_TXT),
    ("FONTNAME",   (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE",   (0, 0), (-1, 0), 8),
    ("FONTNAME",   (0, 1), (-1, -1), "Helvetica"),
    ("FONTSIZE",   (0, 1), (-1, -1), 8),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, LIGHT_ROW]),
    ("GRID",       (0, 0), (-1, -1), 0.4, colors.HexColor("#B0BDD0")),
    ("VALIGN",     (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ("LEFTPADDING",   (0, 0), (-1, -1), 5),
    ("RIGHTPADDING",  (0, 0), (-1, -1), 5),
]

def make_table(headers, rows, col_widths, wrap_cols=None):
    """Build a styled table. wrap_cols: list of col indices to wrap as Paragraphs."""
    wrap_cols = wrap_cols or []
    data = [[p(h, "cell_bold") for h in headers]]
    for row in rows:
        data.append([
            p(str(cell), "cell") if i in wrap_cols else Paragraph(str(cell), S["cell"])
            for i, cell in enumerate(row)
        ])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle(_TS_BASE))
    return t


# ═══════════════════════════════════════════════════════════════════════════════
# CONTENT
# ═══════════════════════════════════════════════════════════════════════════════
doc = SimpleDocTemplate(
    OUT,
    pagesize=letter,
    leftMargin=0.75 * inch,
    rightMargin=0.75 * inch,
    topMargin=0.75 * inch,
    bottomMargin=0.75 * inch,
)
W = doc.width  # usable width

story = []

# ── Title ─────────────────────────────────────────────────────────────────────
story += [
    p("Variable Dictionary", "title"),
    p("<b>Project:</b> UnionSpill — Layer Connectivity Pipeline", "meta"),
    p("<b>Authors:</b> Luis de Azevedo-Gomes &amp; Guilherme Neri", "meta"),
    sp(4),
    p("This dictionary covers three datasets produced by the layer connectivity pipeline "
      "(<tt>Programs/layer_connectivity/</tt>). They are used as inputs to "
      "<tt>07_layer_spillover.do</tt> to estimate within-firm, cross-layer spillover "
      "effects of the Súmula 277 reform.", "body"),
    sp(8),
    hr(),
]

# ══════════════════════════════════════════════════════════════════════════════
# DATASET 1 — totalflows_wide
# ══════════════════════════════════════════════════════════════════════════════
story += [
    section_header("Dataset 1 — totalflows_wide_2007_2011.csv"),
    sp(8),
    p("<b>File:</b> totalflows_wide_2007_2011.csv &nbsp;|&nbsp; "
      "<b>Path:</b> Data/RAIS_aux/", "meta"),
    p("<b>Unit of observation:</b> establishment &nbsp;|&nbsp; "
      "<b>Rows:</b> 16,470 firms &nbsp;|&nbsp; "
      "<b>Year pairs covered:</b> 2007–08, 2008–09, 2009–10, 2010–11", "meta"),
    sp(8),
    p("This file contains firm-level total worker flows for each of the four pre-treatment "
      "year pairs. A \"flow\" between years t and t+1 counts any worker who was employed at "
      "the focal firm in December of year t <i>or</i> December of year t+1 (outflows + inflows). "
      "The file is constructed in <tt>05_yearly_employers.do</tt> and used in "
      "<tt>07_layer_spillover.do</tt> for the firm-level restricted specification.", "body"),
    sp(10),
]

# 1.1 Identifier
story += [subsection("1.1 Identifier"), sp(2)]
story.append(make_table(
    ["Variable", "Type", "Description"],
    [
        ["identificad", "INTEGER",
         "14-digit establishment identifier (CNPJ-base). "
         "Note: stored as integer here; must be read with stringcols(1) in Stata "
         "or cast to VARCHAR for joins with other pipeline files that store it as a 14-char string."],
    ],
    [1.2*inch, 0.8*inch, W - 2.0*inch],
    wrap_cols=[2],
))
story.append(sp(10))

# 1.2 Total flows
story += [
    subsection("1.2 Total Flow Variables"),
    sp(3),
    p("For each year pair <i>AB</i> (07_08, 08_09, 09_10, 10_11), two variables are provided. "
      "Flows are symmetric: a worker who left in year A or arrived in year B is counted once. "
      "Null values arise when the firm does not appear in one of the two annual RAIS cross-sections "
      "(typically newly-entered or exiting firms at the edge of the panel).", "body"),
    sp(6),
]
story.append(make_table(
    ["Variable", "Type", "Mean", "Max", "Nulls", "Description"],
    [
        ["totalflows_<i>AB</i>", "DOUBLE", "~25.3", "~4,149", "~722 (07_08)",
         "Raw count of worker flows between the focal firm and all other firms "
         "in year pair AB. Equals outflows + inflows, where an outflow is a "
         "worker present in December t and absent in December t+1 (at this firm), "
         "and an inflow is the reverse."],
        ["totalflows_pw_<i>AB</i>", "DOUBLE", "~0.26", "2.00", "same as above",
         "Per-worker flow rate: totalflows_AB / E_avg, where E_avg = "
         "(December employment in year t + December employment in year t+1) / 2. "
         "Values above 1 are possible when flows exceed average employment "
         "(high-turnover firms). Used in pre-treatment control bins."],
    ],
    [1.5*inch, 0.55*inch, 0.45*inch, 0.45*inch, 0.65*inch, W - 3.6*inch],
    wrap_cols=[0, 5],
))
story.append(sp(10))

story += [
    sp(14),
    hr(),
]

# ══════════════════════════════════════════════════════════════════════════════
# DATASET 2 — firm_layer_outcomes
# ══════════════════════════════════════════════════════════════════════════════
story += [
    section_header("Dataset 2 — firm_layer_outcomes_{layer}.dta"),
    sp(8),
    p("<b>Files:</b> firm_layer_outcomes_edu2.dta &nbsp;|&nbsp; "
      "firm_layer_outcomes_gender.dta &nbsp;|&nbsp; firm_layer_outcomes_race.dta",
      "meta"),
    p("<b>Path:</b> Data/layer_connectivity/ &nbsp;|&nbsp; "
      "<b>Unit:</b> establishment × layer × year &nbsp;|&nbsp; "
      "<b>Years:</b> 2009–2016", "meta"),
    sp(4),
]

# Row-count table
story.append(make_table(
    ["Layer", "Layer values", "Rows", "Unique firms"],
    [
        ["edu",    "0_no_hs / 1_hs / 2_higher", "316,833", "16,471"],
        ["edu2",   "no_hs / has_hs",             "221,440", "16,471"],
        ["gender", "female / male",               "245,823", "16,471"],
        ["race",   "nonwhite / white",            "230,047", "16,448"],
    ],
    [0.7*inch, 1.5*inch, 0.85*inch, 1.0*inch],
))
story.append(sp(8))

story += [
    p("Built by <tt>06_prep_layer_outcomes.py</tt> (edu2) and <tt>06_prep_demog_outcomes.py</tt> "
      "(gender, race) from <tt>worker_panel_lagos.parquet</tt>. Each row represents one "
      "firm–layer–year cell: all workers at the focal establishment in December of that year "
      "who belong to the layer (education bin, gender, or race group). Outcomes are computed "
      "as the count and within-cell averages of the relevant worker-level variables.", "body"),
    sp(10),
]

# 2.1 Identifiers
story += [subsection("2.1 Identifiers"), sp(2)]
story.append(make_table(
    ["Variable", "Type", "Description"],
    [
        ["identificad", "VARCHAR",
         "14-digit establishment identifier (CNPJ-base). Stored as a zero-padded "
         "14-character string (e.g., '00001961000110'). Join key with "
         "firm_layer_connectivity_{layer}.dta."],
        ["layer_id", "VARCHAR",
         "Layer membership of the workers in this cell. Values depend on the layer: "
         "edu2 → {no_hs, has_hs}; gender → {female, male}; race → {nonwhite, white}. "
         "Workers with missing layer information are excluded. "
         "Together with identificad and year this forms the unique observation key."],
        ["year", "INTEGER",
         "Calendar year of the December 31 stock. Range: 2009–2016. "
         "Only years ≥ 2009 are used in regressions (post-reform data begins 2012)."],
    ],
    [1.2*inch, 0.8*inch, W - 2.0*inch],
    wrap_cols=[2],
))
story.append(sp(10))

# 2.2 Layer definitions
story += [subsection("2.2 Layer Definitions"), sp(2)]
story.append(make_table(
    ["Layer", "Variable", "Source field", "Mapping"],
    [
        ["edu",
         "layer_id ∈ {0_no_hs, 1_hs, 2_higher}",
         "grinstrucao",
         "0_no_hs: grinstrucao ∈ {2,3,4,5} (up to complete primary / less than high school). "
         "1_hs: grinstrucao ∈ {6,7} (incomplete or complete secondary). "
         "2_higher: grinstrucao ∈ {8,9} (incomplete or complete higher education). "
         "Derived from educ_bin in worker_panel_lagos.parquet using pd.cut(grinstrucao, bins=[0,6,8,11])."],
        ["edu2",
         "layer_id ∈ {no_hs, has_hs}",
         "grinstrucao",
         "no_hs: grinstrucao ∈ {2,3,4,5} (up to complete primary). "
         "has_hs: grinstrucao ∈ {6,7,8,9} (some secondary or above). "
         "Derived by remapping the 3-bin educ_bin variable: "
         "0_no_hs → no_hs; {1_hs, 2_higher} → has_hs."],
        ["gender",
         "layer_id ∈ {female, male}",
         "genero",
         "female: genero = 0. male: genero = 1. Workers with missing genero excluded."],
        ["race",
         "layer_id ∈ {nonwhite, white}",
         "raca_cor",
         "white: raca_cor = 2 (branca). nonwhite: raca_cor ∈ {8 parda, 4 preta}. "
         "Excludes indígena (9), amarela (6), and missing/undeclared. "
         "~5 % of workers are excluded from the race layer for this reason."],
    ],
    [0.55*inch, 1.3*inch, 0.9*inch, W - 2.75*inch],
    wrap_cols=[1, 2, 3],
))
story.append(sp(10))

# 2.3 Outcomes
story += [subsection("2.3 Outcome Variables"), sp(3)]
story += [
    p("All outcomes are computed at the firm–layer–year cell level from "
      "<tt>worker_panel_lagos.parquet</tt> (workers with empem3112 = 1, "
      "remdezr &gt; 0, horascontr &gt; 0). Statistics below pool all layers "
      "and years for edu2.", "body"),
    sp(6),
]
story.append(make_table(
    ["Variable", "Type", "Min", "Mean", "Max", "Nulls", "Description"],
    [
        ["layer_emp", "INTEGER", "1", "84.9 (edu2)\n76.5 (gender)\n77.7 (race)",
         "11,494–18,209", "0",
         "Count of workers in the layer at this firm in December of the given year "
         "(COUNT of PIS values in the cell). Denominator for within-cell averages. "
         "Minimum is 1 by construction (cells with zero workers don't appear)."],
        ["lr_remdezr_layer", "DOUBLE",
         "5.40 (edu2)", "7.67 (edu2)\n7.80 (gender)\n7.81 (race)", "11.57", "0",
         "Within-cell average of log December earnings deflated to Dec 2015 BRL. "
         "Computed as AVG(lr_remdezr) over workers in the cell, where "
         "lr_remdezr = log(remdezr / IPCA_t). IPCA deflators: "
         "2009=0.6716, 2010=0.7113, 2011=0.7575, 2012=0.8048, "
         "2013=0.8551, 2014=0.9104, 2015=1.0000, 2016=1.0690."],
        ["lr_remdezr_h_layer", "DOUBLE",
         "0.61 (edu2)", "1.65 (edu2)\n1.72 (gender)\n1.73 (race)", "3.59", "0",
         "Within-cell average of log hourly earnings (deflated). Computed as "
         "AVG(log(remdezr / horascontr / IPCA_t)) at the worker level before "
         "averaging — not equivalent to lr_remdezr_layer minus log(hours). "
         "Workers with horascontr = 0 or remdezr = 0 are excluded."],
        ["l_layer_emp", "DOUBLE", "0.00", "2.85 (edu2)\n2.74 (gender)\n2.71 (race)",
         "9.81", "0",
         "Log of layer_emp: ln(layer_emp). Zero maps to 0 (one-worker cells). "
         "Used as the size outcome and as a control in regressions."],
    ],
    [1.4*inch, 0.55*inch, 0.5*inch, 1.15*inch, 0.5*inch, 0.4*inch, W - 4.5*inch],
    wrap_cols=[0, 3, 6],
))
story.append(sp(14))
story.append(hr())

# ══════════════════════════════════════════════════════════════════════════════
# DATASET 3 — firm_layer_connectivity
# ══════════════════════════════════════════════════════════════════════════════
story += [
    section_header("Dataset 3 — firm_layer_connectivity_{layer}.dta"),
    sp(8),
    p("<b>Files:</b> firm_layer_connectivity_edu2.dta &nbsp;|&nbsp; "
      "firm_layer_connectivity_gender.dta &nbsp;|&nbsp; "
      "firm_layer_connectivity_race.dta",
      "meta"),
    p("<b>Path:</b> Data/layer_connectivity/final_measures/ &nbsp;|&nbsp; "
      "<b>Unit:</b> establishment × layer (time-invariant) &nbsp;|&nbsp; "
      "<b>Period:</b> pre-treatment averages over 2007–2011 year pairs",
      "meta"),
    sp(4),
]

story.append(make_table(
    ["Layer", "Rows", "Unique firms", "Layer values"],
    [
        ["edu",    "44,946", "17,708", "0_no_hs / 1_hs / 2_higher"],
        ["edu2",   "31,237", "17,708", "no_hs / has_hs"],
        ["gender", "33,767", "17,708", "female / male"],
        ["race",   "32,355", "17,663", "nonwhite / white"],
    ],
    [0.7*inch, 0.85*inch, 1.0*inch, 1.5*inch],
))
story.append(sp(8))

story += [
    p("Built by <tt>02_aggregate.py</tt> / <tt>02d_aggregate_demog.py</tt> "
      "(year-pair components) and <tt>03_compute_n.py</tt> / "
      "<tt>03d_compute_n_demog.py</tt> (NaN-aware averages). "
      "The construction uses worker transition records from "
      "<tt>transitions_{layer}.parquet</tt>. Each observation corresponds to one "
      "firm–layer cell and records how connected that cell is to treated firms "
      "(those covered by CBAs affected by the Súmula 277 reform) via worker flows "
      "in the pre-treatment period.", "body"),
    sp(10),
]

# 3.1 Identifiers
story += [subsection("3.1 Identifiers"), sp(2)]
story.append(make_table(
    ["Variable", "Type", "Description"],
    [
        ["identificad", "VARCHAR",
         "14-digit establishment identifier (zero-padded 14-char string, e.g., "
         "'00001961000110'). Join key with firm_layer_outcomes_{layer}.dta "
         "on (identificad, layer_id)."],
        ["layer_id", "VARCHAR",
         "Layer of the focal firm cell. Same values as in firm_layer_outcomes: "
         "edu2 → {no_hs, has_hs}; gender → {female, male}; race → {nonwhite, white}. "
         "A firm appears once per layer in which it has at least one worker-year "
         "transition record."],
    ],
    [1.2*inch, 0.8*inch, W - 2.0*inch],
    wrap_cols=[2],
))
story.append(sp(10))

# 3.3 Year-pair variables
story += [
    subsection("3.2 Year-Pair Variables (four per measure)"),
    sp(3),
    p("Each measure below exists as four year-pair columns, labelled "
      "<tt>*_0708</tt>, <tt>*_0809</tt>, <tt>*_0910</tt>, <tt>*_1011</tt>. "
      "These are the raw year-pair ratios before averaging. Statistics in the "
      "table below are pooled across all year pairs and layers.", "body"),
    sp(6),
]
story.append(make_table(
    ["Variable stub", "Min", "Mean", "Max", "Description"],
    [
        ["layer_treat_pw_<i>AB</i>", "0.000", "~0.083–0.120", "2.000",
         "ratio_total for year pair AB: (outflows to treated + inflows from treated) "
         "at this firm–layer cell, divided by E_avg. This is the layer-specific "
         "analogue of totaltreat_pw_n from the firm-level spillover regressions. "
         "Numerator counts all treated contacts regardless of the worker's layer "
         "at the contact firm."],
        ["sametreat_pw_<i>AB</i>", "0.000", "~0.077–0.111", "2.000",
         "ratio_same for year pair AB: M_same / E_avg, where M_same counts "
         "treated contacts where the worker's layer at the contact firm equals "
         "the focal layer. Captures within-layer transmission of the union "
         "treatment: a no_hs worker at a non-treated firm connects to a treated "
         "firm through the no_hs layer."],
        ["crosstreat_pw_<i>AB</i>", "0.000", "~0.0005–0.006", "2.000",
         "ratio_cross for year pair AB: M_cross / E_avg, where M_cross counts "
         "treated contacts where the worker's layer at the contact firm differs "
         "from the focal layer. Captures cross-layer transmission: e.g., a "
         "has_hs layer at a non-treated firm connecting to a treated firm via "
         "a no_hs worker. Very small for gender and large-education splits "
         "because most workers maintain their demographic group across firms."],
        ["totalflows_layer_pw_<i>AB</i>", "0.000", "~0.252–0.301", "2.000",
         "Total worker flows (to/from any firm, not just treated) for this "
         "firm–layer cell in year pair AB, scaled by E_avg. Measures overall "
         "labour market attachment of the layer. Used to construct the "
         "layer_totalflows_pw_pre4 control bins in regressions."],
    ],
    [1.5*inch, 0.45*inch, 1.1*inch, 0.45*inch, W - 3.5*inch],
    wrap_cols=[0, 4],
))
story.append(sp(10))

# 3.4 Averaged variables
story += [subsection("3.3 NaN-Aware Average Variables (main analysis variables)"), sp(2)]
story.append(make_table(
    ["Variable", "Type", "Mean (edu)", "Mean (edu2)", "Mean (gender)", "Mean (race)", "Description"],
    [
        ["layer_treat_pw_n", "DOUBLE", "0.102", "0.083", "0.114", "0.120",
         "NaN-aware average of layer_treat_pw_AB across the available year pairs. "
         "Main treatment variable in 07_layer_spillover.do: scaled to P90 of "
         "the untreated balanced-panel subsample at 2009 to form layer_conn_norm."],
        ["sametreat_pw_n", "DOUBLE", "0.091", "0.077", "0.111", "0.111",
         "NaN-aware average of sametreat_pw_AB. Within-layer connectivity component. "
         "By construction, sametreat_pw_n + crosstreat_pw_n ≤ layer_treat_pw_n "
         "(equality when all treated contacts have an observed contact-firm layer)."],
        ["crosstreat_pw_n", "DOUBLE", "0.009", "0.004", "0.001", "0.006",
         "NaN-aware average of crosstreat_pw_AB. Cross-layer connectivity component. "
         "Typically much smaller than sametreat_pw_n: most workers who move to a "
         "treated firm are in the same demographic group as the focal layer."],
        ["totalflows_layer_pw_n", "DOUBLE", "0.286", "0.252", "0.285", "0.301",
         "NaN-aware average of totalflows_layer_pw_AB. Used to construct the "
         "pre-treatment turnover bins (layer_totalflows_pw_pre4) that are "
         "interacted with year dummies as additional controls in regressions."],
        ["*_count_n", "INTEGER", "3.7", "3.7", "3.8", "3.7",
         "Number of non-missing year pairs that entered the average for each "
         "_n variable. Maximum is 4 (all four year pairs available). "
         "Values below 4 arise when the firm-layer is absent from one "
         "RAIS cross-section. One _count_n variable is stored per _n variable "
         "(e.g., layer_treat_pw_n_count_n)."],
    ],
    [1.4*inch, 0.5*inch, 0.58*inch, 0.58*inch, 0.63*inch, 0.58*inch, W - 4.27*inch],
    wrap_cols=[0, 6],
))
story.append(sp(14))
story += [
    hr(),
    sp(4),
    p("UnionSpill Project — Luis de Azevedo-Gomes &amp; Guilherme Neri  |  Generated 2026",
      "footer"),
]

# ── Build ─────────────────────────────────────────────────────────────────────
doc.build(story)
print(f"Saved: {OUT}")
