#!/usr/bin/env python3
"""
Generate self-contained HTML detail reports from clo-author markdown reports.

Subcommands:
    peer-review   Combine domain + methods referee + editorial decision
    code-audit    Interactive code audit report
    strategy      Strategy review with phase accordion
    quality-gate  Quality gate dashboard
    literature    Filterable annotated bibliography

Usage:
    python3 scripts/generate_html_report.py peer-review \
        quality_reports/reviews/YYYY-MM-DD_referee_domain.md \
        quality_reports/reviews/YYYY-MM-DD_referee_methods.md \
        quality_reports/reviews/YYYY-MM-DD_editorial_decision.md \
        [--output quality_reports/reviews/YYYY-MM-DD_peer_review.html]
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from html import escape
from pathlib import Path
from textwrap import dedent


def find_base_dir():
    return Path(__file__).resolve().parent.parent / "templates" / "html" / "base"


def load_base_assets():
    base = find_base_dir()
    css = (base / "styles.css").read_text() if (base / "styles.css").exists() else ""
    js = (base / "components.js").read_text() if (base / "components.js").exists() else ""
    return css, js


# ---------- Markdown Helpers ----------

def md_to_html(text):
    """Minimal markdown to HTML: bold, italic, code, links, paragraphs."""
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    paragraphs = text.strip().split("\n\n")
    return "".join(f"<p>{p.strip()}</p>" for p in paragraphs if p.strip())


def extract_field(text, field):
    m = re.search(rf'\*\*{re.escape(field)}:\*\*\s*(.+)', text)
    return m.group(1).strip() if m else ""


def extract_section(text, heading):
    pattern = rf'^##\s+{re.escape(heading)}\s*\n(.*?)(?=\n##\s|\Z)'
    m = re.search(pattern, text, re.MULTILINE | re.DOTALL)
    return m.group(1).strip() if m else ""


def extract_table_rows(text):
    rows = []
    for line in text.split("\n"):
        if "|" in line and "---" not in line:
            cols = [c.strip() for c in line.split("|") if c.strip()]
            if cols and not cols[0].lower().startswith("dimension") and not cols[0].lower().startswith("---"):
                rows.append(cols)
    return rows


def parse_major_comments(text):
    comments = []
    parts = re.split(r'\n(\d+)\.\s+\*\*', text)
    if len(parts) < 2:
        parts = re.split(r'\n(\d+)\.\s+', text)

    i = 1
    while i < len(parts) - 1:
        num = parts[i]
        body = parts[i + 1] if i + 1 < len(parts) else ""
        title_match = re.match(r'(.+?)\*\*\s*\n?(.*)', body, re.DOTALL)
        if title_match:
            title = title_match.group(1).strip()
            rest = title_match.group(2).strip()
        else:
            lines = body.strip().split("\n", 1)
            title = lines[0].strip().rstrip("*").strip()
            rest = lines[1].strip() if len(lines) > 1 else ""

        cwcm_match = re.search(
            r'\*\*What would change my mind:\*\*\s*(.*?)(?=\n\d+\.\s|\Z)',
            rest, re.DOTALL
        )
        if not cwcm_match:
            cwcm_match = re.search(
                r'- \*\*What would change my mind:\*\*\s*(.*?)(?=\n\d+\.\s|\Z)',
                rest, re.DOTALL
            )

        main_text = rest
        cwcm_text = ""
        if cwcm_match:
            cwcm_text = cwcm_match.group(1).strip()
            main_text = rest[:cwcm_match.start()].strip()

        comments.append({
            "num": num,
            "title": title,
            "text": main_text,
            "cwcm": cwcm_text,
        })
        i += 2

    return comments


def parse_numbered_list(text):
    items = []
    for m in re.finditer(r'(\d+)\.\s+(.+?)(?=\n\d+\.|\Z)', text, re.DOTALL):
        items.append(m.group(2).strip())
    if not items:
        for line in text.strip().split("\n"):
            line = line.strip().lstrip("-").lstrip("*").strip()
            if line:
                items.append(line)
    return items


def parse_bullet_list(text):
    items = []
    for line in text.strip().split("\n"):
        line = line.strip()
        if line.startswith("- ") or line.startswith("* "):
            items.append(line[2:].strip())
        elif line:
            items.append(line)
    return items


# ---------- Peer Review Parser ----------

def parse_methods_referee(text):
    data = {
        "date": extract_field(text, "Date"),
        "paper": extract_field(text, "Paper"),
        "paper_type": extract_field(text, "Paper type"),
        "design": extract_field(text, "Design"),
        "recommendation": extract_field(text, "Recommendation"),
        "score": 0,
        "summary": "",
        "dimensions": [],
        "sanity_checks": [],
        "major_comments": [],
        "minor_comments": [],
        "technical_suggestions": [],
        "questions": [],
    }

    score_str = extract_field(text, "Overall Score")
    m = re.match(r'(\d+)', score_str)
    if m:
        data["score"] = int(m.group(1))

    data["summary"] = extract_section(text, "Summary")

    dim_section = extract_section(text, "Dimension Scores")
    for row in extract_table_rows(dim_section):
        if len(row) >= 4 and row[0] != "**Weighted**" and "Weighted" not in row[0]:
            try:
                data["dimensions"].append({
                    "name": row[0].strip("*").strip(),
                    "weight": row[1].strip().rstrip("%"),
                    "score": int(re.search(r'\d+', row[2]).group()),
                    "notes": row[3] if len(row) > 3 else "",
                })
            except (ValueError, AttributeError):
                pass

    sanity_section = extract_section(text, "Sanity Check Results")
    for line in sanity_section.split("\n"):
        m = re.match(r'- \*\*(\w+):\*\*\s*(\w+)\.?\s*(.*)', line)
        if m:
            data["sanity_checks"].append({
                "name": m.group(1),
                "status": m.group(2),
                "detail": m.group(3).strip(),
            })

    major_section = extract_section(text, "Major Comments")
    data["major_comments"] = parse_major_comments(major_section)

    minor_section = extract_section(text, "Minor Comments")
    data["minor_comments"] = parse_numbered_list(minor_section)

    tech_section = extract_section(text, "Technical Suggestions")
    data["technical_suggestions"] = parse_bullet_list(tech_section)

    q_section = extract_section(text, "Questions for the Authors")
    data["questions"] = parse_numbered_list(q_section)

    return data


def parse_domain_referee(text):
    data = {
        "date": extract_field(text, "Date"),
        "paper": extract_field(text, "Paper"),
        "field": extract_field(text, "Field"),
        "calibrated_to": extract_field(text, "Calibrated to"),
        "recommendation": extract_field(text, "Recommendation"),
        "score": 0,
        "summary": "",
        "dimensions": [],
        "major_comments": [],
        "minor_comments": [],
        "missing_literature": [],
        "questions": [],
    }

    score_str = extract_field(text, "Overall Score")
    m = re.match(r'(\d+)', score_str)
    if m:
        data["score"] = int(m.group(1))

    data["summary"] = extract_section(text, "Summary")

    dim_section = extract_section(text, "Dimension Scores")
    for row in extract_table_rows(dim_section):
        if len(row) >= 4 and "Weighted" not in row[0]:
            try:
                data["dimensions"].append({
                    "name": row[0].strip("*").strip(),
                    "weight": row[1].strip().rstrip("%"),
                    "score": int(re.search(r'\d+', row[2]).group()),
                    "notes": row[3] if len(row) > 3 else "",
                })
            except (ValueError, AttributeError):
                pass

    major_section = extract_section(text, "Major Comments")
    data["major_comments"] = parse_major_comments(major_section)

    minor_section = extract_section(text, "Minor Comments")
    data["minor_comments"] = parse_numbered_list(minor_section)

    lit_section = extract_section(text, "Missing Literature")
    data["missing_literature"] = parse_bullet_list(lit_section)

    q_section = extract_section(text, "Questions for the Authors")
    data["questions"] = parse_numbered_list(q_section)

    return data


def parse_editorial_decision(text):
    data = {
        "date": extract_field(text, "Date"),
        "journal": extract_field(text, "Journal"),
        "paper": extract_field(text, "Paper"),
        "decision": extract_field(text, "Decision"),
        "assessment": "",
        "referee_summary": "",
        "must_address": [],
        "should_address": [],
        "may_push_back": [],
        "disagreements": "",
        "timeline": "",
    }

    data["assessment"] = extract_section(text, "Editor's Assessment")
    data["referee_summary"] = extract_section(text, "Referee Summary")

    concerns = extract_section(text, "Concerns Classification")
    must_section = re.search(r'###\s*MUST Address\s*\n(.*?)(?=\n###|\Z)', concerns, re.DOTALL)
    should_section = re.search(r'###\s*SHOULD Address\s*\n(.*?)(?=\n###|\Z)', concerns, re.DOTALL)
    may_section = re.search(r'###\s*MAY Push Back\s*\n(.*?)(?=\n###|\Z)', concerns, re.DOTALL)

    if must_section:
        data["must_address"] = parse_numbered_list(must_section.group(1))
    if should_section:
        data["should_address"] = parse_numbered_list(should_section.group(1))
    if may_section:
        data["may_push_back"] = parse_numbered_list(may_section.group(1))

    data["disagreements"] = extract_section(text, "Where Referees Disagree")
    data["timeline"] = extract_section(text, "Revision Timeline")

    return data


# ---------- Peer Review HTML Builder ----------

def score_color(score):
    if score >= 90: return "var(--accept)"
    if score >= 80: return "var(--minor-rev)"
    if score >= 65: return "var(--major-rev)"
    return "var(--reject)"


def score_pill_class(score):
    if score >= 90: return "pill-accept"
    if score >= 80: return "pill-minor"
    if score >= 65: return "pill-major"
    return "pill-reject"


def decision_pill_class(decision):
    d = decision.lower()
    if "accept" in d and "major" not in d and "minor" not in d: return "pill-accept"
    if "minor" in d: return "pill-minor"
    if "major" in d: return "pill-major"
    if "reject" in d: return "pill-reject"
    return "pill-neutral"


def sanity_pill_class(status):
    s = status.lower()
    if s in ("pass", "ok"): return "pill-pass"
    if s in ("fail", "fragile"): return "pill-fail"
    return "pill-warn"


def build_dimension_bars(dimensions):
    html = ""
    for d in dimensions:
        color = score_color(d["score"])
        pct = d["score"]
        html += f"""
      <div style="margin-bottom:14px">
        <div class="flex-between" style="margin-bottom:4px">
          <div>
            <span style="font-size:13.5px;color:var(--slate);font-weight:500">{escape(d['name'])}</span>
            <span style="font-family:var(--mono);font-size:11px;color:var(--g500)">{d['weight']}%</span>
          </div>
          <span style="font-family:var(--mono);font-size:13px;font-weight:600;color:var(--slate)">{d['score']}</span>
        </div>
        <div class="score-bar-track">
          <div class="score-bar-fill" style="width:{pct}%;background:{color}"></div>
        </div>
        <div style="font-size:12px;color:var(--g500);margin-top:3px">{escape(d.get('notes', ''))}</div>
      </div>"""
    return html


def build_major_comments_html(comments):
    html = ""
    for c in comments:
        html += f"""
      <div class="card card-bordered-left" style="margin-bottom:12px">
        <div class="collapsible-header open">
          <span style="font-family:var(--mono);font-size:11px;color:var(--clay);margin-right:4px">{c['num']}.</span>
          {escape(c['title'])}
        </div>
        <div class="collapsible-body open">
          <div style="font-size:13.5px;color:var(--g700);line-height:1.6">{md_to_html(c['text'])}</div>
          {f'''<div style="margin-top:12px;padding:12px 16px;background:var(--g100);border-radius:8px;border-left:3px solid var(--olive)">
            <div style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--olive);margin-bottom:6px">What would change my mind</div>
            <div style="font-size:13px;color:var(--g700);line-height:1.55">{md_to_html(c["cwcm"])}</div>
          </div>''' if c.get('cwcm') else ''}
        </div>
      </div>"""
    return html


def build_simple_list(items, ordered=True):
    if not items:
        return '<p style="color:var(--g500);font-size:13px;font-style:italic">None listed.</p>'
    tag = "ol" if ordered else "ul"
    li = "".join(f"<li style='margin-bottom:8px;font-size:13.5px;color:var(--g700);line-height:1.55'>{md_to_html(item)}</li>" for item in items)
    return f"<{tag} style='padding-left:20px;margin:8px 0'>{li}</{tag}>"


def build_sanity_checks_html(checks):
    if not checks:
        return ""
    html = '<div class="grid-2" style="margin:12px 0 20px">'
    for ch in checks:
        pcls = sanity_pill_class(ch["status"])
        html += f"""
      <div class="card" style="margin-bottom:0;padding:14px 16px">
        <div class="flex-between" style="margin-bottom:6px">
          <span style="font-weight:600;font-size:14px;color:var(--slate)">{escape(ch['name'])}</span>
          <span class="pill {pcls}">{escape(ch['status'])}</span>
        </div>
        <div style="font-size:12.5px;color:var(--g700);line-height:1.5">{escape(ch['detail'][:200])}</div>
      </div>"""
    html += "</div>"
    return html


def build_editorial_tab(ed):
    dcls = decision_pill_class(ed["decision"])

    assessment_html = md_to_html(ed["assessment"]) if ed["assessment"] else ""
    ref_summary_html = md_to_html(ed["referee_summary"]) if ed["referee_summary"] else ""

    must_html = ""
    if ed["must_address"]:
        must_items = "".join(
            f"<li style='margin-bottom:10px;font-size:13.5px;line-height:1.55;color:var(--g700)'>{md_to_html(item)}</li>"
            for item in ed["must_address"]
        )
        must_html = f"""
      <div class="card card-red" style="margin-bottom:14px">
        <div class="collapsible-header open" style="color:var(--reject)">MUST Address ({len(ed['must_address'])})</div>
        <div class="collapsible-body open">
          <ol style="padding-left:20px;margin:4px 0">{must_items}</ol>
        </div>
      </div>"""

    should_html = ""
    if ed["should_address"]:
        should_items = "".join(
            f"<li style='margin-bottom:10px;font-size:13.5px;line-height:1.55;color:var(--g700)'>{md_to_html(item)}</li>"
            for item in ed["should_address"]
        )
        should_html = f"""
      <div class="card card-amber" style="margin-bottom:14px">
        <div class="collapsible-header">SHOULD Address ({len(ed['should_address'])})</div>
        <div class="collapsible-body">
          <ol style="padding-left:20px;margin:4px 0">{should_items}</ol>
        </div>
      </div>"""

    may_html = ""
    if ed["may_push_back"]:
        may_items = "".join(
            f"<li style='margin-bottom:10px;font-size:13.5px;line-height:1.55;color:var(--g700)'>{md_to_html(item)}</li>"
            for item in ed["may_push_back"]
        )
        may_html = f"""
      <div class="card" style="margin-bottom:14px;border-left:3px solid var(--g300)">
        <div class="collapsible-header">MAY Push Back ({len(ed['may_push_back'])})</div>
        <div class="collapsible-body">
          <ol style="padding-left:20px;margin:4px 0">{may_items}</ol>
        </div>
      </div>"""

    disagree_html = ""
    if ed["disagreements"]:
        disagree_html = f"""
      <h3 style="margin-top:28px">Where Referees Disagree</h3>
      <div style="font-size:14px;color:var(--g700);line-height:1.6">{md_to_html(ed['disagreements'])}</div>"""

    timeline_html = ""
    if ed["timeline"]:
        timeline_html = f"""
      <h3 style="margin-top:28px">Revision Timeline</h3>
      <div style="font-size:14px;color:var(--g700);line-height:1.6">{md_to_html(ed['timeline'])}</div>"""

    return f"""
    <div id="editorial" class="tab-content active">
      <div style="padding:20px 24px;border-radius:var(--radius);margin-bottom:24px;text-align:center;
        {'background:#fce4e4;border:1.5px solid #f5b0b0' if 'reject' in ed['decision'].lower() else
         'background:#fdecd7;border:1.5px solid var(--oat)' if 'major' in ed['decision'].lower() else
         'background:#fef8e1;border:1.5px solid #f5e6a3' if 'minor' in ed['decision'].lower() else
         'background:#e8f5e9;border:1.5px solid #c3e6cb'}">
        <div style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.1em;color:var(--g500);margin-bottom:4px">Decision</div>
        <div style="font-family:var(--serif);font-size:24px;font-weight:500;color:var(--slate)">{escape(ed['decision'])}</div>
        <div style="font-size:13px;color:var(--g500);margin-top:4px">{escape(ed['journal'])}</div>
      </div>

      <h3>Editor's Assessment</h3>
      <div style="font-size:14.5px;color:var(--g700);line-height:1.65;margin-bottom:28px">{assessment_html}</div>

      {"<h3>Referee Summary</h3><div style='font-size:14px;color:var(--g700);line-height:1.6;margin-bottom:28px'>" + ref_summary_html + "</div>" if ref_summary_html else ""}

      <h3>Concerns Classification</h3>
      {must_html}
      {should_html}
      {may_html}

      {disagree_html}
      {timeline_html}
    </div>"""


def build_referee_tab(data, tab_id, is_methods=False):
    scls = score_pill_class(data["score"])
    color = score_color(data["score"])
    rec = data["recommendation"]
    rcls = decision_pill_class(rec)

    badges = f'<span class="pill {rcls}">{escape(rec)}</span>'
    if is_methods:
        if data.get("paper_type"):
            badges += f' <span class="pill pill-neutral">{escape(data["paper_type"])}</span>'
        if data.get("design"):
            badges += f' <span class="pill pill-neutral">{escape(data["design"])}</span>'

    dims_html = build_dimension_bars(data.get("dimensions", []))

    sanity_html = ""
    if is_methods and data.get("sanity_checks"):
        sanity_html = f"<h3>Sanity Checks</h3>{build_sanity_checks_html(data['sanity_checks'])}"

    major_html = ""
    if data.get("major_comments"):
        major_html = f"<h3>Major Comments ({len(data['major_comments'])})</h3>{build_major_comments_html(data['major_comments'])}"

    minor_html = ""
    if data.get("minor_comments"):
        minor_html = f"<h3>Minor Comments ({len(data['minor_comments'])})</h3>{build_simple_list(data['minor_comments'])}"

    extra_sections = ""
    if is_methods and data.get("technical_suggestions"):
        extra_sections += f"<h3>Technical Suggestions</h3>{build_simple_list(data['technical_suggestions'], ordered=False)}"
    if not is_methods and data.get("missing_literature"):
        extra_sections += f"<h3>Missing Literature</h3>{build_simple_list(data['missing_literature'], ordered=False)}"
    if data.get("questions"):
        extra_sections += f"<h3>Questions for the Authors</h3>{build_simple_list(data['questions'])}"

    return f"""
    <div id="{tab_id}" class="tab-content">
      <div class="flex-between" style="margin-bottom:20px">
        <div>{badges}</div>
        <div style="text-align:right">
          <span style="font-family:var(--mono);font-size:32px;font-weight:700;color:{color}">{data['score']}</span>
          <span style="font-family:var(--mono);font-size:13px;color:var(--g500)">/100</span>
        </div>
      </div>

      <div style="font-size:14.5px;color:var(--g700);line-height:1.65;margin-bottom:28px">{md_to_html(data.get('summary', ''))}</div>

      <h3>Dimension Scores</h3>
      <div style="margin-bottom:8px">{dims_html}</div>

      {sanity_html}
      {major_html}
      {minor_html}
      {extra_sections}
    </div>"""


def build_peer_review_html(domain, methods, editorial):
    css, js = load_base_assets()

    paper_title = editorial.get("paper") or methods.get("paper") or (domain.get("paper") if domain else "")
    date = editorial.get("date") or methods.get("date") or ""
    journal = editorial.get("journal", "")
    decision = editorial.get("decision", "")

    has_domain = domain is not None
    has_methods = methods is not None

    avg_score = None
    scores = []
    if has_domain and domain.get("score"):
        scores.append(domain["score"])
    if has_methods and methods.get("score"):
        scores.append(methods["score"])
    if scores:
        avg_score = sum(scores) / len(scores)

    tabs = ['<button class="tab active" data-target="editorial">Editorial Decision</button>']
    if has_domain:
        tabs.append('<button class="tab" data-target="domain">Domain Referee</button>')
    if has_methods:
        tabs.append('<button class="tab" data-target="methods">Methods Referee</button>')

    tab_bar = f'<nav class="tab-bar">{"".join(tabs)}</nav>'

    editorial_tab = build_editorial_tab(editorial)
    domain_tab = build_referee_tab(domain, "domain", is_methods=False) if has_domain else ""
    methods_tab = build_referee_tab(methods, "methods", is_methods=True) if has_methods else ""

    dcls = decision_pill_class(decision)

    score_summary = ""
    if scores:
        parts = []
        if has_domain:
            dc = score_color(domain["score"])
            parts.append(f'<span style="font-family:var(--mono);font-size:13px">Domain <strong style="color:{dc}">{domain["score"]}</strong></span>')
        if has_methods:
            mc = score_color(methods["score"])
            parts.append(f'<span style="font-family:var(--mono);font-size:13px">Methods <strong style="color:{mc}">{methods["score"]}</strong></span>')
        if avg_score is not None:
            ac = score_color(avg_score)
            parts.append(f'<span style="font-family:var(--mono);font-size:13px">Avg <strong style="color:{ac}">{avg_score:.0f}</strong></span>')
        score_summary = f'<div style="display:flex;gap:20px;margin-top:8px">{"".join(parts)}</div>'

    json_data = json.dumps({
        "type": "peer-review",
        "generated": datetime.now().isoformat()[:19],
        "paper": paper_title,
        "journal": journal,
        "decision": decision,
        "domain_score": domain["score"] if has_domain else None,
        "methods_score": methods["score"] if has_methods else None,
        "avg_score": round(avg_score, 1) if avg_score else None,
    })

    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Peer Review — {escape(paper_title[:60])}</title>
  <style>{css}</style>
</head>
<body>
  <script type="application/json" id="report-data">{json_data}</script>
  <div class="page">
    <header style="padding-bottom:24px;border-bottom:1.5px solid var(--g300);margin-bottom:8px">
      <div class="eyebrow">Peer Review Report</div>
      <div class="flex-between" style="align-items:flex-start">
        <div>
          <h1 style="max-width:700px">{escape(paper_title)}</h1>
          <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
            <span class="pill {dcls}">{escape(decision)}</span>
            {"<span class='pill pill-neutral'>" + escape(journal) + "</span>" if journal else ""}
            {"<span class='pill pill-neutral'>" + escape(date) + "</span>" if date else ""}
          </div>
          {score_summary}
        </div>
        <div class="toolbar">
          <button class="toolbar-btn" id="dark-toggle">Dark</button>
          <button class="toolbar-btn" id="print-btn">Print</button>
        </div>
      </div>
    </header>

    {tab_bar}
    {editorial_tab}
    {domain_tab}
    {methods_tab}

    <footer class="generated-footer">
      Generated {generated} by clo-author &middot;
      <a href="https://github.com/hugosantanna/clo-author">github.com/hugosantanna/clo-author</a>
    </footer>
  </div>
  <script>{js}</script>
</body>
</html>"""


