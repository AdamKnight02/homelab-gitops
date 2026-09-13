#!/usr/bin/env python3
"""Convert PKI Homelab Master Guide Markdown to PDF"""

import markdown
from weasyprint import HTML, CSS
from weasyprint.text.fonts import FontConfiguration

# Read the markdown file
with open('PKI-HOMELAB-MASTER-GUIDE.md', 'r') as f:
    md_content = f.read()

# Convert markdown to HTML
md = markdown.Markdown(extensions=['tables', 'fenced_code', 'toc'])
html_body = md.convert(md_content)

# Create full HTML document with styling
html_content = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>PKI Homelab Master Guide</title>
    <style>
        @page {{
            size: letter;
            margin: 2.5cm;
            @bottom-center {{
                content: counter(page);
                font-size: 9pt;
                color: #666;
            }}
            @top-left {{
                content: "PKI Homelab Master Guide";
                font-size: 8pt;
                color: #999;
                font-style: italic;
            }}
        }}
        
        body {{
            font-family: 'DejaVu Sans', 'Liberation Sans', Arial, sans-serif;
            font-size: 10pt;
            line-height: 1.6;
            color: #333;
        }}
        
        h1 {{
            font-size: 24pt;
            color: #1a5276;
            border-bottom: 3px solid #1a5276;
            padding-bottom: 10px;
            margin-top: 30px;
            page-break-before: always;
        }}
        
        h1:first-of-type {{
            page-break-before: avoid;
        }}
        
        h2 {{
            font-size: 16pt;
            color: #2874a6;
            border-bottom: 2px solid #2874a6;
            padding-bottom: 5px;
            margin-top: 25px;
        }}
        
        h3 {{
            font-size: 13pt;
            color: #2e86c1;
            margin-top: 20px;
        }}
        
        h4 {{
            font-size: 11pt;
            color: #5499c7;
            margin-top: 15px;
        }}
        
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 15px 0;
            font-size: 9pt;
        }}
        
        th {{
            background-color: #1a5276;
            color: white;
            padding: 8px;
            text-align: left;
            font-weight: bold;
            border: 1px solid #1a5276;
        }}
        
        td {{
            padding: 6px 8px;
            border: 1px solid #ddd;
        }}
        
        tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        
        tr:hover {{
            background-color: #e8f4f8;
        }}
        
        code {{
            font-family: 'DejaVu Sans Mono', 'Liberation Mono', monospace;
            background-color: #f4f4f4;
            padding: 2px 4px;
            border-radius: 3px;
            font-size: 9pt;
            color: #c7254e;
        }}
        
        pre {{
            background-color: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 4px;
            padding: 12px;
            overflow-x: auto;
            font-size: 8pt;
            line-height: 1.4;
            margin: 15px 0;
        }}
        
        pre code {{
            background-color: transparent;
            padding: 0;
            color: #333;
        }}
        
        blockquote {{
            border-left: 4px solid #1a5276;
            margin: 15px 0;
            padding: 10px 20px;
            background-color: #f8f9fa;
            font-style: italic;
        }}
        
        ul, ol {{
            margin: 10px 0;
            padding-left: 25px;
        }}
        
        li {{
            margin: 5px 0;
        }}
        
        .title-page {{
            text-align: center;
            padding-top: 200px;
        }}
        
        .title-page h1 {{
            font-size: 32pt;
            border: none;
            color: #1a5276;
        }}
        
        .title-page .subtitle {{
            font-size: 16pt;
            color: #666;
            margin-top: 20px;
        }}
        
        .title-page .meta {{
            font-size: 12pt;
            color: #999;
            margin-top: 50px;
        }}
        
        .toc {{
            page-break-after: always;
        }}
        
        .toc h2 {{
            border-bottom: 2px solid #1a5276;
        }}
        
        .toc ul {{
            list-style: none;
            padding-left: 0;
        }}
        
        .toc li {{
            margin: 8px 0;
            padding-left: 20px;
        }}
        
        .toc a {{
            color: #1a5276;
            text-decoration: none;
        }}
        
        .toc a:hover {{
            text-decoration: underline;
        }}
        
        strong {{
            color: #1a5276;
        }}
        
        hr {{
            border: none;
            border-top: 2px solid #1a5276;
            margin: 30px 0;
        }}
        
        /* Status indicators */
        .status-running {{
            color: #27ae60;
            font-weight: bold;
        }}
        
        .status-partial {{
            color: #f39c12;
            font-weight: bold;
        }}
        
        .status-planned {{
            color: #e74c3c;
            font-weight: bold;
        }}
    </style>
</head>
<body>
    {html_body}
</body>
</html>'''

# Write HTML file
with open('/tmp/pki_guide.html', 'w') as f:
    f.write(html_content)

# Convert to PDF
print("Converting to PDF...")
font_config = FontConfiguration()
HTML('/tmp/pki_guide.html').write_pdf(
    '/home/frostnode/Desktop/PKI-HOMELAB-MASTER-GUIDE.pdf',
    font_config=font_config
)

print("PDF generated successfully!")
print("Location: /home/frostnode/Desktop/PKI-HOMELAB-MASTER-GUIDE.pdf")
