import re
import os

def on_page_markdown(markdown, page, config, files):
    """
    Hook to fix links in README.md when it's used as the homepage (index.md).
    
    1. Rewrites relative links starting with `docs/` to remove the prefix, 
       so they work within the generated site structure where `docs/` is root.
    2. Rewrites image sources pointing to `dev/images/` to use absolute GitHub raw URLs,
       since these assets aren't included in the site build.
    """
    
    # Only apply to the homepage (which includes README.md)
    if page.file.src_path != 'index.md':
        return markdown

    # Pattern 1: Fix relative file links (e.g. [Link](docs/user/file.md) -> [Link](user/file.md))
    # This regex looks for markdown links where the URL starts with docs/
    markdown = re.sub(
        r'\[([^\]]+)\]\(docs/([^)]+)\)',
        r'[\1](\2)',
        markdown
    )

    # Pattern 2: Fix image links to dev/images/ (e.g. src="dev/images/..." -> src="https://raw.github...")
    # This handles both markdown ![]() syntax and HTML <img> tags if used
    base_url = config['repo_url'].rstrip('/') + '/blob/main'
    raw_url = "https://raw.githubusercontent.com/keithrbennett/cov-loupe/main"
    
    # Fix HTML img tags commonly used for resizing
    markdown = re.sub(
        r'src="dev/images/([^"]+)"',
        f'src="{raw_url}/dev/images/\\1"',
        markdown
    )
    
    return markdown
