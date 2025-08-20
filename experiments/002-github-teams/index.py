"""GitHub Teams management with Pulumi."""

import pulumi
import pulumi_github as github

config = pulumi.Config()
org_name = config.get("orgName") or "aygp-dr"

engineering_team = github.Team("engineering",
    name="engineering",
    description="Engineering team",
    privacy="closed",
    create_default_maintainer=False,
)

ops_team = github.Team("operations",
    name="operations",
    description="Operations team",
    privacy="closed",
    parent_team_id=engineering_team.id,
)

dev_team = github.Team("developers",
    name="developers",
    description="Development team",
    privacy="closed",
    parent_team_id=engineering_team.id,
)

team_repo = github.Repository("team-resources",
    name="team-resources",
    description="Shared team resources",
    visibility="private",
    has_issues=True,
    auto_init=True,
)

engineering_repo_access = github.TeamRepository("engineering-repo",
    team_id=engineering_team.id,
    repository=team_repo.name,
    permission="admin",
)

dev_repo_access = github.TeamRepository("dev-repo",
    team_id=dev_team.id,
    repository=team_repo.name,
    permission="push",
)

pulumi.export("engineering_team_id", engineering_team.id)
pulumi.export("ops_team_id", ops_team.id)
pulumi.export("dev_team_id", dev_team.id)
pulumi.export("team_repo_url", team_repo.html_url)