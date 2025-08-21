#!/usr/bin/env python3
"""
Test Pulumi GitHub provider availability in CI environment.
"""

import os
import sys

try:
    import pulumi
    import pulumi_github as github
    
    print("✓ Pulumi package imported successfully")
    print(f"  Pulumi version: {pulumi.__version__ if hasattr(pulumi, '__version__') else 'unknown'}")
    
    # Test that we can access the GitHub provider
    config = pulumi.Config()
    
    # Verify token is available
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        print("✓ GitHub token is available")
        print(f"  Token length: {len(token)} characters")
    else:
        print("✗ GitHub token not found in environment")
        sys.exit(1)
    
    # Test that we can use the provider functions
    try:
        # This won't actually execute without a Pulumi program context,
        # but we can verify the function exists
        assert hasattr(github, 'get_repository')
        assert hasattr(github, 'get_repositories')
        assert hasattr(github, 'Repository')
        assert hasattr(github, 'Team')
        print("✓ GitHub provider functions are available")
    except AssertionError:
        print("✗ Some GitHub provider functions are missing")
        sys.exit(1)
    
    print("\n=== Pulumi GitHub Provider Test Passed ===")
    print("The CI environment is properly configured for Pulumi operations")
    
except ImportError as e:
    print(f"✗ Failed to import required packages: {e}")
    print("Please ensure pulumi and pulumi-github are installed")
    sys.exit(1)
except Exception as e:
    print(f"✗ Unexpected error: {e}")
    sys.exit(1)