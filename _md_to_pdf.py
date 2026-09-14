"""Convert STRATUM_MVO_Roadmap.md to a well-formatted PDF via headless Chromium."""
import asyncio
import re
import sys
from pathlib import Path

SRC = Path(r"C:\Users\Rakesh\Downloads\Junaid\Dropper\STRATUM-Desktop\qgroundcontrol\docs\STRATUM_MVO_Roadmap.md")
DST = Path(r"C:\Users\Rakesh\Downloads\Junaid\Dropper\STRATUM-Desktop\qgroundcontrol\docs\STRATUM_MVO_Roadmap.pdf")
TMP_HTML = Path(r"C:\Users\Rakesh\Downloads\Junaid\Dropper\STRATUM-Desktop\_roadmap_tmp.html")

CSS = r"""
@page {
  size: A4;
  margin: 20mm 18mm 22mm 18mm;
}
* { box-sizing: border-box; }
html, body {
  font-family: "Segoe UI", "Calibri", "Helvetica Neue", Arial, sans-serif;
  font-size: 10.5pt;
  line-height: 1.5;
  color: #1a1a1a;
  margin: 0;
  padding: 0;
}
h1 {
  font-size: 22pt;
  font-weight: 600;
  margin: 0 0 12pt 0;
  color: #0b3d66;
  border-bottom: 2pt solid #0b3d66;
  padding-bottom: 6pt;
  page-break-after: avoid;
  page-break-inside: avoid;
}
h1:not(:first-of-type) {
  margin-top: 22pt;
  padding-top: 8pt;
}
h2 {
  font-size: 15pt;
  font-weight: 600;
  margin: 18pt 0 8pt 0;
  color: #0b3d66;
  page-break-after: avoid;
  page-break-inside: avoid;
}
h3 {
  font-size: 12pt;
  font-weight: 600;
  margin: 14pt 0 6pt 0;
  color: #1a1a1a;
  page-break-after: avoid;
  page-break-inside: avoid;
}
h4 {
  font-size: 11pt;
  font-weight: 600;
  margin: 10pt 0 4pt 0;
  color: #333;
  page-break-after: avoid;
}
p {
  margin: 5pt 0;
  orphans: 3;
  widows: 3;
}
ul, ol {
  margin: 5pt 0;
  padding-left: 22pt;
}
li {
  margin: 3pt 0;
  page-break-inside: avoid;
}
strong { color: #0b3d66; font-weight: 600; }
em { color: #333; font-style: italic; }

/* Inline code. */
code {
  font-family: "Consolas", "Courier New", monospace;
  font-size: 9.5pt;
  background: #f2f4f7;
  padding: 0.5pt 3pt;
  border-radius: 2pt;
  color: #a03050;
  word-break: break-word;
  overflow-wrap: anywhere;
  box-decoration-break: clone;
  -webkit-box-decoration-break: clone;
}
h1 code, h2 code, h3 code, h4 code, th code {
  background: transparent;
  color: inherit;
  padding: 0;
}

pre {
  background: #f6f8fa;
  border: 1pt solid #d0d7de;
  border-radius: 4pt;
  padding: 8pt 10pt;
  font-family: "Consolas", "Courier New", monospace;
  font-size: 9pt;
  line-height: 1.4;
  white-space: pre-wrap;
  word-break: break-word;
  overflow-wrap: anywhere;
  page-break-inside: avoid;
  margin: 8pt 0;
}
pre code {
  background: transparent;
  padding: 0;
  color: #1a1a1a;
  border-radius: 0;
  font-size: inherit;
  word-break: normal;
}

blockquote {
  border-left: 3pt solid #0b3d66;
  background: #eef4fa;
  padding: 6pt 10pt;
  margin: 10pt 0;
  color: #333;
  font-style: italic;
  page-break-inside: avoid;
}
blockquote p { margin: 3pt 0; }

table {
  border-collapse: collapse;
  width: 100%;
  margin: 10pt 0;
  font-size: 9.5pt;
  page-break-inside: auto;
}
thead { display: table-header-group; }
tbody { display: table-row-group; }
tr {
  page-break-inside: avoid;
  page-break-after: auto;
}
th {
  background: #0b3d66;
  color: white;
  text-align: left;
  padding: 6pt 8pt;
  font-weight: 600;
  vertical-align: top;
  word-break: normal;
  overflow-wrap: break-word;
}
td {
  border: 0.75pt solid #d0d7de;
  padding: 5pt 8pt;
  vertical-align: top;
  word-break: normal;
  overflow-wrap: break-word;
}
tbody tr:nth-child(even) td { background: #f6f8fa; }

hr {
  border: none;
  border-top: 1pt solid #d0d7de;
  margin: 16pt 0;
}
a { color: #0b3d66; text-decoration: none; }

.title-block {
  margin: 0 0 8pt 0;
  padding: 0 0 12pt 0;
  border-bottom: 3pt solid #0b3d66;
}
.title-block .doc-title {
  font-size: 24pt;
  font-weight: 700;
  color: #0b3d66;
  margin: 0;
  line-height: 1.2;
}
.title-block .doc-subtitle {
  font-size: 11pt;
  color: #555;
  margin: 6pt 0 0 0;
}
.title-block .doc-meta {
  font-size: 9pt;
  color: #888;
  margin: 4pt 0 0 0;
}
"""


def strip_first_h1(md: str):
    m = re.match(r"^#\s+(.+?)\s*\n", md)
    if not m:
        return "STRATUM MVO — Development Roadmap", md
    return m.group(1), md[m.end():]


async def main() -> int:
    import markdown
    from playwright.async_api import async_playwright

    md_text = SRC.read_text(encoding="utf-8")
    title, body_md = strip_first_h1(md_text)

    html_body = markdown.markdown(
        body_md,
        extensions=["tables", "fenced_code", "sane_lists", "attr_list"],
    )

    html_doc = (
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
        f"<title>{title}</title><style>{CSS}</style></head><body>"
        "<div class=\"title-block\">"
        f"<div class=\"doc-title\">{title}</div>"
        "<div class=\"doc-subtitle\">Multi-Vehicle Orchestration — plan of work</div>"
        "<div class=\"doc-meta\">Derived from NXM-SW-ARCH-STRATUM-MVO-001 v0.2 &middot; "
        "Nexam Systems &middot; Company Proprietary</div>"
        "</div>"
        f"{html_body}</body></html>"
    )

    TMP_HTML.write_text(html_doc, encoding="utf-8")

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        await page.goto(TMP_HTML.as_uri(), wait_until="networkidle")
        await page.pdf(
            path=str(DST),
            format="A4",
            margin={"top": "20mm", "bottom": "22mm", "left": "18mm", "right": "18mm"},
            print_background=True,
            display_header_footer=True,
            header_template="<div></div>",
            footer_template=(
                '<div style="font-family: Segoe UI, sans-serif; font-size: 8pt; '
                'color: #888; width: 100%; text-align: center; padding: 0 18mm;">'
                'STRATUM MVO Roadmap &middot; '
                '<span class="pageNumber"></span> / <span class="totalPages"></span>'
                '</div>'
            ),
        )
        await browser.close()

    TMP_HTML.unlink(missing_ok=True)
    print(f"OK: {DST} ({DST.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