# ---------- Code Audit Parser + Builder ----------

def parse_code_audit(text):
    data = {
        "title": "",
        "date": extract_field(text, "Date"),
        "reviewer": extract_field(text, "Reviewer"),
        "paper_type": extract_field(text, "Paper type"),
        "score": 0,
        "mode": extract_field(text, "Mode"),
        "alignment": {"status": "", "detail": ""},
        "code_map": [],
        "sanity_checks": [],
        "numerical": "",
        "robustness": {"done": 0, "total": 0, "checks": []},
        "quality_matrix": [],
        "score_breakdown": [],
        "escalation": "",
        "recommendations": [],
    }

    first_line = text.strip().split("\n")[0]
    m = re.match(r'#\s*Code Audit\s*[—–-]\s*(.*)', first_line)
    if m:
        data["title"] = m.group(1).strip()

    score_str = extract_field(text, "Score")
    sm = re.match(r'(\d+)', score_str)
    if sm:
        data["score"] = int(sm.group(1))

    align_section = extract_section(text, "Code-Strategy Alignment")
    if align_section:
        first_word = align_section.split()[0] if align_section.split() else ""
        data["alignment"]["status"] = first_word.rstrip(":")
        rest = align_section[len(first_word):].strip().lstrip(":")
        data["alignment"]["detail"] = rest.strip()

    map_section = extract_section(text, "Paper-to-Code Map")
    for line in map_section.split("\n"):
        line = line.strip()
        if "→" in line and not line.startswith("Paper symbol"):
            parts = [p.strip() for p in line.split("→")]
            if len(parts) >= 3:
                data["code_map"].append({"symbol": parts[0], "variable": parts[1], "script": parts[2]})

    sanity_section = extract_section(text, "Sanity Checks")
    for line in sanity_section.split("\n"):
        m = re.match(r'-\s*(\w[\w\s]*?):\s*(PASS|FLAG|FAIL)\s*[—–-]?\s*(.*)', line)
        if m:
            data["sanity_checks"].append({"name": m.group(1).strip(), "status": m.group(2), "detail": m.group(3).strip()})

    data["numerical"] = extract_section(text, "Numerical Discipline")

    robust_section = extract_section(text, "Robustness")
    done = len(re.findall(r'\[x\]', robust_section))
    total = len(re.findall(r'\[[ x]\]', robust_section))
    data["robustness"]["done"] = done
    data["robustness"]["total"] = total
    for line in robust_section.split("\n"):
        m = re.match(r'-\s*\[([ x])\]\s*(.*)', line)
        if m:
            data["robustness"]["checks"].append({"done": m.group(1) == "x", "label": m.group(2).strip()})

    quality_section = extract_section(text, "Code Quality")
    for row in extract_table_rows(quality_section):
        if len(row) >= 4:
            try:
                data["quality_matrix"].append({"num": row[0], "category": row[1], "status": row[2], "issues": row[3]})
            except IndexError:
                pass

    breakdown_section = extract_section(text, "Score Breakdown")
    for line in breakdown_section.split("\n"):
        line = line.strip()
        if line and not line.startswith("```") and not line.startswith("Starting") and not line.startswith("Final") and not line.startswith("---"):
            m = re.match(r'(.+?):\s*([+-]?\d+)', line)
            if m:
                data["score_breakdown"].append({"item": m.group(1).strip(), "delta": int(m.group(2)), "note": ""})
                bracket = re.search(r'\[(.+?)\]', line)
                if bracket:
                    data["score_breakdown"][-1]["note"] = bracket.group(1)

    data["escalation"] = extract_section(text, "Escalation Status")

    rec_section = extract_section(text, "Recommendations")
    for m in re.finditer(r'(\d+)\.\s+\*\*\[(\w+)\]\*\*\s+(.*?)(?=\n\d+\.|\Z)', rec_section, re.DOTALL):
        data["recommendations"].append({"num": m.group(1), "severity": m.group(2), "text": m.group(3).strip()})

    return data


