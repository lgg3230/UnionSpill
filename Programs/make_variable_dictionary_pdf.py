"""
Generate a PDF variable dictionary for worker_panel_lagos.parquet
using reportlab.

Structure:
  Part 1 – Raw Variables   (direct RAIS fields)
  Part 2 – Derived Variables (constructed from raw fields)
"""

from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUTPUT = "/gpfs/kellogg/proj/lgg3230/UnionSpill/worker_panel_lagos_data_dictionary.pdf"

# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "Title", parent=styles["Title"],
    fontSize=16, spaceAfter=4, leading=20
)
subtitle_style = ParagraphStyle(
    "Subtitle", parent=styles["Normal"],
    fontSize=10, textColor=colors.HexColor("#555555"),
    spaceAfter=12, leading=14
)
# Top-level part heading (Part 1 / Part 2)
part_style = ParagraphStyle(
    "Part", parent=styles["Heading1"],
    fontSize=14, textColor=colors.white,
    backColor=colors.HexColor("#1a3a6b"),
    spaceBefore=18, spaceAfter=8, leading=20,
    leftIndent=-6, rightIndent=-6,
    borderPad=5
)
# Subsection heading within a part
section_style = ParagraphStyle(
    "Section", parent=styles["Heading2"],
    fontSize=11, textColor=colors.HexColor("#1a3a6b"),
    spaceBefore=12, spaceAfter=4, leading=15,
)
note_style = ParagraphStyle(
    "Note", parent=styles["Normal"],
    fontSize=8.5, textColor=colors.HexColor("#333333"),
    leading=13, spaceAfter=6
)
footer_style = ParagraphStyle(
    "Footer", parent=styles["Normal"],
    fontSize=8, textColor=colors.HexColor("#888888"),
    alignment=TA_CENTER
)
cell_style = ParagraphStyle(
    "Cell", parent=styles["Normal"],
    fontSize=8, leading=11
)
header_cell_style = ParagraphStyle(
    "HeaderCell", parent=styles["Normal"],
    fontSize=8.5, leading=11, textColor=colors.white,
    fontName="Helvetica-Bold"
)

# Table colors
HEADER_BG   = colors.HexColor("#1a3a6b")
HEADER_FG   = colors.white
ROW_EVEN_BG = colors.HexColor("#eef2f7")
ROW_ODD_BG  = colors.white
GRID_COLOR  = colors.HexColor("#cccccc")

def make_table(headers, rows, col_widths):
    """Build a styled reportlab Table."""
    header_row = [Paragraph(h, header_cell_style) for h in headers]
    data = [header_row]
    for row in rows:
        data.append([Paragraph(str(c), cell_style) for c in row])

    t = Table(data, colWidths=col_widths, repeatRows=1)
    ts = [
        ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
        ("TEXTCOLOR",  (0, 0), (-1, 0), HEADER_FG),
        ("FONTNAME",   (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",   (0, 0), (-1, 0), 8.5),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 6),
        ("TOPPADDING",    (0, 0), (-1, 0), 6),
        ("GRID", (0, 0), (-1, -1), 0.4, GRID_COLOR),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 1), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 1), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 5),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 5),
    ]
    for i in range(1, len(data)):
        bg = ROW_EVEN_BG if i % 2 == 0 else ROW_ODD_BG
        ts.append(("BACKGROUND", (0, i), (-1, i), bg))
    t.setStyle(TableStyle(ts))
    return t

W = 6.5 * inch   # usable width (letter − 1" margins each side)

story = []

# ---------------------------------------------------------------------------
# Title block
# ---------------------------------------------------------------------------
story.append(Paragraph("Variable Dictionary", title_style))
story.append(Paragraph(
    "<b>File:</b> worker_panel_lagos.parquet &nbsp;&nbsp;|&nbsp;&nbsp; "
    "<b>Path:</b> Data/CBA_RAIS_firm_level/", subtitle_style))
story.append(Paragraph(
    "<b>Observations:</b> 19,598,473 worker-years &nbsp;|&nbsp; "
    "<b>Unique workers (all years):</b> 5,723,160 &nbsp;|&nbsp; "
    "<b>Establishments:</b> 16,472 (balanced) &nbsp;|&nbsp; "
    "<b>Years:</b> 2009–2016",
    subtitle_style))
