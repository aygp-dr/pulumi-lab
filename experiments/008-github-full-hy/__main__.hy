;; Complete GitHub setup in Hy
(import pulumi)
(import [pulumi-github :as github])

;; Configuration
(setv config (pulumi.Config))
(setv repo-prefix (config.get "repoPrefix"))

;; Create repository
(setv lab-repo
  (github.Repository "lab-repo"
    :name f"{repo-prefix}-workshop"
    :description "Created during Pulumi workshop"
    :visibility "private"
    :has-issues True
    :auto-init True
    :gitignore-template "Python"
    :license-template "mit"))

;; Create webhook
(setv webhook
  (github.RepositoryWebhook "webhook"
    :repository (. lab-repo name)
    :configuration {:url "https://example.com/hook"
                    :content-type "json"
                    :insecure-ssl False}
    :active True
    :events ["push" "pull_request"]))

;; Branch protection
(setv protection
  (github.BranchProtection "main-protection"
    :repository-id (. lab-repo node-id)
    :pattern "main"
    :enforce-admins True
    :required-status-checks [{:strict True
                             :contexts ["ci/build"]}]))

;; Outputs
(pulumi.export "repo_url" (. lab-repo html-url))
(pulumi.export "repo_ssh" (. lab-repo ssh-clone-url))