def build_code_audit_html(data):
    css, js = load_base_assets()
    score = data["score"]
    scls = score_pill_class(score)
    color = score_color(score)

    align_status = data["alignment"]["status"].upper()
    align_cls = "pill-fail" if align_status == "DEVIATION" else "pill-pass"

    code_map_html = ""
    if data["code_map"]:
        rows = ""
        for m in data["code_map"]:
            rows += f"<tr><td class='mono' style='font-size:12px;color:var(--clay)'>{escape(m['symbol'])}</td><td class='mono' style='font-size:12px'>{escape(m['variable'])}</td><td class='mono' style='font-size:12px;color:var(--g500)'>{escape(m['script'])}</td></tr>"
        code_map_html = f"""
      <h3>Paper-to-Code Map</h3>
      <table class="report-table"><thead><tr><th>Paper Symbol</th><th>Variable</th><th>Script</th></tr></thead><tbody>{rows}</tbody></table>"""

    sanity_html = ""
    if data["sanity_checks"]:
        items = ""
        for ch in data["sanity_checks"]:
            scls2 = "pill-pass" if ch["status"] == "PASS" else ("pill-fail" if ch["status"] == "FAIL" else "pill-warn")
            items += f"""<div class="card" style="margin-bottom:0;padding:12px 16px">
        <div class="flex-between" style="margin-bottom:4px"><span style="font-weight:600;font-size:13px;color:var(--slate)">{escape(ch['name'])}</span><span class="pill {scls2}">{ch['status']}</span></div>
        <div style="font-size:12px;color:var(--g700);line-height:1.5">{escape(ch['detail'])}</div></div>"""
        sanity_html = f'<h3>Sanity Checks</h3><div class="grid-2" style="margin-bottom:20px">{items}</div>'

    robust_html = ""
    if data["robustness"]["total"] > 0:
        pct = data["robustness"]["done"] / data["robustness"]["total"] * 100
        checks_li = ""
        for ch in data["robustness"]["checks"]:
            icon = "&#x2714;" if ch["done"] else "&#x2718;"
            color2 = "var(--accept)" if ch["done"] else "var(--reject)"
            checks_li += f'<li style="margin-bottom:6px;font-size:13px;color:var(--g700)"><span style="color:{color2};margin-right:6px">{icon}</span>{escape(ch["label"])}</li>'
        robust_html = f"""
      <h3>Robustness &nbsp;<span style="font-family:var(--mono);font-size:12px;color:var(--g500)">{data['robustness']['done']}/{data['robustness']['total']}</span></h3>
      <div class="progress-track"><div class="progress-fill" style="width:{pct:.0f}%;background:{"var(--accept)" if pct >= 80 else "var(--warn)" if pct >= 50 else "var(--reject)"}"></div></div>
      <ul style="list-style:none;padding:0;margin:12px 0">{checks_li}</ul>"""

    quality_html = ""
    if data["quality_matrix"]:
        rows = ""
        for q in data["quality_matrix"]:
            st = q["status"].upper()
            stcls = "pill-pass" if st == "OK" else ("pill-warn" if st == "WARN" else "pill-fail")
            rows += f"<tr><td class='mono' style='font-size:12px;color:var(--g500)'>{q['num']}</td><td style='font-weight:500;color:var(--slate);font-size:13px'>{escape(q['category'])}</td><td><span class='pill {stcls}'>{st}</span></td><td style='font-size:12px;color:var(--g700)'>{escape(q['issues'])}</td></tr>"
        quality_html = f"""
      <h3>Code Quality</h3>
      <table class="report-table"><thead><tr><th>#</th><th>Category</th><th>Status</th><th>Issues</th></tr></thead><tbody>{rows}</tbody></table>"""

    breakdown_html = ""
    if data["score_breakdown"]:
        items = '<div style="font-family:var(--mono);font-size:13px;margin:12px 0">'
        items += f'<div class="flex-between" style="padding:6px 0;border-bottom:1.5px solid var(--g300)"><span style="color:var(--slate);font-weight:600">Starting</span><span style="font-weight:600">100</span></div>'
        for bd in data["score_breakdown"]:
            delta_color = "var(--accept)" if bd["delta"] > 0 else "var(--reject)"
            sign = "+" if bd["delta"] > 0 else ""
            items += f'<div class="flex-between" style="padding:6px 0;border-bottom:1px solid var(--g100)"><span style="color:var(--g700)">{escape(bd["item"])}</span><span style="color:{delta_color}">{sign}{bd["delta"]}</span></div>'
        items += f'<div class="flex-between" style="padding:8px 0;font-weight:700;font-size:15px"><span style="color:var(--slate)">Final</span><span style="color:{color}">{score}/100</span></div></div>'
        breakdown_html = f"<h3>Score Breakdown</h3>{items}"

    recs_html = ""
    if data["recommendations"]:
        items = ""
        for r in data["recommendations"]:
            sev = r["severity"].upper()
            scls3 = "pill-reject" if sev == "CRITICAL" else ("pill-major" if sev == "MAJOR" else "pill-warn")
            items += f"""<div class="card card-bordered-left" style="{'border-left-color:var(--reject)' if sev == 'CRITICAL' else 'border-left-color:var(--major-rev)' if sev == 'MAJOR' else ''}">
        <div style="margin-bottom:6px"><span class="pill {scls3}">{sev}</span></div>
        <div style="font-size:13.5px;color:var(--g700);line-height:1.55">{md_to_html(r['text'])}</div></div>"""
        recs_html = f"<h3>Recommendations</h3>{items}"

    json_data = json.dumps({"type": "code-audit", "generated": datetime.now().isoformat()[:19], "score": score, "paper_type": data["paper_type"]})
    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Code Audit — {escape(data['title'][:60])}</title>
  <style>{css}</style>
