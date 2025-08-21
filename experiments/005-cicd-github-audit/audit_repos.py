#!/usr/bin/env python3
"""
GitHub Repository Audit Script
Audits repositories for missing topics, excessive topics, and missing descriptions.
"""

import os
import sys
import json
import csv
import argparse
from datetime import datetime
from typing import List, Dict, Any, Optional
import requests
from dataclasses import dataclass, asdict


@dataclass
class RepoIssue:
    """Represents an issue found in a repository."""
    repo_name: str
    issue_type: str
    details: str
    visibility: str
    last_updated: str


class GitHubAuditor:
    """Audits GitHub repositories for common issues."""
    
    def __init__(self, token: str):
        self.token = token
        self.headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        self.issues: List[RepoIssue] = []
        self.repos_processed = 0
    
    def get_user_repos(self, username: str) -> List[Dict[str, Any]]:
        """Get all repositories for a user."""
        repos = []
        page = 1
        
        while True:
            response = requests.get(
                f'https://api.github.com/users/{username}/repos',
                headers=self.headers,
                params={'page': page, 'per_page': 100}
            )
            response.raise_for_status()
            
            page_repos = response.json()
            if not page_repos:
                break
            
            repos.extend(page_repos)
            page += 1
        
        return repos
    
    def get_org_repos(self, org: str) -> List[Dict[str, Any]]:
        """Get all repositories for an organization."""
        repos = []
        page = 1
        
        while True:
            response = requests.get(
                f'https://api.github.com/orgs/{org}/repos',
                headers=self.headers,
                params={'page': page, 'per_page': 100}
            )
            response.raise_for_status()
            
            page_repos = response.json()
            if not page_repos:
                break
            
            repos.extend(page_repos)
            page += 1
        
        return repos
    
    def audit_repository(self, repo: Dict[str, Any]) -> None:
        """Audit a single repository for issues."""
        repo_name = repo['full_name']
        visibility = 'private' if repo['private'] else 'public'
        last_updated = repo['updated_at']
        
        # Check for missing description
        if not repo.get('description'):
            self.issues.append(RepoIssue(
                repo_name=repo_name,
                issue_type='no_description',
                details='Repository has no description',
                visibility=visibility,
                last_updated=last_updated
            ))
        
        # Check for topics
        topics = repo.get('topics', [])
        if len(topics) == 0:
            self.issues.append(RepoIssue(
                repo_name=repo_name,
                issue_type='no_topics',
                details='Repository has no topics',
                visibility=visibility,
                last_updated=last_updated
            ))
        elif len(topics) > 5:
            self.issues.append(RepoIssue(
                repo_name=repo_name,
                issue_type='too_many_topics',
                details=f'Repository has {len(topics)} topics (recommended max: 5)',
                visibility=visibility,
                last_updated=last_updated
            ))
        
        self.repos_processed += 1
    
    def run_audit(self, target: str, target_type: str = 'user') -> Dict[str, Any]:
        """Run the audit on all repositories."""
        print(f"Starting audit for {target_type}: {target}")
        
        # Get repositories
        if target_type == 'user':
            repos = self.get_user_repos(target)
        else:
            repos = self.get_org_repos(target)
        
        print(f"Found {len(repos)} repositories to audit")
        
        # Audit each repository
        for repo in repos:
            self.audit_repository(repo)
        
        # Prepare summary
        summary = {
            'total_repos': self.repos_processed,
            'repos_with_issues': len(set(issue.repo_name for issue in self.issues)),
            'total_issues': len(self.issues),
            'no_topics': len([i for i in self.issues if i.issue_type == 'no_topics']),
            'too_many_topics': len([i for i in self.issues if i.issue_type == 'too_many_topics']),
            'no_description': len([i for i in self.issues if i.issue_type == 'no_description'])
        }
        
        return {
            'target': target,
            'target_type': target_type,
            'audit_date': datetime.now().isoformat(),
            'summary': summary,
            'issues': [asdict(issue) for issue in self.issues]
        }


def format_json(audit_result: Dict[str, Any]) -> str:
    """Format audit results as JSON."""
    return json.dumps(audit_result, indent=2)


def format_markdown(audit_result: Dict[str, Any]) -> str:
    """Format audit results as Markdown."""
    lines = []
    summary = audit_result['summary']
    
    lines.append(f"# Repository Audit Report")
    lines.append(f"\n**Target:** {audit_result['target']} ({audit_result['target_type']})")
    lines.append(f"**Date:** {audit_result['audit_date']}")
    lines.append(f"\n## Summary")
    lines.append(f"- Total repositories: {summary['total_repos']}")
    lines.append(f"- Repositories with issues: {summary['repos_with_issues']}")
    lines.append(f"- Total issues found: {summary['total_issues']}")
    
    if summary['total_issues'] > 0:
        lines.append(f"\n### Issues by Type")
        lines.append(f"- No topics: {summary['no_topics']}")
        lines.append(f"- Too many topics: {summary['too_many_topics']}")
        lines.append(f"- No description: {summary['no_description']}")
        
        lines.append(f"\n## Detailed Issues")
        lines.append("\n| Repository | Issue Type | Details | Visibility |")
        lines.append("|------------|------------|---------|------------|")
        
        for issue in audit_result['issues']:
            lines.append(
                f"| {issue['repo_name']} | {issue['issue_type'].replace('_', ' ').title()} | "
                f"{issue['details']} | {issue['visibility']} |"
            )
    else:
        lines.append(f"\n✅ **No issues found!** All repositories are properly configured.")
    
    return '\n'.join(lines)


def format_csv(audit_result: Dict[str, Any]) -> str:
    """Format audit results as CSV."""
    output = []
    writer = csv.DictWriter(
        output,
        fieldnames=['repo_name', 'issue_type', 'details', 'visibility', 'last_updated'],
        lineterminator='\n'
    )
    
    writer.writeheader()
    for issue in audit_result['issues']:
        writer.writerow(issue)
    
    return ''.join(output)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Audit GitHub repositories')
    
    # Target specification
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--user', help='Audit user repositories')
    group.add_argument('--org', help='Audit organization repositories')
    
    # Output format
    parser.add_argument(
        '--format',
        choices=['json', 'markdown', 'csv'],
        default='markdown',
        help='Output format (default: markdown)'
    )
    
    args = parser.parse_args()
    
    # Get GitHub token
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print("Error: GITHUB_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)
    
    # Determine target
    if args.user:
        target = args.user
        target_type = 'user'
    else:
        target = args.org
        target_type = 'org'
    
    # Run audit
    try:
        auditor = GitHubAuditor(token)
        result = auditor.run_audit(target, target_type)
        
        # Format and output results
        if args.format == 'json':
            print(format_json(result))
        elif args.format == 'csv':
            print(format_csv(result))
        else:
            print(format_markdown(result))
        
        # Exit with error code if issues found
        if result['summary']['repos_with_issues'] > 0:
            sys.exit(1)
        
    except requests.exceptions.RequestException as e:
        print(f"Error accessing GitHub API: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == '__main__':
    main()