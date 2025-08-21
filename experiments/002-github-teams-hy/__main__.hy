;; GitHub Provider Deep Dive - Comprehensive Resource Demo
;; Maps common gh CLI operations to Pulumi resources

(import pulumi)
(import pulumi_github :as github)
(import random)
(import string)

;; Helper for unique naming
(defn random-suffix []
  (.join "" (random.choices 
             (+ string.ascii-lowercase string.digits) 
             :k 4)))

(setv suffix (random-suffix))
(setv config (pulumi.Config))

;; ========================================
;; 1. REPOSITORY MANAGEMENT
;; ========================================

;; Main repository (gh repo create equivalent)
(setv main-repo
  (github.Repository "main-repo"
    :name f"pulumi-demo-{suffix}"
    :description "Comprehensive GitHub provider demo"
    :visibility "private"
    :has-issues True
    :has-projects True
    :has-wiki False
    :auto-init True
    :gitignore-template "Python"
    :license-template "mit"))

;; Add README file (gh repo edit)
(setv readme-file
  (github.RepositoryFile "readme"
    :repository main-repo.name
    :file "README.md"
    :content "# Pulumi Demo Repository

This repository demonstrates GitHub provider capabilities.

## Features
- Team-based access control
- Branch protection
- Actions secrets
- Issue tracking
- Automated workflows"
    :commit-message "Add comprehensive README"
    :commit-author "Pulumi Bot"
    :commit-email "bot@pulumi.io"))

;; ========================================
;; 2. TEAM & ORGANIZATION
;; ========================================

;; Create teams (gh team create equivalent)
(setv dev-team
  (github.Team "dev-team"
    :name f"dev-{suffix}"
    :description "Development team"
    :privacy "closed"))

(setv ops-team
  (github.Team "ops-team"
    :name f"ops-{suffix}"
    :description "Operations team"
    :privacy "closed"
    :parent-team-id dev-team.id))

(setv security-team
  (github.Team "security-team"
    :name f"security-{suffix}"
    :description "Security team"
    :privacy "secret"))

;; Grant team access to repository
(setv dev-team-access
  (github.TeamRepository "dev-team-repo"
    :team-id dev-team.id
    :repository main-repo.name
    :permission "push"))

(setv ops-team-access
  (github.TeamRepository "ops-team-repo"
    :team-id ops-team.id
    :repository main-repo.name
    :permission "maintain"))

(setv security-team-access
  (github.TeamRepository "security-team-repo"
    :team-id security-team.id
    :repository main-repo.name
    :permission "admin"))

;; ========================================
;; 3. BRANCH PROTECTION
;; ========================================

(setv main-branch-protection
  (github.BranchProtection "main-protection"
    :repository-id main-repo.name
    :pattern "main"
    :enforce-admins False
    :require-signed-commits True
    :required-status-checks [{
      "strict" True
      "contexts" ["continuous-integration/github-actions"]}]
    :required-pull-request-reviews [{
      "required-approving-review-count" 1
      "dismiss-stale-reviews" True
      "require-code-owner-reviews" True}]
    :restrictions [{
      "teams" [ops-team.slug security-team.slug]}]))

;; ========================================
;; 4. ISSUES & LABELS
;; ========================================

;; Create issue labels (gh label create)
(setv bug-label
  (github.IssueLabel "bug-label"
    :repository main-repo.name
    :name "bug"
    :color "d73a4a"
    :description "Something isn't working"))

(setv enhancement-label
  (github.IssueLabel "enhancement-label"
    :repository main-repo.name
    :name "enhancement"
    :color "a2eeef"
    :description "New feature or request"))

(setv security-label
  (github.IssueLabel "security-label"
    :repository main-repo.name
    :name "security"
    :color "ff0000"
    :description "Security vulnerability"))

;; Create milestone
(setv v1-milestone
  (github.RepositoryMilestone "v1-milestone"
    :repository main-repo.name
    :title "v1.0.0"
    :description "First major release"
    :state "open"))

;; Create initial issue (gh issue create)
(setv welcome-issue
  (github.Issue "welcome-issue"
    :repository main-repo.name
    :title "Welcome to the repository!"
    :body "This issue tracks the initial setup of our repository.

## Tasks
- [x] Repository created
- [x] Teams configured
- [x] Branch protection enabled
- [ ] CI/CD pipeline
- [ ] Documentation"
    :labels [enhancement-label.name]
    :milestone v1-milestone.number))

;; ========================================
;; 5. ACTIONS SECRETS & VARIABLES
;; ========================================

;; Repository secrets (gh secret set)
(setv api-key-secret
  (github.ActionsSecret "api-key"
    :repository main-repo.name
    :secret-name "API_KEY"
    :plaintext-value "demo-api-key-placeholder"))

(setv deploy-token-secret
  (github.ActionsSecret "deploy-token"
    :repository main-repo.name
    :secret-name "DEPLOY_TOKEN"
    :plaintext-value "demo-deploy-token"))

;; Repository variables (gh variable set)
(setv environment-var
  (github.ActionsVariable "environment"
    :repository main-repo.name
    :variable-name "ENVIRONMENT"
    :value "production"))

(setv region-var
  (github.ActionsVariable "region"
    :repository main-repo.name
    :variable-name "AWS_REGION"
    :value "us-west-2"))

;; ========================================
;; 6. WEBHOOKS
;; ========================================

(setv ci-webhook
  (github.RepositoryWebhook "ci-webhook"
    :repository main-repo.name
    :active True
    :events ["push" "pull_request"]
    :configuration {
      "url" "https://example.com/webhook"
      "content_type" "json"
      "insecure_ssl" "0"}))

;; ========================================
;; 7. DEPLOY KEYS
;; ========================================

;; Note: In production, use proper SSH key generation
(setv deploy-key
  (github.RepositoryDeployKey "deploy-key"
    :repository main-repo.name
    :title f"Deploy Key {suffix}"
    :key "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDe... demo@pulumi"
    :read-only True))

;; ========================================
;; 8. DATA RETRIEVAL FUNCTIONS
;; ========================================

;; Get repository data (gh repo view)
(setv repo-data 
  (github.get-repository 
    :name main-repo.name))

;; ========================================
;; EXPORTS
;; ========================================

(pulumi.export "repository" {
  "name" main-repo.name
  "url" main-repo.html-url
  "ssh-url" main-repo.ssh-clone-url
  "default-branch" main-repo.default-branch})

(pulumi.export "teams" {
  "dev" dev-team.slug
  "ops" ops-team.slug
  "security" security-team.slug})

(pulumi.export "issue-labels" [
  bug-label.name
  enhancement-label.name
  security-label.name])

(pulumi.export "milestone" v1-milestone.title)
(pulumi.export "webhook-url" ci-webhook.url)
(pulumi.export "suffix" suffix)