</head>
<body>
  <script type="application/json" id="report-data">{json_data}</script>
  <div class="page">
    <header style="padding-bottom:24px;border-bottom:1.5px solid var(--g300);margin-bottom:8px">
      <div class="eyebrow">Code Audit</div>
      <div class="flex-between" style="align-items:flex-start">
        <div>
          <h1 style="max-width:700px">{escape(data['title'] or 'Code Audit')}</h1>
          <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
            <span class="pill {scls}">{score}/100</span>
            <span class="pill pill-neutral">{escape(data['paper_type'])}</span>
            <span class="pill pill-neutral">{escape(data['date'])}</span>
          </div>
        </div>
        <div class="toolbar">
          <button class="toolbar-btn" id="dark-toggle">Dark</button>
          <button class="toolbar-btn" id="print-btn">Print</button>
        </div>
      </div>
    </header>

    <section>
      <h3>Code-Strategy Alignment</h3>
      <div class="card {'card-red' if align_status == 'DEVIATION' else 'card-green'}">
        <div style="margin-bottom:6px"><span class="pill {align_cls}">{align_status}</span></div>
        <div style="font-size:14px;color:var(--g700);line-height:1.6">{md_to_html(data['alignment']['detail'])}</div>
      </div>
    </section>

    <section style="margin-top:32px">
      {code_map_html}
      {sanity_html}
      {robust_html}
      {quality_html}
      {breakdown_html}
      {recs_html}
    </section>

    <footer class="generated-footer">
      Generated {generated} by clo-author &middot;
      <a href="https://github.com/hugosantanna/clo-author">github.com/hugosantanna/clo-author</a>
    </footer>
  </div>
  <script>{js}</script>