story.append(Paragraph(
    "All observations have <i>empem3112</i> = 1 (employed on December 31). "
    "This is a stock-of-workers panel. "
    "The 5,723,160 unique workers is a cumulative count across all years — "
    "many workers appear in multiple years.",
    note_style))

# Year-by-year breakdown
story.append(make_table(
    ["Year", "Obs", "Unique workers", "Establishments"],
    [
        ["2009", "2,290,841", "2,284,339", "16,472"],
        ["2010", "2,454,406", "2,448,653", "16,472"],
        ["2011", "2,564,403", "2,558,690", "16,472"],
        ["2012", "2,565,124", "2,558,835", "16,472"],
        ["2013", "2,566,450", "2,560,553", "16,472"],
        ["2014", "2,529,443", "2,523,797", "16,472"],
        ["2015", "2,379,563", "2,374,097", "16,472"],
        ["2016", "2,248,243", "2,243,227", "16,472"],
    ],
    col_widths=[0.7*inch, 1.2*inch, 1.4*inch, 1.4*inch]
))
story.append(Paragraph(
    "Note: obs ≈ unique workers each year. The small gap (~5–6K workers, or ~0.2 %, appear "
    "at more than one establishment in the same year) is consistent with the one-spell-per-worker "
    "selection in 1010_rais_to_firm.do allowing a small number of exceptions. "
    "The establishment count is identical every year — "
    "this is a <b>balanced panel on the firm side</b> (in_balanced_panel restriction).",
    note_style))
story.append(HRFlowable(width=W, thickness=1.5, color=colors.HexColor("#1a3a6b"), spaceAfter=12))

# ===========================================================================
# PART 1 – RAW VARIABLES
# ===========================================================================
story.append(Paragraph("Part 1 — Raw Variables", part_style))
story.append(Paragraph(
    "Variables taken directly from RAIS microdata with no transformation beyond "
    "stripping the leading '1' from 15-digit establishment IDs.",
    note_style))

