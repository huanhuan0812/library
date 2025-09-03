import os
import markdown2
from pathlib import Path
from datetime import datetime

class MarkdownConverter:
    def __init__(self, template_path=None):
        self.template_path = template_path
        self.default_template = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        {css}
    </style>
</head>
<body>
    <div class="container">
        {content}
        <footer>
            <p>生成于: {timestamp}</p>
        </footer>
    </div>
</body>
</html>"""
        
        self.default_css = """
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
        pre { background: #f8f8f8; padding: 15px; border-radius: 5px; overflow: auto; }
        pre code { background: transparent; padding: 0; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        table, th, td { border: 1px solid #ddd; }
        th, td { padding: 10px; text-align: left; }
        th { background: #f0f0f0; }
        footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 0.9em; }
        """
    
    def load_template(self):
        if self.template_path and os.path.exists(self.template_path):
            with open(self.template_path, 'r', encoding='utf-8') as f:
                return f.read()
        return self.default_template
    
    def convert_file(self, input_path, output_path, extensions=None):
        if extensions is None:
            extensions = ['fenced-code-blocks', 'tables', 'toc', 'metadata']
        
        try:
            with open(input_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            html = markdown2.markdown(content, extras=extensions)
            template = self.load_template()
            
            final_html = template.format(
                title=Path(input_path).stem,
                css=self.default_css,
                content=html,
                timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            )
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(final_html)
            
            return True
            
        except Exception as e:
            print(f"Error converting {input_path}: {e}")
            return False

def batch_convert(input_dir, output_dir, extensions=None):
    converter = MarkdownConverter()
    
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith('.md'):
                input_path = os.path.join(root, file)
                rel_path = os.path.relpath(root, input_dir)
                output_subdir = os.path.join(output_dir, rel_path)
                
                Path(output_subdir).mkdir(parents=True, exist_ok=True)
                
                output_file = Path(file).stem + '.html'
                output_path = os.path.join(output_subdir, output_file)
                
                if converter.convert_file(input_path, output_path, extensions):
                    print(f"✓ {input_path} -> {output_path}")
                else:
                    print(f"✗ Failed: {input_path}")

if __name__ == "__main__":
    batch_convert("docs", "html_output")