</body>
</html>"""


# ---------- Strategy Review Parser + Builder ----------

def parse_strategy_review(text):
    data = {
        "title": "",
        "date": extract_field(text, "Date"),
        "reviewer": extract_field(text, "Reviewer"),
        "claim": {},
        "phases": [],
        "sanity_checks": [],
        "summary": {},
        "recommendations": [],
        "positives": [],
    }

    first_line = text.strip().split("\n")[0]
    m = re.match(r'#\s*Strategy Review[:\s]*(.+)', first_line)
    if m:
        data["title"] = m.group(1).strip()

    claim_section = extract_section(text, "Phase 1: Claim Identification")
    for line in claim_section.split("\n"):
        m = re.match(r'-\s*\*\*(.+?):\*\*\s*(.*)', line)
        if m:
            data["claim"][m.group(1).strip().lower().replace(" ", "_")] = m.group(2).strip()

    for phase_num in [2, 3, 4]:
        phase_pattern = rf'## Phase {phase_num}: (.+?)\n(.*?)(?=\n## Phase|\n## Summary|\Z)'
        pm = re.search(phase_pattern, text, re.DOTALL)
        if pm:
            phase = {"num": phase_num, "name": pm.group(1).strip(), "issues": []}
            issue_pattern = r'##### Issue (\d+\.\d+): (.+?)\n(.*?)(?=\n##### Issue|\n## Phase|\n###? Sanity|\n## Summary|\Z)'
            for im in re.finditer(issue_pattern, pm.group(2), re.DOTALL):
                issue = {"id": im.group(1), "title": im.group(2).strip(), "location": "", "severity": "", "problem": "", "fix": ""}
                body = im.group(3)
                loc = re.search(r'\*\*Location:\*\*\s*(.*)', body)
                if loc: issue["location"] = loc.group(1).strip()
                sev = re.search(r'\*\*Severity:\*\*\s*(.*)', body)
                if sev: issue["severity"] = sev.group(1).strip()
                prob = re.search(r'\*\*Problem:\*\*\s*(.*?)(?=\n- \*\*|\Z)', body, re.DOTALL)
                if prob: issue["problem"] = prob.group(1).strip()
                fix = re.search(r'\*\*Suggested fix:\*\*\s*(.*?)(?=\n##### |\n## |\Z)', body, re.DOTALL)
                if fix: issue["fix"] = fix.group(1).strip()
                phase["issues"].append(issue)

            sanity_in_phase = re.search(r'### Sanity Check\n(.*?)(?=\n## |\Z)', pm.group(2), re.DOTALL)
            if sanity_in_phase:
                for line in sanity_in_phase.group(1).split("\n"):
                    sm = re.match(r'-\s*\*\*(\w+):\*\*\s*(\w+)\.?\s*(.*)', line)
                    if sm:
                        data["sanity_checks"].append({"name": sm.group(1), "status": sm.group(2), "detail": sm.group(3).strip()})

            data["phases"].append(phase)

    summary_section = extract_section(text, "Summary")
    for line in summary_section.split("\n"):
        m = re.match(r'-\s*\*\*(.+?):\*\*\s*(.*)', line)
        if m:
            data["summary"][m.group(1).strip().lower()] = m.group(2).strip()

    rec_section = extract_section(text, "Priority Recommendations")
    for rm in re.finditer(r'(\d+)\.\s+\*\*\[(\w+)\]\*\*\s+(.*?)(?=\n\d+\.|\Z)', rec_section, re.DOTALL):
        data["recommendations"].append({"num": rm.group(1), "severity": rm.group(2), "text": rm.group(3).strip()})

    pos_section = extract_section(text, "Positive Findings")
    data["positives"] = parse_bullet_list(pos_section)

    return data


def build_strategy_review_html(data):
    css, js = load_base_assets()

    overall = data["summary"].get("overall assessment", "").upper()
    overall_cls = "pill-reject" if "MAJOR" in overall else ("pill-warn" if "MINOR" in overall else "pill-pass")

    claim_html = ""
    if data["claim"]:
        items = "".join(f'<div style="margin-bottom:6px"><span style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.06em;color:var(--g500)">{escape(k.replace("_"," "))}</span><br><span style="font-size:13.5px;color:var(--slate)">{escape(v)}</span></div>' for k, v in data["claim"].items())
        claim_html = f'<div class="card" style="display:grid;grid-template-columns:1fr 1fr;gap:12px">{items}</div>'

    phases_html = ""
    for phase in data["phases"]:
        issues_html = ""
        for iss in phase["issues"]:
            sev = iss["severity"].upper()
            sev_cls = "pill-reject" if sev == "CRITICAL" else ("pill-major" if sev == "MAJOR" else "pill-warn")
            loc_html = f'<div class="mono" style="font-size:11px;color:var(--g500);margin-bottom:8px">{escape(iss["location"])}</div>' if iss["location"] else ""
            issues_html += f"""
        <div class="card card-bordered-left" style="{'border-left-color:var(--reject)' if sev == 'CRITICAL' else 'border-left-color:var(--major-rev)' if sev == 'MAJOR' else ''}margin-bottom:12px">
          <div class="flex-between" style="margin-bottom:6px">
            <span style="font-family:var(--serif);font-weight:500;color:var(--slate);font-size:14px">{escape(iss['id'])}. {escape(iss['title'])}</span>
            <span class="pill {sev_cls}">{sev}</span>
          </div>
          {loc_html}
          <div class="collapsible-header open">Problem</div>
          <div class="collapsible-body open" style="font-size:13.5px;color:var(--g700);line-height:1.55">{md_to_html(iss['problem'])}</div>
          {f'''<div class="collapsible-header">Suggested Fix</div>
          <div class="collapsible-body" style="font-size:13.5px;color:var(--g700);line-height:1.55;padding:8px 0 8px 22px;background:var(--g100);border-radius:8px;padding:12px 16px;margin-top:4px">{md_to_html(iss["fix"])}</div>''' if iss["fix"] else ""}
        </div>"""

        issue_count = len(phase["issues"])
        phases_html += f"""
      <div style="margin-bottom:28px">
        <div class="collapsible-header open" style="font-family:var(--serif);font-size:18px;color:var(--slate)">
          Phase {phase['num']}: {escape(phase['name'])} &nbsp;<span style="font-family:var(--mono);font-size:12px;color:var(--g500)">{issue_count} issue{'s' if issue_count != 1 else ''}</span>
        </div>
        <div class="collapsible-body open">{issues_html}</div>
      </div>"""

    sanity_html = ""
    if data["sanity_checks"]:
        items = ""
        for ch in data["sanity_checks"]:
            pcls = sanity_pill_class(ch["status"])
            items += f'<div class="card" style="margin-bottom:0;padding:12px 16px"><div class="flex-between" style="margin-bottom:4px"><span style="font-weight:600;font-size:13px;color:var(--slate)">{escape(ch["name"])}</span><span class="pill {pcls}">{escape(ch["status"])}</span></div><div style="font-size:12px;color:var(--g700);line-height:1.5">{escape(ch["detail"][:200])}</div></div>'
        sanity_html = f'<h3>Sanity Checks</h3><div class="grid-2" style="margin-bottom:20px">{items}</div>'

    recs_html = ""
    if data["recommendations"]:
        items = ""
        for r in data["recommendations"]:
            sev = r["severity"].upper()
            scls = "pill-reject" if sev == "CRITICAL" else ("pill-major" if sev == "MAJOR" else "pill-warn")
            items += f'<div class="card card-bordered-left" style="{"border-left-color:var(--reject)" if sev == "CRITICAL" else "border-left-color:var(--major-rev)" if sev == "MAJOR" else ""}"><div style="margin-bottom:6px"><span class="pill {scls}">{sev}</span></div><div style="font-size:13.5px;color:var(--g700);line-height:1.55">{md_to_html(r["text"])}</div></div>'
        recs_html = f"<h3>Priority Recommendations</h3>{items}"

    positives_html = ""
    if data["positives"]:
        items = "".join(f'<li style="margin-bottom:8px;font-size:13.5px;color:var(--g700);line-height:1.55">{md_to_html(p)}</li>' for p in data["positives"])
        positives_html = f'<div class="card card-green" style="margin-top:20px"><h3 style="margin-top:0;color:var(--accept)">Positive Findings</h3><ul style="padding-left:20px;margin:8px 0">{items}</ul></div>'

    json_data = json.dumps({"type": "strategy-review", "generated": datetime.now().isoformat()[:19], "overall": overall})
    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Strategy Review — {escape(data['title'][:60])}</title>
  <style>{css}</style>
</head>
<body>
  <script type="application/json" id="report-data">{json_data}</script>
  <div class="page">
    <header style="padding-bottom:24px;border-bottom:1.5px solid var(--g300);margin-bottom:8px">
      <div class="eyebrow">Strategy Review</div>
      <div class="flex-between" style="align-items:flex-start">
        <div>
          <h1 style="max-width:700px">{escape(data['title'] or 'Strategy Review')}</h1>
          <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
            <span class="pill {overall_cls}">{escape(overall or 'Review')}</span>
            <span class="pill pill-neutral">{escape(data['claim'].get('paper_type', ''))}</span>
            <span class="pill pill-neutral">{escape(data['claim'].get('design', ''))}</span>
            <span class="pill pill-neutral">{escape(data['date'])}</span>
          </div>
        </div>
        <div class="toolbar">
          <button class="toolbar-btn" id="dark-toggle">Dark</button>
          <button class="toolbar-btn" id="print-btn">Print</button>
        </div>
      </div>
    </header>

    <section>
      <h3>Claim Identification</h3>
      {claim_html}
    </section>

    <section style="margin-top:32px">
      {phases_html}
      {sanity_html}
    </section>

    <section style="margin-top:32px">
      {recs_html}
      {positives_html}
    </section>

    <footer class="generated-footer">
      Generated {generated} by clo-author &middot;
      <a href="https://github.com/hugosantanna/clo-author">github.com/hugosantanna/clo-author</a>
    </footer>
  </div>
  <script>{js}</script>
</body>
</html>"""


# ---------- CLI ----------

