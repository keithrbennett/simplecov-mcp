import re
import os

def on_page_markdown(markdown, page, config, files):
    """
    Hook to fix links in README.md when it's used as the homepage (index.md).

    1. Rewrites relative links starting with `docs/` to remove the prefix,
       so they work within the generated site structure where `docs/` is root.
    2. Rewrites full GitHub blob URLs to doc site URLs (e.g.
       https://github.com/keithrbennett/cov-loupe/blob/main/docs/user/CLI_USAGE.md
       -> https://keithrbennett.github.io/cov-loupe/user/CLI_USAGE/)
    3. Rewrites image sources pointing to `dev/images/` to use absolute GitHub raw URLs,
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

    # Pattern 1b: Convert GitHub blob URLs to doc site URLs
    # Matches: https://github.com/keithrbennett/cov-loupe/blob/main/docs/...
    # or: https://github.com/keithrbennett/cov-loupe/blob/main/QUICKSTART.md
    # Exception: README.md files stay as GitHub links (not in mkdocs nav)
    site_url = config['site_url'].rstrip('/')

    # Convert docs/ links with optional anchors (but skip README.md files)
    def convert_docs_link(match):
        path = match.group(1)
        # Don't convert README.md links - they're not in the mkdocs nav
        if path.endswith('README') or 'README.md' in path:
            return match.group(0)
        anchor = match.group(3) if match.group(3) else ''
        closing = match.group(4)
        return f"{site_url}/{path}/{anchor}{closing}"

    markdown = re.sub(
        r'https://github\.com/keithrbennett/cov-loupe/blob/main/docs/([^)\s]+?)(\.md)?(\#[^)\s]+)?(\))',
        convert_docs_link,
        markdown
    )

    # Convert root-level doc links (like QUICKSTART.md)
    markdown = re.sub(
        r'https://github\.com/keithrbennett/cov-loupe/blob/main/([A-Z][A-Z_]+\.md)(\#[^)\s]+)?(\))',
        lambda m: f"{site_url}/{m.group(1).replace('.md', '')}/{m.group(2) if m.group(2) else ''}{m.group(3)}",
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
