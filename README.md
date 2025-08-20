# Pulumi Lab

Exploration of Pulumi Infrastructure as Code with focus on GitHub provider and FreeBSD environment.

## Quick Start

```bash
# Install Pulumi
curl -fsSL https://get.pulumi.com | sh

# Choose a stack
cd experiments/001-github-provider
pulumi up
```

## Structure

```
pulumi-lab/
├── experiments/          # Numbered experiments
│   ├── 001-github-provider/
│   ├── 002-github-teams/
│   ├── 003-github-actions/
│   └── ...
├── notes/               # Documentation and learnings
└── scripts/             # Utility scripts
```

## Current Focus Areas

1. GitHub Provider - Repository management, teams, actions
2. Multi-language support (TypeScript, Python, Go)
3. State management patterns
4. CI/CD integration
5. FreeBSD compatibility

## Resources

- [Pulumi GitHub Provider](https://www.pulumi.com/registry/packages/github/)
- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [Pulumi Examples](https://github.com/pulumi/examples)