def cmd_peer_review(args):
    domain_text = None
    methods_text = None
    editorial_text = None

    for fpath in args.files:
        p = Path(fpath)
        if not p.exists():
            print(f"Warning: {fpath} not found, skipping", file=sys.stderr)
            continue
        text = p.read_text(errors="replace")
        fname = p.name.lower()

        if "domain" in fname or "Domain Referee" in text[:200]:
            domain_text = text
        elif "methods" in fname or "Methods Referee" in text[:200]:
            methods_text = text
        elif "editorial" in fname or "editor" in fname or "Editorial Decision" in text[:200]:
            editorial_text = text
        else:
            first_line = text.strip().split("\n")[0].lower()
            if "methods" in first_line:
                methods_text = text
            elif "domain" in first_line:
                domain_text = text
            elif "editorial" in first_line or "decision" in first_line:
                editorial_text = text
            else:
                print(f"Warning: Could not classify {fpath}, skipping", file=sys.stderr)

    if not editorial_text and not methods_text:
        print("Error: Need at least an editorial decision or methods referee report.", file=sys.stderr)
        sys.exit(1)

    domain = parse_domain_referee(domain_text) if domain_text else None
    methods = parse_methods_referee(methods_text) if methods_text else None

    if editorial_text:
        editorial = parse_editorial_decision(editorial_text)
    else:
        editorial = {
            "date": methods["date"] if methods else "",
            "journal": "",
            "paper": methods["paper"] if methods else (domain["paper"] if domain else ""),
            "decision": methods["recommendation"] if methods else "",
            "assessment": "",
            "referee_summary": "",
            "must_address": [],
            "should_address": [],
            "may_push_back": [],
            "disagreements": "",
            "timeline": "",
        }

    html = build_peer_review_html(domain, methods, editorial)

    if args.output:
        out = Path(args.output)
    else:
        first_file = Path(args.files[0])
        date_prefix = re.match(r'(\d{4}-\d{2}-\d{2})', first_file.name)
        prefix = date_prefix.group(1) + "_" if date_prefix else ""
        out = first_file.parent / f"{prefix}peer_review.html"

    out.write_text(html)
    print(f"Peer review report generated: {out}")
    return out


# ---------- Quality Gate Parser + Builder ----------

def parse_quality_gate(text):
    data = {
        "date": extract_field(text, "Date"),
        "paper": extract_field(text, "Paper"),
        "phase": extract_field(text, "Pipeline phase"),
        "gate_requested": extract_field(text, "Gate requested"),
        "overall": None,
        "result": "",
        "components": [],
        "blocking": [],
        "passing": [],
        "action": "",
        "escalation": "",
    }

    m = re.search(r'Weighted Aggregate:\s*([\d.]+)', text)
    if m:
        data["overall"] = float(m.group(1))
    m = re.search(r'Gate Result:\s*(\w+)', text)
    if m:
        data["result"] = m.group(1)

    for row in re.finditer(
        r'\|\s*([^|]+?)\s*\|\s*(\d+)%\s*\|\s*([^|]+?)\s*\|\s*(\d+)/100\s*\|\s*(\w+)\s*\|', text
    ):
        data["components"].append({
            "name": row.group(1).strip(),
            "weight": int(row.group(2)),
            "agent": row.group(3).strip(),
            "score": int(row.group(4)),
            "status": row.group(5).strip(),
        })

    blocking_section = re.search(r'## Blocking Components\s*\n(.*?)(?=\n## Passing|\n## Recommended|\Z)', text, re.DOTALL)
    if blocking_section:
        for bm in re.finditer(r'### (.+?)\n(.*?)(?=\n### |\Z)', blocking_section.group(1), re.DOTALL):
            data["blocking"].append({"title": bm.group(1).strip(), "detail": bm.group(2).strip()})

    passing_section = re.search(r'## Passing Components.*?\n(.*?)(?=\n## Recommended|\n## Escalation|\Z)', text, re.DOTALL)
    if passing_section:
        for pm in re.finditer(r'### (.+?)\n(.*?)(?=\n### |\Z)', passing_section.group(1), re.DOTALL):
            data["passing"].append({"title": pm.group(1).strip(), "detail": pm.group(2).strip()})

    data["action"] = extract_section(text, "Recommended Action")
    data["escalation"] = extract_section(text, "Escalation Log")

    return data


def build_quality_gate_html(data):
    css, js = load_base_assets()
    overall = data["overall"] or 0
    result = data["result"]
    result_cls = "pill-pass" if result == "PASS" else "pill-fail"
    gauge_color = score_color(overall) if overall else "var(--g500)"

    gauge_html = f"""
    <div class="score-gauge">
      <div class="score-gauge-number" style="color:{gauge_color}">{overall:.1f}</div>
      <div class="score-gauge-label">weighted aggregate</div>
    </div>"""

    gates_html = '<div style="max-width:600px;margin:0 auto 28px">'
    for label, threshold in [("Commit", 80), ("PR", 90), ("Submission", 95)]:
        pct = min(overall / threshold * 100, 100)
        color = "var(--accept)" if overall >= threshold else "var(--reject)"
        passed = "PASS" if overall >= threshold else "FAIL"
        pcls = "pill-pass" if passed == "PASS" else "pill-fail"
        gates_html += f"""
      <div class="gate-row">
        <span class="gate-label">{label} &ge;{threshold}</span>
        <div class="gate-track"><div class="gate-fill" style="width:{pct:.0f}%;background:{color}"></div></div>
        <span class="gate-value">{overall:.1f}</span>
        <span class="pill {pcls}">{passed}</span>
      </div>"""
    gates_html += "</div>"

    comp_html = '<div class="grid-2">'
    for c in data["components"]:
        color = score_color(c["score"])
        scls = score_pill_class(c["score"])
        comp_html += f"""
      <div class="card" style="margin-bottom:0">
        <div class="flex-between" style="margin-bottom:8px">
          <div>
            <span style="font-family:var(--serif);font-weight:500;color:var(--slate);font-size:14px">{escape(c['name'])}</span>
            <span style="font-family:var(--mono);font-size:11px;color:var(--g500)">{c['weight']}%</span>
          </div>
          <span class="pill {scls}">{c['score']}</span>
        </div>
        <div class="score-bar-track"><div class="score-bar-fill" style="width:{c['score']}%;background:{color}"></div></div>
        <div style="font-family:var(--mono);font-size:11px;color:var(--g500);margin-top:6px">{escape(c['agent'])}</div>
      </div>"""
    comp_html += "</div>"

    blocking_html = ""
    if data["blocking"]:
        items = ""
        for b in data["blocking"]:
            items += f"""
      <div class="card card-red" style="margin-bottom:12px">
        <div class="collapsible-header open" style="color:var(--reject)">{escape(b['title'])}</div>
        <div class="collapsible-body open" style="font-size:13.5px;color:var(--g700);line-height:1.6">{md_to_html(b['detail'])}</div>
      </div>"""
        blocking_html = f"<h3>Blocking Components</h3>{items}"

    passing_html = ""
    if data["passing"]:
        items = ""
        for p in data["passing"]:
            items += f"""
      <div class="card card-green" style="margin-bottom:12px">
        <div class="collapsible-header">{escape(p['title'])}</div>
        <div class="collapsible-body" style="font-size:13px;color:var(--g700);line-height:1.6">{md_to_html(p['detail'])}</div>
      </div>"""
        passing_html = f"<h3>Passing Components</h3>{items}"

    action_html = ""
    if data["action"]:
        action_html = f'<div class="alert alert-info" style="margin-top:24px"><strong>Recommended Action</strong><div style="margin-top:6px;font-size:13.5px;line-height:1.6">{md_to_html(data["action"])}</div></div>'

    escalation_html = ""
    if data["escalation"]:
        escalation_html = f'<h3>Escalation Log</h3><div style="font-size:13px;color:var(--g700);line-height:1.6">{md_to_html(data["escalation"])}</div>'

    json_data = json.dumps({"type": "quality-gate", "generated": datetime.now().isoformat()[:19], "overall": overall, "result": result})
    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Quality Gate — {escape(data['paper'][:60])}</title>
  <style>{css}</style>
</head>
<body>
  <script type="application/json" id="report-data">{json_data}</script>
  <div class="page">
    <header style="padding-bottom:24px;border-bottom:1.5px solid var(--g300);margin-bottom:8px">
      <div class="eyebrow">Quality Gate</div>
      <div class="flex-between" style="align-items:flex-start">
        <div>
          <h1 style="max-width:700px">{escape(data['paper'] or 'Quality Gate Summary')}</h1>
          <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
            <span class="pill {result_cls}">{escape(result)}</span>
            <span class="pill pill-neutral">{escape(data['phase'])}</span>
            <span class="pill pill-neutral">{escape(data['gate_requested'])}</span>
            <span class="pill pill-neutral">{escape(data['date'])}</span>
          </div>
        </div>
        <div class="toolbar">
          <button class="toolbar-btn" id="dark-toggle">Dark</button>
          <button class="toolbar-btn" id="print-btn">Print</button>
        </div>
      </div>
    </header>

    <section>
      {gauge_html}
      {gates_html}
    </section>

    <section style="margin-top:16px">
      <h3>Components</h3>
      {comp_html}
    </section>

    <section style="margin-top:32px">
      {blocking_html}
      {passing_html}
      {action_html}
      {escalation_html}
    </section>

    <footer class="generated-footer">
      Generated {generated} by clo-author &middot;
      <a href="https://github.com/hugosantanna/clo-author">github.com/hugosantanna/clo-author</a>
    </footer>
  </div>
  <script>{js}</script>
