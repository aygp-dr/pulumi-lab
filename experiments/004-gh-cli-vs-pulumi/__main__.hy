;; GitHub Organization Management with Pulumi
;; Equivalent to bash scripts using gh CLI

(import pulumi)
(import pulumi_github :as github)
(import requests)
(import os)
(import sys)
(import json)
(import git)
(import concurrent.futures [ThreadPoolExecutor as-completed])
(import argparse)
(import pathlib [Path])

;; ========================================
;; 1. INVITATION MANAGEMENT
;; ========================================

(defclass InvitationManager []
  "Manage GitHub repository invitations"
  
  (defn __init__ [self token]
    (setv self.token token)
    (setv self.headers {
      "Authorization" f"token {token}"
      "Accept" "application/vnd.github.v3+json"}))
  
  (defn list-pending-invitations [self]
    "List all pending repository invitations"
    (setv response (requests.get
      "https://api.github.com/user/repository_invitations"
      :headers self.headers))
    (.raise-for-status response)
    (.json response))
  
  (defn accept-invitation [self invitation-id]
    "Accept a single invitation via API"
    (setv response (requests.patch
      f"https://api.github.com/user/repository_invitations/{invitation-id}"
      :headers self.headers))
    (.raise-for-status response)
    (print f"✓ Accepted invitation {invitation-id}")))

(defn accept-all-invitations []
  "Accept all pending invitations using Pulumi resources"
  (setv token (os.getenv "GITHUB_TOKEN"))
  (when (not token)
    (print "✗ GITHUB_TOKEN not set")
    (sys.exit 1))
  
  (setv manager (InvitationManager token))
  (setv invitations (.list-pending-invitations manager))
  
  (if invitations
    (do
      (print f"Found {(len invitations)} pending invitation(s)")
      (for [invite invitations]
        ;; Create Pulumi resource for each invitation
        (github.UserInvitationAccepter
          f"accept-{(get invite \"id\")}"
          :invitation-id (str (get invite "id")))
        (print f"✓ Accepting invitation from {(get invite \"repository\" \"full_name\")}")))
    (print "No pending invitations")))

;; ========================================
;; 2. REPOSITORY FETCHING
;; ========================================

(defclass RepositoryFetcher []
  "Fetch and clone repositories"
  
  (defn __init__ [self [base-path "./repos"]]
    (setv self.base-path (Path base-path))
    (.mkdir self.base-path :parents True :exist-ok True))
  
  (defn get-all-repositories [self]
    "Get all repositories accessible to the authenticated user"
    ;; Using Pulumi's data source
    (try
      (setv repos (github.get-repositories
        :query "user:@me"
        :include-repo-id True))
      (return repos.full-names)
      (except [Exception e]
        (print f"Error fetching repositories: {e}")
        (return []))))
  
  (defn clone-or-update-repo [self repo-name]
    "Clone or update a single repository"
    (setv repo-path (/ self.base-path repo-name))
    
    (try
      (if (.exists repo-path)
        (do
          ;; Update existing repo
          (setv repo (git.Repo repo-path))
          (setv origin (.remote repo "origin"))
          (.fetch origin)
          (.pull origin)
          (print f"↻ Updated {repo-name}"))
        (do
          ;; Clone new repo
          (.mkdir (.parent repo-path) :parents True :exist-ok True)
          (git.Repo.clone-from
            f"https://github.com/{repo-name}.git"
            repo-path)
          (print f"↓ Cloned {repo-name}")))
      (except [Exception e]
        (print f"✗ Error with {repo-name}: {e}"))))
  
  (defn fetch-all-repos-parallel [self [max-workers 16]]
    "Fetch all repositories in parallel"
    (setv repos (.get-all-repositories self))
    
    (when repos
      (print f"Fetching {(len repos)} repositories...")
      (with [executor (ThreadPoolExecutor :max-workers max-workers)]
        (setv futures {
          (.submit executor self.clone-or-update-repo repo) repo
          for repo in repos})
        
        (for [future (as-completed futures)]
          (try
            (.result future)
            (except [Exception e]
              (print f"✗ Failed: {e}"))))))))

;; ========================================
;; 3. COLLABORATOR MANAGEMENT
;; ========================================

(defclass CollaboratorManager []
  "Manage repository collaborators"
  
  (defn __init__ [self organization]
    (setv self.organization organization))
  
  (defn setup-repository-collaborators [self repo-name admin-users write-users]
    "Set up collaborators for a repository"
    
    ;; Add admin collaborators
    (for [user admin-users]
      (github.RepositoryCollaborator
        f"{repo-name}-admin-{user}"
        :repository repo-name
        :username user
        :permission "admin")
      (print f"  → Added {user} as admin to {repo-name}"))
    
    ;; Add write collaborators
    (for [user write-users]
      (github.RepositoryCollaborator
        f"{repo-name}-write-{user}"
        :repository repo-name
        :username user
        :permission "push")
      (print f"  → Added {user} with write access to {repo-name}")))
  
  (defn setup-org-wide-collaborators [self 
                                      [admin-users ["jwalsh" "seanjensengrey"]]
                                      [write-users ["dsp-dr"]]]
    "Set up collaborators for all organization repositories"
    
    ;; Get all organization repositories
    (try
      (setv org-repos (github.get-repositories
        :query f"org:{self.organization}"
        :include-repo-id True))
      
      (print f"Setting up collaborators for {self.organization}...")
      
      ;; Set up collaborators for each repo
      (for [repo-name org-repos.full-names]
        (.setup-repository-collaborators self
          repo-name
          admin-users
          write-users))
      
      (except [Exception e]
        (print f"Error setting up collaborators: {e}")))))

