;; GitHub Provider with Repository and Teams
;; Based on [0:20-0:30] GitHub Provider Deep Dive pattern

(import pulumi)
(import pulumi_github :as github)
(import os)
(import random)
(import string)
(import sys)
(import importlib.util)

;; Check for GitHub provider
(defn check-dependencies []
  "Verify required dependencies are installed"
  (try
    (importlib.util.find_spec "pulumi_github")
    (print "✓ pulumi-github provider found")
    (except [ImportError]
      (print "✗ pulumi-github not installed. Run: pip install pulumi-github>=6.0.0")
      (sys.exit 1)))
  
  ;; Check for GitHub token
  (when (not (os.getenv "GITHUB_TOKEN"))
    (print "✗ GITHUB_TOKEN not set. Copy .env.example to .env and add your token")
    (sys.exit 1))
  (print "✓ GITHUB_TOKEN configured"))

;; Run dependency check
(check-dependencies)

;; Generate random suffix for unique naming
(defn random-suffix []
  "Generate a random 6-character suffix"
  (.join "" (random.choices 
             (+ string.ascii-lowercase string.digits) 
             :k 6)))

;; Configuration
(setv config (pulumi.Config))
(setv repo-base-name (config.get "repoBaseName" "pulumi-lab-demo"))
(setv repo-suffix (random-suffix))
(setv repo-name f"{repo-base-name}-{repo-suffix}")

;; Create private repository
(setv demo-repo
  (github.Repository "demo-repo"
    :name repo-name
    :description f"Demo repository created by Pulumi - {repo-suffix}"
    :visibility "private"  ; Always private as per requirements
    :has-issues True
    :has-wiki False
    :has-downloads False
    :auto-init True
    :gitignore-template "Python"
    :license-template "mit"))

;; Create teams for the repository
(setv engineering-team
  (github.Team "engineering-team"
    :name f"engineering-{repo-suffix}"
    :description "Engineering team with write access"
    :privacy "closed"))

(setv ops-team
  (github.Team "ops-team"
    :name f"ops-{repo-suffix}"
    :description "Operations team with admin access"
    :privacy "closed"))

;; Add repository permissions for teams
(setv engineering-repo-access
  (github.TeamRepository "engineering-repo-access"
    :team-id engineering-team.id
    :repository demo-repo.name
    :permission "push"))

(setv ops-repo-access
  (github.TeamRepository "ops-repo-access"
    :team-id ops-team.id
    :repository demo-repo.name
    :permission "admin"))

;; Add branch protection
(setv main-protection
  (github.BranchProtection "main-protection"
    :repository-id demo-repo.name
    :pattern "main"
    :enforce-admins True
    :allows-deletions False
    :required-status-checks [{
      "strict" True
      "contexts" ["continuous-integration"]}]))

;; Export outputs
(pulumi.export "repository-name" demo-repo.name)
(pulumi.export "repository-url" demo-repo.html-url)
(pulumi.export "repository-ssh-url" demo-repo.ssh-clone-url)
(pulumi.export "repository-visibility" demo-repo.visibility)
(pulumi.export "engineering-team-id" engineering-team.id)
(pulumi.export "ops-team-id" ops-team.id)
(pulumi.export "random-suffix" repo-suffix)