</body>
</html>"""


# ---------- Literature Parser + Builder ----------

def parse_literature(text):
    data = {
        "title": "",
        "date": extract_field(text, "Date"),
        "topic": extract_field(text, "Topic"),
        "total": 0,
        "papers": [],
    }

    first_line = text.strip().split("\n")[0]
    m = re.match(r'#\s*Annotated Bibliography[:\s]*(.+)', first_line)
    if m:
        data["title"] = m.group(1).strip()

    total_str = extract_field(text, "Papers reviewed")
    tm = re.match(r'(\d+)', total_str)
    if tm:
        data["total"] = int(tm.group(1))

    categories = [
        "Directly Related",
        "Same Method, Different Context",
        "Same Context, Different Method",
        "Theoretical Foundations",
        "Methods Papers",
    ]

    for cat in categories:
        pattern = rf'^##\s+{re.escape(cat)}\s*\n(.*?)(?=\n##\s[^#]|\Z)'
        sec = re.search(pattern, text, re.MULTILINE | re.DOTALL)
        if not sec:
            continue
        body = sec.group(1)

        entries = re.split(r'(?:^|\n)###\s+', body)
        for entry in entries:
            entry = entry.strip()
            if not entry:
                continue

            header_match = re.match(r'(.+?)(?:\s*[—–-]\s*)(.+?)(?:\n|$)', entry)
            if header_match:
                author_year = header_match.group(1).strip()
                short_title = header_match.group(2).strip()
            else:
                first = entry.split("\n")[0].strip()
                author_year = first
                short_title = ""

            year_match = re.search(r'\((\d{4})\)', author_year)
            year = int(year_match.group(1)) if year_match else 0

            author_only = re.sub(r'\s*\(\d{4}\)', '', author_year).strip()

            journal = ""
            jm = re.search(r'\*\*Journal:\*\*\s*(.+)', entry)
            if jm:
                journal = jm.group(1).strip()

            proximity = 0
            pm = re.search(r'\*\*Proximity:\*\*\s*(\d)', entry)
            if pm:
                proximity = int(pm.group(1))

            contribution = ""
            cm = re.search(r'\*\*Main contribution:\*\*\s*(.+)', entry)
            if cm:
                contribution = cm.group(1).strip()

            strategy = ""
            sm = re.search(r'\*\*Identification strategy:\*\*\s*(.+)', entry)
            if sm:
                strategy = sm.group(1).strip()

            finding = ""
            fm = re.search(r'\*\*Key finding:\*\*\s*(.+)', entry)
            if fm:
                finding = fm.group(1).strip()

            relevance = ""
            rm = re.search(r'\*\*Relevance:\*\*\s*(.+)', entry)
            if rm:
                relevance = rm.group(1).strip()

            data["papers"].append({
                "category": cat,
                "author_year": author_year,
                "author_only": author_only,
                "short_title": short_title,
                "year": year,
                "journal": journal,
                "proximity": proximity,
                "contribution": contribution,
                "strategy": strategy,
                "finding": finding,
                "relevance": relevance,
            })

    if not data["total"]:
        data["total"] = len(data["papers"])

    return data


def proximity_pill_class(prox):
    if prox >= 5: return "pill-accent"
    if prox >= 4: return "pill-pass"
    if prox >= 3: return "pill-warn"
    if prox >= 2: return "pill-neutral"
    return "pill-neutral"


def category_short(cat):
    mapping = {
        "Directly Related": "direct",
        "Same Method, Different Context": "same-method",
        "Same Context, Different Method": "same-context",
        "Theoretical Foundations": "theory",
        "Methods Papers": "methods",
    }
    return mapping.get(cat, cat.lower().replace(" ", "-"))


def category_label(cat):
    mapping = {
        "Directly Related": "Direct",
        "Same Method, Different Context": "Same Method",
        "Same Context, Different Method": "Same Context",
        "Theoretical Foundations": "Theory",
        "Methods Papers": "Methods",
    }
    return mapping.get(cat, cat)


def build_literature_html(data):
    css, js = load_base_assets()

    papers = data["papers"]
    total = data["total"] or len(papers)

    categories_present = []
    seen_cats = set()
    for p in papers:
        if p["category"] not in seen_cats:
            categories_present.append(p["category"])
            seen_cats.add(p["category"])

    methods_present = []
    seen_methods = set()
    for p in papers:
        s = p["strategy"].strip()
        if s and s not in seen_methods:
            methods_present.append(s)
            seen_methods.add(s)

    proximities_present = sorted(set(p["proximity"] for p in papers if p["proximity"]), reverse=True)

    cat_counts = {}
    for p in papers:
        cat_counts[p["category"]] = cat_counts.get(p["category"], 0) + 1

    avg_prox = 0
    prox_vals = [p["proximity"] for p in papers if p["proximity"]]
    if prox_vals:
        avg_prox = sum(prox_vals) / len(prox_vals)

    stats_html = f"""
    <div class="stats-row">
      <div class="stat-card">
        <div class="stat-number">{total}</div>
        <div class="stat-label">Papers</div>
      </div>"""
    for cat in categories_present:
        stats_html += f"""
      <div class="stat-card">
        <div class="stat-number">{cat_counts.get(cat, 0)}</div>
        <div class="stat-label">{escape(category_label(cat))}</div>
      </div>"""
    stats_html += f"""
      <div class="stat-card">
        <div class="stat-number">{avg_prox:.1f}</div>
        <div class="stat-label">Avg Proximity</div>
      </div>
    </div>"""

    filter_html = '<div id="lit-filters" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding:12px 0;margin-bottom:16px">'

    filter_html += '<div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;width:100%">'
    filter_html += '<span style="font-family:var(--mono);font-size:10px;color:var(--g500);text-transform:uppercase;letter-spacing:0.08em;margin-right:4px">Category</span>'
    for cat in categories_present:
        filter_html += f'<button class="filter-btn" data-filter="{escape(category_short(cat))}" data-group="category">{escape(category_label(cat))}</button>'
    filter_html += '</div>'

    filter_html += '<div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;width:100%;margin-top:8px">'
    filter_html += '<span style="font-family:var(--mono);font-size:10px;color:var(--g500);text-transform:uppercase;letter-spacing:0.08em;margin-right:4px">Proximity</span>'
    for prox in proximities_present:
        filter_html += f'<button class="filter-btn" data-filter="{prox}" data-group="proximity">{prox}</button>'
    filter_html += '</div>'

    if methods_present:
        filter_html += '<div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;width:100%;margin-top:8px">'
        filter_html += '<span style="font-family:var(--mono);font-size:10px;color:var(--g500);text-transform:uppercase;letter-spacing:0.08em;margin-right:4px">Method</span>'
        for method in methods_present:
            filter_html += f'<button class="filter-btn" data-filter="{escape(method.lower())}" data-group="method">{escape(method)}</button>'
        filter_html += '</div>'

    filter_html += '<div style="display:flex;gap:8px;align-items:center;width:100%;margin-top:10px">'
    filter_html += '<input type="text" class="filter-search" placeholder="Search papers..." id="lit-search">'
    filter_html += '<span id="filter-count" style="font-family:var(--mono);font-size:11px;color:var(--g500);white-space:nowrap"></span>'
    filter_html += '</div>'

    filter_html += '</div>'

    sort_html = """
    <div style="display:flex;gap:8px;align-items:center;margin-bottom:16px">
      <span style="font-family:var(--mono);font-size:10px;color:var(--g500);text-transform:uppercase;letter-spacing:0.08em">Sort</span>
      <button class="filter-btn active" data-sort="proximity">Proximity</button>
      <button class="filter-btn" data-sort="year">Year</button>
      <button class="filter-btn" data-sort="author">Author</button>
    </div>"""

    cards_html = '<div id="paper-list">'
    for p in papers:
        cat_s = category_short(p["category"])
        prox_cls = proximity_pill_class(p["proximity"])
        method_lower = p["strategy"].lower() if p["strategy"] else ""

        body_parts = []
        if p["contribution"]:
            body_parts.append(f'<div style="margin-bottom:10px"><span style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.06em;color:var(--g500)">Contribution</span><div style="font-size:13.5px;color:var(--g700);line-height:1.55;margin-top:2px">{escape(p["contribution"])}</div></div>')
        if p["finding"]:
            body_parts.append(f'<div style="margin-bottom:10px"><span style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.06em;color:var(--g500)">Key Finding</span><div style="font-size:13.5px;color:var(--g700);line-height:1.55;margin-top:2px">{escape(p["finding"])}</div></div>')
        if p["relevance"]:
            body_parts.append(f'<div style="margin-bottom:4px"><span style="font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.06em;color:var(--olive)">Relevance</span><div style="font-size:13.5px;color:var(--g700);line-height:1.55;margin-top:2px">{escape(p["relevance"])}</div></div>')

        body_html = "".join(body_parts)

        cards_html += f"""
      <div class="card paper-card" data-filterable
           data-category="{cat_s}"
           data-proximity="{p['proximity']}"
           data-method="{escape(method_lower)}"
           data-year="{p['year']}"
           data-author="{escape(p['author_only'].lower())}">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
          <div style="flex:1">
            <div style="font-family:var(--serif);font-size:16px;font-weight:500;color:var(--slate);line-height:1.3">{escape(p['author_year'])}</div>
            <div style="font-size:13px;color:var(--g500);margin-top:2px;line-height:1.4">{escape(p['short_title'])}</div>
          </div>
          <button class="copy-btn" data-copy="{escape(p['author_year'])}">Cite</button>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:10px">
          {"<span class='pill pill-neutral'>" + escape(p['journal']) + "</span>" if p['journal'] else ""}
          <span class="pill {prox_cls}">Prox {p['proximity']}</span>
          {"<span class='pill pill-neutral'>" + escape(p['strategy']) + "</span>" if p['strategy'] else ""}
          <span class="pill pill-neutral">{escape(category_label(p['category']))}</span>
        </div>
        <div class="collapsible-header open" style="margin-top:8px">Details</div>
        <div class="collapsible-body open">{body_html}</div>
      </div>"""
    cards_html += '</div>'

    lit_js = """
