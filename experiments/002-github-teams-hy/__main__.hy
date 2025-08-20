;; GitHub Teams management with Pulumi in Hy

(import pulumi)
(import pulumi-github :as github)

(setv config (pulumi.Config))
(setv org-name (or (.get config "orgName") "aygp-dr"))

;; Create engineering team
(setv engineering-team
  (github.Team "engineering"
    :name "engineering"
    :description "Engineering team"
    :privacy "closed"
    :create-default-maintainer False))

;; Create operations team as child of engineering
(setv ops-team
  (github.Team "operations"
    :name "operations"
    :description "Operations team"
    :privacy "closed"
    :parent-team-id (. engineering-team id)))

;; Create developers team as child of engineering
(setv dev-team
  (github.Team "developers"
    :name "developers"
    :description "Development team"
    :privacy "closed"
    :parent-team-id (. engineering-team id)))

;; Create shared repository
(setv team-repo
  (github.Repository "team-resources"
    :name "team-resources"
    :description "Shared team resources"
    :visibility "private"
    :has-issues True
    :auto-init True))

;; Grant engineering team admin access
(setv engineering-repo-access
  (github.TeamRepository "engineering-repo"
    :team-id (. engineering-team id)
    :repository (. team-repo name)
    :permission "admin"))

;; Grant dev team push access
(setv dev-repo-access
  (github.TeamRepository "dev-repo"
    :team-id (. dev-team id)
    :repository (. team-repo name)
    :permission "push"))

;; Export team and repository information
(pulumi.export "engineering_team_id" (. engineering-team id))
(pulumi.export "ops_team_id" (. ops-team id))
(pulumi.export "dev_team_id" (. dev-team id))
(pulumi.export "team_repo_url" (. team-repo html-url))