# ------------------------------------------------------------------
# 1.1 Identifiers
story.append(Paragraph("1.1  Identifiers", section_style))
story.append(make_table(
    ["Variable", "Type", "Description"],
    col_widths=[1.3*inch, 0.75*inch, 4.45*inch],
    rows=[
        ["identificad", "VARCHAR",
         "14-digit establishment identifier (CNPJ-base from RAIS). "
         "Note: some raw RAIS files carry 15-digit IDs with a leading '1' — "
         "that prefix has been stripped."],
        ["PIS", "VARCHAR",
         "Worker identifier (PIS/PASEP social insurance number)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.2 Wages (raw)
story.append(Paragraph("1.2  Wages", section_style))
story.append(Paragraph(
    "remdezembro and remmedia are in <b>minimum wages (salários mínimos)</b>. "
    "remdezr and remmedr are in <b>nominal BRL</b> — the 'r' suffix in RAIS stands for "
    "<i>remuneração</i> (remuneration), not real/deflated. "
    "salcontr and ultrem are also in <b>nominal BRL</b>.",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Min", "Mean", "Max", "Description"],
    col_widths=[1.25*inch, 0.6*inch, 0.55*inch, 0.75*inch, 0.9*inch, 2.45*inch],
    rows=[
        ["remdezembro", "DOUBLE", "0", "4.50 MW",  "150 MW",
         "December earnings in minimum wages."],
        ["remmedia",    "DOUBLE", "0", "4.23 MW",  "150 MW",
         "Average monthly earnings in minimum wages."],
        ["remdezr",     "DOUBLE", "0", "2,902 BRL","132,007",
         "December earnings in nominal BRL (raw RAIS field; 'r' = remuneração, not real/deflated)."],
        ["remmedr",     "DOUBLE", "0", "2,736 BRL","130,875",
         "Average monthly earnings in nominal BRL (same naming convention as remdezr)."],
        ["salcontr",    "DOUBLE", "0", "2,035 BRL","9,999,999",
         "Contracted salary in nominal BRL."],
        ["ultrem",      "DOUBLE", "0", "—",        "4,081,467",
         "Last remuneration received, nominal BRL."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.3 Work Schedule
story.append(Paragraph("1.3  Work Schedule", section_style))
story.append(make_table(
    ["Variable", "Type", "Min", "Mean", "Max", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 0.5*inch, 0.65*inch, 0.5*inch, 2.9*inch],
    rows=[
        ["horascontr", "TINYINT", "1", "41.4", "44",
         "Contracted weekly hours."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.4 Contract Type
story.append(Paragraph("1.4  Contract Type", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.3*inch, 2.35*inch],
    rows=[
        ["tpvinculo", "TINYINT",
         "10=CLT private (93.2 %), 20=rural/CLT rural (3.0 %), "
         "55=apprentice/Lei 10.097 (1.5 %), 60=fixed-term/Lei 9.601 (1.5 %), "
         "70=rural other (0.3 %), 90=fixed-term other (0.2 %), "
         "30/31/35=public statutory (0.1 %), 40/80/15/25=other (0.04 %)",
         "Employment bond type (vínculo empregatício)."],
        ["tipoadm", "TINYINT",
         "0=not admitted this year/transfer (77.2 %), "
         "2=first job/new hire (17.0 %), 1=rehire (3.8 %), "
         "4=transfer (1.9 %)",
         "Admission type for workers hired during the year."],
        ["tiposal", "TINYINT",
         "1=monthly (77.1 %), 5=hourly (21.0 %), 6=daily (0.9 %), "
         "4=task-based (0.4 %), 7=commission (0.4 %)",
         "Salary payment type (tipo de salário)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.5 Dates
story.append(Paragraph("1.5  Date Fields", section_style))
story.append(make_table(
    ["Variable", "Type", "Format", "Example", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 0.9*inch, 0.85*inch, 2.9*inch],
    rows=[
        ["dtadmissao",   "VARCHAR", "DDMMYYYY", "01052006",
         "Date of admission to current establishment."],
        ["dtnascimento", "VARCHAR", "DDMMYYYY", "31081966",
         "Worker date of birth."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.6 Demographics
story.append(Paragraph("1.6  Worker Demographics", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.5*inch, 2.15*inch],
    rows=[
        ["genero",      "TINYINT",
         "1=male (68.1 %), 0=female (31.9 %)",
         "Gender (raw RAIS field)."],
        ["raca_cor",    "TINYINT",
         "2=branca/white (58.4 %), 8=parda/mixed (31.3 %), "
         "4=preta/black (5.4 %), 9=indígena (3.8 %), "
         "6=amarela/Asian (0.9 %), 99=undeclared, −1=missing",
         "Race/color (cor ou raça)."],
        ["nacionalidad","TINYINT",
         "10=Brazilian (99.7 %), 40/45/20/21/80=foreign",
         "Nationality code."],
        ["idade",       "DOUBLE",
         "0–100, mean 35.9",
         "Age as reported in RAIS record."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.7 Education
story.append(Paragraph("1.7  Education", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 3.1*inch, 1.55*inch],
    rows=[
        ["grinstrucao", "TINYINT",
         "7=complete secondary (43.9 %), 9=complete higher (18.5 %), "
         "5=complete primary (9.1 %), 4=incomplete secondary (7.7 %), "
         "6=incomplete higher (7.5 %), 8=incomplete post-grad (4.5 %), "
         "3=incomplete primary (4.0 %), 2=illiterate/no schooling (3.6 %)",
         "Education level — raw RAIS grau de instrução code."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.8 Disability
story.append(Paragraph("1.8  Disability", section_style))
story.append(Paragraph(
    "<b>Note:</b> portdefic flags ~25 % of workers (likely includes administrative filings "
    "and partial records). Use d_disabled (Part 2) for analysis.",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.5*inch, 2.15*inch],
    rows=[
        ["portdefic", "TINYINT",
         "0=no (74.5 %), 1=yes (25.5 %)",
         "Raw RAIS disability carrier field (porte de deficiência). "
         "High share may reflect administrative coding."],
        ["tpdefic",   "TINYINT",
         "0=none (97.8 %), 1=physical (1.1 %), 2=hearing (0.6 %), "
         "6=intellectual (0.2 %), 3=visual (0.2 %), "
         "4=rehabilitated (0.1 %), 5=multiple (0.03 %)",
         "Disability type (tipo de deficiência)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.9 Occupation
story.append(Paragraph("1.9  Occupation", section_style))
story.append(make_table(
    ["Variable", "Type", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 4.65*inch],
    rows=[
        ["ocup2002", "INTEGER",
         "CBO 2002 occupation code at the 6-digit level "
         "(e.g., 784205=farm workers, 411005=general office clerks, 622110=crop farmers)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.10 Establishment Characteristics
story.append(Paragraph("1.10  Establishment Characteristics", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.5*inch, 2.15*inch],
    rows=[
        ["clascnae20",  "VARCHAR",
         "5-digit CNAE 2.0 code (e.g., 10716=poultry processing, "
         "86101=hospitals, 29107=auto manufacturing)",
         "Economic activity classification (CNAE 2.0)."],
        ["municipio",   "INTEGER",
         "IBGE 6-digit code; 2,096 distinct municipalities",
         "Municipality of the establishment."],
        ["tamestab",    "TINYINT",
         "1=1–4 emp, 2=5–9, 3=10–19, 4=20–49, 5=50–99, "
         "6=100–249, 7=250–499, 8=500–999, 9=1000+",
         "Establishment size category."],
        ["natjuridica", "SMALLINT",
         "2062=Ltda (41.0 %), 2054=S.A. fechada (24.0 %), "
         "2046=EIRELI (12.1 %), 3999=other private (6.6 %), "
         "2011=S.A. aberta (4.5 %)",
         "Legal nature of the establishment (natureza jurídica)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.11 Employment Status & Separation
story.append(Paragraph("1.11  Employment Status & Separation", section_style))
story.append(Paragraph(
    "Near-universal causadesli = 0 is consistent with the empem3112 = 1 selection. "
    "The small number of non-zero values likely reflects administrative corrections "
    "or mid-year separations with same-year rehire.",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.2*inch, 2.45*inch],
    rows=[
        ["empem3112",  "TINYINT",
         "1 for all obs",
         "Employed on December 31 — the selection criterion defining the panel."],
        ["causadesli", "TINYINT",
         "0=still employed (99.6 %), 71=death (0.4 %), "
         "80=retirement (0.02 %), 78=transfer (0.02 %)",
         "Cause of separation (causa do desligamento)."],
        ["mesdesli",   "TINYINT", "All 0",
         "Month of separation (all zero — consistent with Dec 31 employment)."],
        ["diadesli",   "DOUBLE",  "All 0",
         "Day of separation (all zero)."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 1.12 Leave
story.append(Paragraph("1.12  Leave / Absence Records", section_style))
story.append(Paragraph(
    "RAIS tracks up to three leave spells per worker-year. "
    "−1 = not applicable to this spell index; "
    "99 in causafast = employed but no leave during the year.",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Description"],
    col_widths=[1.25*inch, 0.65*inch, 2.3*inch, 2.3*inch],
    rows=[
        ["causafast1", "TINYINT",
         "99=no leave (67.2 %), −1=N/A (21.2 %), 40=illness (8.9 %), "
         "50=work accident (1.1 %), 10=maternity (0.7 %), 70=other (0.6 %)",
         "Cause of first leave spell."],
        ["causafast2", "TINYINT", "Same codes", "Cause of second leave spell."],
        ["causafast3", "TINYINT", "Same codes", "Cause of third leave spell."],
        ["mesiniaf1",  "TINYINT", "−1=N/A, 1–12=month", "Start month of first leave spell."],
        ["mesiniaf2",  "TINYINT", "−1=N/A, 1–12=month", "Start month of second leave spell."],
        ["mesiniaf3",  "TINYINT", "−1=N/A, 1–12=month", "Start month of third leave spell."],
        ["mesfimaf1",  "TINYINT", "−1=N/A, 1–12=month", "End month of first leave spell."],
        ["mesfimaf2",  "TINYINT", "−1=N/A, 1–12=month", "End month of second leave spell."],
        ["mesfimaf3",  "TINYINT", "−1=N/A, 1–12=month", "End month of third leave spell."],
    ]
))

# ===========================================================================
# PART 2 – DERIVED VARIABLES
# ===========================================================================
story.append(PageBreak())
story.append(Paragraph("Part 2 — Derived Variables", part_style))
story.append(Paragraph(
    "Variables constructed from raw RAIS fields during data cleaning "
    "(1010_rais_to_firm.do / 011c_worker_panel.py).",
    note_style))

# ------------------------------------------------------------------
# 2.1 Panel identifier
story.append(Paragraph("2.1  Panel Identifier", section_style))
story.append(make_table(
    ["Variable", "Type", "Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 1.0*inch, 3.65*inch],
    rows=[
        ["year", "BIGINT", "2009–2016",
         "Calendar year of the observation. Added when stacking annual RAIS cross-sections "
         "into the panel."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.2 Wages — deflated and log
story.append(Paragraph("2.2  Wages — Deflated & Log", section_style))
story.append(Paragraph(
    "remdezr and remmedr (raw RAIS, nominal BRL) are deflated to December 2015 BRL "
    "by dividing by the year-specific IPCA index (normalised to 1 in December 2015): "
    "lr_remdezr = log(remdezr / IPCA_t). "
    "salcontr_m adjusts salcontr to a monthly basis using contracted hours, "
    "then is similarly deflated. Log versions are missing when the level is zero.",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Min", "Mean", "Max", "Nulls", "Description"],
    col_widths=[1.2*inch, 0.55*inch, 0.6*inch, 0.75*inch, 0.85*inch, 0.65*inch, 1.85*inch],
    rows=[
        ["salcontr_m",    "DOUBLE", "0",    "—",    "75,968,082","—",
         "Monthly contracted salary in nominal BRL (hours-adjusted from salcontr)."],
        ["lr_remdezr",    "DOUBLE", "5.37", "7.79", "11.73",  "797,129",
         "log(remdezr / IPCA_t) — log December earnings in Dec 2015 BRL."],
        ["lr_remmedr",    "DOUBLE", "5.26", "7.72", "11.72",  "417,774",
         "log(remmedr / IPCA_t) — log average monthly earnings in Dec 2015 BRL."],
        ["lr_salcontr_m", "DOUBLE", "−4.61","7.68", "18.49",  "7,043,827",
         "log(salcontr_m / IPCA_t) — log monthly contracted salary in Dec 2015 BRL. "
         "High nulls because salcontr is often zero."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.3 Work schedule dummy
story.append(Paragraph("2.3  Work Schedule", section_style))
story.append(make_table(
    ["Variable", "Type", "Values", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 1.0*inch, 3.65*inch],
    rows=[
        ["hours_ge40", "TINYINT", "0/1 (84.9 % = 1)",
         "1 if contracted hours ≥ 40/week. Derived from horascontr."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.4 Contract type dummies
story.append(Paragraph("2.4  Contract Type Dummies", section_style))
story.append(Paragraph(
    "Binary indicators derived from tpvinculo. Reference category is CLT private (tpvinculo = 10).",
    note_style))
story.append(make_table(
    ["Variable", "Type", "Share = 1", "Source values (tpvinculo)", "Description"],
    col_widths=[1.3*inch, 0.6*inch, 0.75*inch, 1.5*inch, 2.35*inch],
    rows=[
        ["d_apprentice",     "TINYINT", "1.5 %", "55",
         "Apprentice contract (Lei 10.097)."],
        ["d_fixed_term",     "TINYINT", "1.8 %", "60, 90, 50, 95, 96, 97",
         "Fixed-term contract (contrato por prazo determinado)."],
        ["d_rural",          "TINYINT", "3.4 %", "20, 70",
         "Rural sector employment (Lei 5889/73)."],
        ["d_public",         "TINYINT", "0.1 %", "30, 31, 35",
         "Public sector statutory contract."],
        ["d_other_contract", "TINYINT", "0.05 %","40, 80, 15, 25",
         "Residual/other contract type."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.5 Tenure
story.append(Paragraph("2.5  Tenure", section_style))
story.append(make_table(
    ["Variable", "Type", "Range / Categories", "Source", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 1.7*inch, 1.0*inch, 1.95*inch],
    rows=[
        ["tempempr",   "DOUBLE",
         "1.1–599.9 months (mean 71.8)",
         "dtadmissao",
         "Tenure at the establishment in months."],
        ["tenure_bin", "VARCHAR",
         "lt1yr, 1_2yr, 3_5yr, 5_10yr, 10_20yr, 20plus",
         "tempempr",
         "Tenure binned into duration bands."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.6 Demographics
story.append(Paragraph("2.6  Worker Demographics", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Source", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.1*inch, 1.1*inch, 1.45*inch],
    rows=[
        ["d_male",    "TINYINT",
         "0/1 (68.1 % = 1)",
         "genero",
         "Binary gender indicator."],
        ["race_group","VARCHAR",
         "branca (58.4 %), parda (31.3 %), preta (5.4 %), other_missing (5.0 %)",
         "raca_cor",
         "Race recoded; amarela, indígena, undeclared → 'other_missing'."],
        ["age",       "DOUBLE",
         "0–109, mean 35.7",
         "dtnascimento",
         "Age computed from birth date and reference date."],
        ["age_bin",   "VARCHAR",
         "14_24 (16.3 %), 25_34 (35.2 %), 35_44 (25.8 %), "
         "45_54 (16.7 %), 55plus (5.9 %), missing (0.01 %)",
         "age / idade",
         "Age binned into five groups."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.7 Education
story.append(Paragraph("2.7  Education", section_style))
story.append(make_table(
    ["Variable", "Type", "Key Values", "Source", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 2.1*inch, 1.1*inch, 1.45*inch],
    rows=[
        ["educ_bin", "VARCHAR",
         "0_no_hs=less than HS (32.2 %), 1_hs=HS complete (48.4 %), "
         "2_higher=higher education (19.4 %)",
         "grinstrucao",
         "Education recoded into three bins."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.8 Disability
story.append(Paragraph("2.8  Disability", section_style))
story.append(make_table(
    ["Variable", "Type", "Values", "Source", "Description"],
    col_widths=[1.2*inch, 0.65*inch, 1.2*inch, 0.9*inch, 2.55*inch],
    rows=[
        ["d_disabled", "TINYINT",
         "0/1 (2.2 % = 1, 435K workers)",
         "tpdefic",
         "Clean binary: 1 if tpdefic ≠ 0. Preferred over portdefic for analysis."],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# 2.9 Occupation
story.append(Paragraph("2.9  Occupation", section_style))
story.append(make_table(
    ["Variable", "Type", "Description", "Source"],
    col_widths=[1.2*inch, 0.65*inch, 3.35*inch, 1.3*inch],
    rows=[
        ["ocup4", "INTEGER",
         "CBO 2002 occupation at the 4-digit family level (first four digits of ocup2002).",
         "ocup2002"],
    ]
))
story.append(Spacer(1, 6))

# ------------------------------------------------------------------
# Construction notes
story.append(HRFlowable(width=W, thickness=1, color=colors.HexColor("#1a3a6b"), spaceBefore=12, spaceAfter=8))
story.append(Paragraph("Notes on Construction", section_style))
notes = [
    "<b>Sample:</b> Lagos (2021) sample — establishments in the lagos_sample selection, "
    "restricted to workers employed on December 31 (empem3112 = 1).",
    "<b>Wage deflation:</b> lr_remdezr and lr_remmedr use Brazil's IPCA index, "
    "base = December 2015. The raw level variables remdezr and remmedr are in nominal BRL.",
    "<b>portdefic vs d_disabled:</b> portdefic has ~25 % flagged (likely includes administrative "
    "disability filings); d_disabled = (tpdefic ≠ 0) gives the standard 2.2 % rate.",
    "<b>Leave coding:</b> −1 in mesiniaf*/mesfimaf* means no leave spell of that index. "
    "99 in causafast* means the worker was employed but had no leave.",
    "<b>One spell per worker per year:</b> n_obs ≈ n_unique_workers in every year. "
    "A small residual of ~5–6K workers per year (~0.2 %) appear at more than one establishment "
    "in the same year. This is consistent with the one-spell-per-worker selection algorithm "
    "in 1010_rais_to_firm.do (ranked by hours, then hourly wage, then random tiebreaker "
    "with seed 12345), which selects one spell per worker-firm pair but does not enforce "
    "uniqueness across firms.",
    "<b>Balanced firm panel:</b> the establishment count is exactly 16,472 in every year (2009–2016), "
    "reflecting the in_balanced_panel restriction.",
]
for n in notes:
    story.append(Paragraph("• " + n, note_style))

story.append(Spacer(1, 20))
story.append(HRFlowable(width=W, thickness=0.5, color=colors.HexColor("#aaaaaa")))
story.append(Spacer(1, 4))
story.append(Paragraph(
    "UnionSpill Project — Luis de Azevedo-Gomes & Guilherme Neri &nbsp;|&nbsp; Generated 2026",
    footer_style))

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=LETTER,
    leftMargin=inch,
    rightMargin=inch,
    topMargin=0.85*inch,
    bottomMargin=0.85*inch,
    title="Variable Dictionary — worker_panel_lagos.parquet",
    author="UnionSpill Project",
)
doc.build(story)
print(f"PDF written to {OUTPUT}")