(function() {
  'use strict';

  var container = document.getElementById('paper-list');
  var filterBar = document.getElementById('lit-filters');
  if (!container || !filterBar) return;

  var cards = function() { return container.querySelectorAll('.paper-card'); };
  var searchInput = document.getElementById('lit-search');
  var counterEl = document.getElementById('filter-count');
  var sortBtns = document.querySelectorAll('[data-sort]');

  function getActiveFilters(group) {
    var vals = [];
    filterBar.querySelectorAll('.filter-btn[data-group="' + group + '"].active').forEach(function(b) {
      vals.push(b.getAttribute('data-filter'));
    });
    return vals;
  }

  function applyAllFilters() {
    var catFilters = getActiveFilters('category');
    var proxFilters = getActiveFilters('proximity');
    var methFilters = getActiveFilters('method');
    var query = searchInput ? searchInput.value.toLowerCase().trim() : '';
    var shown = 0;
    var total = 0;

    cards().forEach(function(card) {
      total++;
      var matchCat = catFilters.length === 0 || catFilters.indexOf(card.getAttribute('data-category')) !== -1;
      var matchProx = proxFilters.length === 0 || proxFilters.indexOf(card.getAttribute('data-proximity')) !== -1;
      var matchMeth = methFilters.length === 0 || methFilters.indexOf(card.getAttribute('data-method')) !== -1;
      var matchSearch = !query || (card.textContent || '').toLowerCase().indexOf(query) !== -1;
      var visible = matchCat && matchProx && matchMeth && matchSearch;
      card.style.display = visible ? '' : 'none';
      if (visible) shown++;
    });

    if (counterEl) counterEl.textContent = 'Showing ' + shown + ' of ' + total;
  }

  filterBar.querySelectorAll('.filter-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      btn.classList.toggle('active');
      applyAllFilters();
    });
  });

  if (searchInput) searchInput.addEventListener('input', applyAllFilters);

  function sortCards(key) {
    var arr = Array.prototype.slice.call(cards());
    arr.sort(function(a, b) {
      if (key === 'proximity') {
        return parseInt(b.getAttribute('data-proximity') || '0') - parseInt(a.getAttribute('data-proximity') || '0');
      } else if (key === 'year') {
        return parseInt(b.getAttribute('data-year') || '0') - parseInt(a.getAttribute('data-year') || '0');
      } else if (key === 'author') {
        return (a.getAttribute('data-author') || '').localeCompare(b.getAttribute('data-author') || '');
      }
      return 0;
    });
    arr.forEach(function(card) { container.appendChild(card); });
  }

  sortBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      sortBtns.forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      sortCards(btn.getAttribute('data-sort'));
    });
  });

  applyAllFilters();
})();
"""

    json_data = json.dumps({
        "type": "literature",
        "generated": datetime.now().isoformat()[:19],
        "topic": data["topic"],
        "total": total,
        "avg_proximity": round(avg_prox, 2),
    })
    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bibliography — {escape(data['title'][:60])}</title>
  <style>{css}</style>
</head>
<body>
  <script type="application/json" id="report-data">{json_data}</script>
  <div class="page">
    <header style="padding-bottom:24px;border-bottom:1.5px solid var(--g300);margin-bottom:8px">
      <div class="eyebrow">Annotated Bibliography</div>
      <div class="flex-between" style="align-items:flex-start">
        <div>
          <h1 style="max-width:700px">{escape(data['title'] or 'Annotated Bibliography')}</h1>
          <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
            <span class="pill pill-accent">{total} papers</span>
            <span class="pill pill-neutral">{escape(data['date'])}</span>
          </div>
        </div>
        <div class="toolbar">
          <button class="toolbar-btn" id="dark-toggle">Dark</button>
          <button class="toolbar-btn" id="print-btn">Print</button>
        </div>
      </div>
      {stats_html}
    </header>

    <section style="margin-top:28px">
      {filter_html}
      {sort_html}
      {cards_html}
    </section>

    <footer class="generated-footer">
      Generated {generated} by clo-author &middot;
      <a href="https://github.com/hugosantanna/clo-author">github.com/hugosantanna/clo-author</a>
    </footer>
  </div>
  <script>{js}</script>
  <script>{lit_js}</script>
</body>
</html>"""


# ---------- CLI ----------

def cmd_code_audit(args):
    p = Path(args.file)
    if not p.exists():
        print(f"Error: {args.file} not found", file=sys.stderr)
        sys.exit(1)
    data = parse_code_audit(p.read_text(errors="replace"))
    html = build_code_audit_html(data)
    if args.output:
        out = Path(args.output)
    else:
        out = p.with_suffix(".html")
    out.write_text(html)
    print(f"Code audit report generated: {out}")
    return out


def cmd_strategy_review(args):
    p = Path(args.file)
    if not p.exists():
        print(f"Error: {args.file} not found", file=sys.stderr)
        sys.exit(1)
    data = parse_strategy_review(p.read_text(errors="replace"))
    html = build_strategy_review_html(data)
    if args.output:
        out = Path(args.output)
    else:
        out = p.with_suffix(".html")
    out.write_text(html)
    print(f"Strategy review report generated: {out}")
    return out


def cmd_quality_gate(args):
    p = Path(args.file)
    if not p.exists():
        print(f"Error: {args.file} not found", file=sys.stderr)
        sys.exit(1)
    data = parse_quality_gate(p.read_text(errors="replace"))
    html = build_quality_gate_html(data)
    if args.output:
        out = Path(args.output)
    else:
        out = p.with_suffix(".html")
    out.write_text(html)
    print(f"Quality gate report generated: {out}")
    return out


def cmd_literature(args):
    p = Path(args.file)
    if not p.exists():
        print(f"Error: {args.file} not found", file=sys.stderr)
        sys.exit(1)
    data = parse_literature(p.read_text(errors="replace"))
    html = build_literature_html(data)
    if args.output:
        out = Path(args.output)
    else:
        out = p.with_suffix(".html")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html)
    print(f"Literature report generated: {out}")
    return out


def main():
    parser = argparse.ArgumentParser(description="Generate clo-author HTML detail reports")
    sub = parser.add_subparsers(dest="command")

    pr = sub.add_parser("peer-review", help="Combined peer review report")
    pr.add_argument("files", nargs="+", help="Markdown report files (domain, methods, editorial)")
    pr.add_argument("--output", "-o", help="Output HTML file path")

    ca = sub.add_parser("code-audit", help="Code audit report")
    ca.add_argument("file", help="Code audit markdown file")
    ca.add_argument("--output", "-o", help="Output HTML file path")

    sr = sub.add_parser("strategy-review", help="Strategy review report")
    sr.add_argument("file", help="Strategy review markdown file")
    sr.add_argument("--output", "-o", help="Output HTML file path")

    qg = sub.add_parser("quality-gate", help="Quality gate summary report")
    qg.add_argument("file", help="Quality gate summary markdown file")
    qg.add_argument("--output", "-o", help="Output HTML file path")

    lit = sub.add_parser("literature", help="Filterable annotated bibliography")
    lit.add_argument("file", help="Annotated bibliography markdown file")
    lit.add_argument("--output", "-o", help="Output HTML file path")

    args = parser.parse_args()
    if args.command == "peer-review":
        cmd_peer_review(args)
    elif args.command == "code-audit":
        cmd_code_audit(args)
    elif args.command == "strategy-review":
        cmd_strategy_review(args)
    elif args.command == "quality-gate":
        cmd_quality_gate(args)
    elif args.command == "literature":
        cmd_literature(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
