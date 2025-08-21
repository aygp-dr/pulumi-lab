#!/bin/sh
# Test script to verify Pulumi installation on FreeBSD

echo "========================================="
echo "Pulumi on FreeBSD Compatibility Test"
echo "========================================="
echo ""

# Check FreeBSD version
echo "1. System Information:"
echo "   OS: $(uname -s) $(uname -r)"
echo "   Arch: $(uname -m)"
echo ""

# Check Linux compatibility
echo "2. Linux Compatibility Layer:"
if kldstat | grep -q linux; then
    echo "   ✓ Linux kernel modules loaded:"
    kldstat | grep linux | sed 's/^/     /'
else
    echo "   ✗ Linux compatibility not loaded"
    echo "   Run: sudo kldload linux64"
fi
echo ""

# Check Linux base
echo "3. Linux Base System:"
if pkg info | grep -q linux-c7; then
    echo "   ✓ CentOS 7 base packages installed"
    pkg info | grep linux-c7 | head -3 | sed 's/^/     /'
else
    echo "   ✗ Linux base not installed"
    echo "   Run: sudo pkg install linux-c7-base"
fi
echo ""

# Check Pulumi installation
echo "4. Pulumi Installation:"
if [ -f "$HOME/.local/bin/pulumi" ]; then
    echo "   ✓ Pulumi binary found at ~/.local/bin/pulumi"
    if $HOME/.local/bin/pulumi version 2>/dev/null; then
        echo "   ✓ Version: $($HOME/.local/bin/pulumi version)"
    else
        echo "   ✗ Pulumi binary not executable"
    fi
else
    echo "   ✗ Pulumi not installed"
    echo "   Follow FREEBSD_PULUMI_SETUP.md for installation"
fi
echo ""

# Check language plugins
echo "5. Language Plugins:"
for plugin in pulumi-language-python pulumi-language-nodejs pulumi-language-go; do
    if [ -f "$HOME/.local/bin/$plugin" ]; then
        echo "   ✓ $plugin installed"
    else
        echo "   ✗ $plugin not found"
    fi
done
echo ""

# Check Python environment
echo "6. Python Environment:"
if command -v python3 >/dev/null 2>&1; then
    echo "   ✓ Python $(python3 --version | cut -d' ' -f2)"
    if python3 -c "import hy" 2>/dev/null; then
        echo "   ✓ Hy $(python3 -c 'import hy; print(hy.__version__)')"
    else
        echo "   ✗ Hy not installed (pip3 install hy)"
    fi
else
    echo "   ✗ Python3 not installed"
fi
echo ""

# Check Docker/LocalStack
echo "7. Container Support:"
if command -v docker >/dev/null 2>&1; then
    echo "   ✓ Docker installed"
    if docker ps >/dev/null 2>&1; then
        echo "   ✓ Docker daemon running"
    else
        echo "   ✗ Docker daemon not running or no permissions"
    fi
else
    echo "   ✗ Docker not installed"
fi
echo ""

# Summary
echo "========================================="
echo "Summary:"
echo ""

if [ -f "$HOME/.local/bin/pulumi" ] && $HOME/.local/bin/pulumi version >/dev/null 2>&1; then
    echo "✓ Pulumi is installed and working on FreeBSD!"
    echo ""
    echo "Next steps:"
    echo "1. Source your shell config: source ~/.bashrc"
    echo "2. Test with: cd experiments/006-s3-buckets-hy"
    echo "3. Initialize: pulumi stack init test --secrets-provider passphrase"
    echo "4. Preview: pulumi preview"
    echo ""
    echo "For interactive session: ./scripts/pulumi-tmux.sh"
else
    echo "✗ Pulumi setup incomplete"
    echo ""
    echo "To install:"
    echo "1. Ensure Linux compatibility is loaded"
    echo "2. Follow FREEBSD_PULUMI_SETUP.md"
    echo "3. Run this test again"
fi
echo "========================================="