# README Publishing System

This project uses **org-mode** (`.org`) files as the canonical documentation format and automatically generates **Markdown** (`.md`) files for GitHub compatibility.

## 🎯 Key Points

- ✅ **README.org** is the source of truth
- ✅ **README.md** is auto-generated (and git-ignored)
- ✅ Uses **Python 3.11** and **Hy 1.0.0**
- ✅ **EXPERIMENTAL** project status

## 📝 Publishing Methods

### Method 1: Emacs One-liner (Simplest)
```bash
# Single file
emacs -Q --batch -l org README.org -f org-md-export-to-markdown

# All files
find . -name "README.org" -exec emacs -Q --batch -l org {} -f org-md-export-to-markdown \;
```

### Method 2: Shell Script
```bash
./scripts/publish-readme.sh
```

### Method 3: Python with uv
```bash
uv run scripts/publish-readme.py
```

### Method 4: Make Target
```bash
make publish-readme        # Shell script approach
make publish-readme-python # Python script approach
make watch-readme          # Auto-publish on changes (requires fswatch)
```

## 📋 Badge Information

The main README.org includes these badges:

- ![Status](https://img.shields.io/badge/status-experimental-orange.svg) **Experimental**
- ![Python](https://img.shields.io/badge/python-3.11-blue.svg) **Python 3.11.11**
- ![Hy](https://img.shields.io/badge/hy-1.0.0-purple.svg) **Hy 1.0.0**
- ![Pulumi](https://img.shields.io/badge/pulumi-latest-blueviolet.svg) **Pulumi Latest**
- ![Platform](https://img.shields.io/badge/platform-FreeBSD-red.svg) **FreeBSD 14.3**
- ![LocalStack](https://img.shields.io/badge/localstack-supported-green.svg) **LocalStack**

## 🔧 Development Workflow

1. Edit `README.org` files
2. Run `make publish-readme` to generate `README.md`
3. `README.md` files are automatically git-ignored
4. Only commit `.org` files to version control

## 🛠️ Dependencies

- **Emacs**: Required for org-mode export
- **uv**: Python package management
- **fswatch**: Optional, for auto-publishing on file changes

## 🎪 Integration with uv

The project uses uv for Python dependency management:

```bash
# Install dependencies
uv sync

# Run with specific extras
uv sync --extra dev
uv sync --extra automation  
uv sync --extra policy

# Run publishing script
uv run scripts/publish-readme.py
```

This approach ensures that:
- Documentation stays in org-mode format (better for Emacs users)
- GitHub gets proper Markdown rendering
- No manual conversion needed
- Version control stays clean (no generated files)