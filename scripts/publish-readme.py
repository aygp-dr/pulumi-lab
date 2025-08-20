#!/usr/bin/env python3
"""
Publish README.org files to README.md using Emacs (simplified one-liner approach)
Uses uv for Python environment management
"""

import subprocess
import sys
from pathlib import Path


def publish_readme_oneliner(org_file: Path) -> bool:
    """Publish README.org to README.md using Emacs one-liner."""
    try:
        # Simple one-liner: emacs -Q --batch -l org README.org -f org-md-export-to-markdown
        cmd = [
            "emacs", "-Q", "--batch", "-l", "org", 
            str(org_file), "-f", "org-md-export-to-markdown"
        ]
        
        result = subprocess.run(
            cmd,
            cwd=org_file.parent,
            capture_output=True,
            text=True,
            check=True
        )
        
        print(f"✅ Published {org_file.name} -> README.md")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to publish {org_file}: {e}")
        return False


def main():
    """Main function to publish README files."""
    print("📚 Pulumi Lab README Publisher (One-liner)")
    print("=" * 45)
    
    # Find project root
    project_root = Path(__file__).parent.parent
    
    # Find README.org files
    readme_files = list(project_root.glob("**/README.org"))
    
    if not readme_files:
        print("ℹ️  No README.org files found")
        return
    
    print(f"📋 Found {len(readme_files)} README.org files")
    
    # Publish each file
    success_count = 0
    for readme_file in readme_files:
        rel_path = readme_file.relative_to(project_root)
        print(f"🚀 Publishing {rel_path}...")
        if publish_readme_oneliner(readme_file):
            success_count += 1
    
    # Summary
    print(f"\n📊 Published {success_count}/{len(readme_files)} files")
    
    if success_count == len(readme_files):
        print("🎉 All README files published successfully!")
    else:
        print("⚠️  Some files failed to publish")
        sys.exit(1)


if __name__ == "__main__":
    main()