;; ========================================
;; 4. REPOSITORY STATUS
;; ========================================

(defclass RepositoryStatus []
  "Check repository status"
  
  (defn __init__ [self [base-path "./repos"]]
    (setv self.base-path (Path base-path)))
  
  (defn get-repository-overview [self]
    "Get overview of all repositories"
    (try
      (setv repos (github.get-repositories
        :query "user:@me"
        :include-repo-id True))
      
      ;; Group by organization
      (setv org-counts {})
      (for [repo-name repos.full-names]
        (setv org (.split repo-name "/") [0])
        (if (in org org-counts)
          (setv (get org-counts org) (+ (get org-counts org) 1))
          (setv (get org-counts org) 1)))
      
      (return org-counts)
      
      (except [Exception e]
        (print f"Error getting repository overview: {e}")
        (return {}))))
  
  (defn find-dirty-repos [self]
    "Find repositories with uncommitted changes"
    (setv dirty-repos [])
    
    (when (.exists self.base-path)
      (for [repo-dir (.iterdir self.base-path)]
        (when (.is-dir repo-dir)
          (for [sub-dir (.iterdir repo-dir)]
            (setv git-dir (/ sub-dir ".git"))
            (when (.exists git-dir)
              (try
                (setv repo (git.Repo sub-dir))
                (when (or (.is-dirty repo) repo.untracked-files)
                  (setv repo-name (.relative-to sub-dir self.base-path))
                  (setv status {
                    "modified" (len (.diff repo.index None))
                    "staged" (len (.diff repo.index "HEAD"))
                    "untracked" (len repo.untracked-files)})
                  (.append dirty-repos [str repo-name) status]))
                (except [Exception]
                  None)))))))
    
    (return dirty-repos))
  
  (defn print-status-report [self]
    "Print a comprehensive status report"
    (print "=== Repository Overview ===")
    (setv overview (.get-repository-overview self))
    (setv total (sum (.values overview)))
    (print f"Total repositories: {total}\n")
    
    (for [[org count] (sorted (.items overview))]
      (print f"{org:<30} {count:>3} repos"))
    
    (print "\n=== Dirty Repositories ===")
    (setv dirty (.find-dirty-repos self))
    
    (if dirty
      (for [[repo-name status] dirty]
        (print f"\n{repo-name}:")
        (when (get status "staged")
          (print f"  Staged: {(get status \"staged\")} files"))
        (when (get status "modified")
          (print f"  Modified: {(get status \"modified\")} files"))
        (when (get status "untracked")
          (print f"  Untracked: {(get status \"untracked\")} files")))
      (print "All repositories are clean!"))))

;; ========================================
;; 5. ORGANIZATION SETUP ORCHESTRATION
;; ========================================

(defclass OrganizationSetup []
  "Orchestrate organization-wide setup"
  
  (defn __init__ [self [organization None]]
    (setv self.organization organization)
    (setv self.config (pulumi.Config)))
  
  (defn run-full-setup [self 
                       [accept-invites True]
                       [fetch-repos True]
                       [setup-collaborators True]
                       [show-status True]]
    "Run complete organization setup"
    
    ;; Step 1: Accept invitations
    (when accept-invites
      (print "=== Accepting Invitations ===")
      (accept-all-invitations))
    
    ;; Step 2: Fetch repositories
    (when fetch-repos
      (print "\n=== Fetching Repositories ===")
      (setv fetcher (RepositoryFetcher))
      (.fetch-all-repos-parallel fetcher))
    
    ;; Step 3: Setup collaborators
    (when (and setup-collaborators self.organization)
      (print f"\n=== Setting up Collaborators for {self.organization} ===")
      (setv manager (CollaboratorManager self.organization))
      (.setup-org-wide-collaborators manager))
    
    ;; Step 4: Show status
    (when show-status
      (print "\n=== Repository Status ===")
      (setv status (RepositoryStatus))
      (.print-status-report status))))

;; ========================================
;; CLI INTERFACE
;; ========================================

(defn main []
  "Main entry point with CLI arguments"
  (setv parser (argparse.ArgumentParser
    :description "Organization-wide GitHub repository management"))
  
  (.add-argument parser "-o" "--org"
    :help "Organization name")
  (.add-argument parser "-a" "--all"
    :action "store_true"
    :help "Run all setup steps")
  (.add-argument parser "-i" "--accept-invites"
    :action "store_true"
    :help "Accept pending invitations")
  (.add-argument parser "-f" "--fetch-repos"
    :action "store_true"
    :help "Fetch all repositories")
  (.add-argument parser "-c" "--setup-collaborators"
    :action "store_true"
    :help "Setup collaborators")
  (.add-argument parser "-s" "--show-status"
    :action "store_true"
    :help "Show repository status")
  
  (setv args (.parse-args parser))
  
  ;; If --all flag, enable everything
  (when args.all
    (setv args.accept-invites True)
    (setv args.fetch-repos True)
    (setv args.setup-collaborators True)
    (setv args.show-status True))
  
  ;; If no flags, show help
  (when (not (any [args.accept-invites
                   args.fetch-repos
                   args.setup-collaborators
                   args.show-status]))
    (.print-help parser)
    (return))
  
  ;; Run setup
  (setv setup (OrganizationSetup args.org))
  (.run-full-setup setup
    :accept-invites args.accept-invites
    :fetch-repos args.fetch-repos
    :setup-collaborators args.setup-collaborators
    :show-status args.show-status))

;; Run if executed directly
(when (= __name__ "__main__")
  (main))