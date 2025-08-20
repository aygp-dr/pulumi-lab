;; Pulumi CLI Commands Reference and Examples in Hy
;; Based on https://www.pulumi.com/docs/iac/cli/commands/

(import pulumi)
(import [pulumi-aws :as aws])
(import subprocess)
(import json)
(import os)

;; Configuration for CLI demonstrations
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "cli-demo"))
(setv environment (pulumi.get-stack))

;; Create a simple resource for CLI demonstrations
(setv demo-bucket
  (aws.s3.BucketV2 "cli-demo-bucket"
    :bucket f"{app-name}-cli-examples-{environment}"))

;; Parameter Store for CLI examples
(setv cli-config-param
  (aws.ssm.Parameter "cli-config"
    :name f"/pulumi/{app-name}/cli-examples"
    :type "String"
    :value (pulumi.Output.json-stringify
      {:cli-version "3.95.0"
       :demo-purpose "CLI commands reference"
       :stack environment
       :app app-name})))

;; Lambda function for CLI testing
(setv cli-test-lambda
  (aws.lambda.Function "cli-test"
    :code (pulumi.AssetArchive
            {"index.py" (pulumi.StringAsset """
def handler(event, context):
    import json
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'CLI test successful',
            'event': event,
            'cli_demo': True
        })
    }
""")})
    :handler "index.handler"
    :runtime "python3.9"
    :role "arn:aws:iam::123456789012:role/lambda-role"  ;; Mock role for demo
    :timeout 30))

;; Export CLI command examples and references
(pulumi.export "cli-commands-reference"
  {:core-commands
    {:up {:command "pulumi up"
          :description "Deploy infrastructure"
          :flags ["--yes" "--skip-preview" "--diff" "--target RESOURCE"]
          :examples ["pulumi up --yes"
                    "pulumi up --target aws:s3/bucket:cli-demo-bucket"
                    "pulumi up --skip-preview --diff"]
          :use-cases ["Deploy changes"
                     "Target specific resources"
                     "Automated deployments"]}
     
     :preview {:command "pulumi preview"
               :description "Show planned changes without applying"
               :flags ["--diff" "--json" "--target RESOURCE"]
               :examples ["pulumi preview"
                         "pulumi preview --diff"
                         "pulumi preview --json > preview.json"]
               :use-cases ["Validate changes"
                          "CI/CD gate checks"
                          "Debug resource dependencies"]}
     
     :destroy {:command "pulumi destroy"
               :description "Delete all resources in stack"
               :flags ["--yes" "--target RESOURCE" "--exclude-protected"]
               :examples ["pulumi destroy --yes"
                         "pulumi destroy --target aws:s3/bucket:cli-demo-bucket"]
               :use-cases ["Tear down environment"
                          "Remove specific resources"
                          "Clean up failed deployments"]}
     
     :refresh {:command "pulumi refresh"
               :description "Sync state with actual infrastructure"
               :flags ["--yes" "--diff"]
               :examples ["pulumi refresh"
                         "pulumi refresh --yes --diff"]
               :use-cases ["Detect drift"
                          "Import manual changes"
                          "Fix state inconsistencies"]}}
   
   :stack-management
    {:init {:command "pulumi stack init"
            :description "Create new stack"
            :flags ["--secrets-provider PROVIDER"]
            :examples ["pulumi stack init dev"
                      "pulumi stack init prod --secrets-provider awskms://..."
                      "pulumi stack init staging --secrets-provider passphrase"]
            :use-cases ["New environment setup"
                       "Environment isolation"
                       "Secrets management"]}
     
     :select {:command "pulumi stack select"
              :description "Switch to different stack"
              :examples ["pulumi stack select dev"
                        "pulumi stack select prod"]
              :use-cases ["Environment switching"
                         "Multi-stack workflows"]}
     
     :ls {:command "pulumi stack ls"
          :description "List all stacks"
          :flags ["--json"]
          :examples ["pulumi stack ls"
                    "pulumi stack ls --json"]
          :use-cases ["Stack inventory"
                     "Automation scripts"]}
     
     :rm {:command "pulumi stack rm"
          :description "Delete stack"
          :flags ["--yes" "--force"]
          :examples ["pulumi stack rm old-stack --yes"]
          :use-cases ["Cleanup old environments"
                     "Remove unused stacks"]}
     
     :export {:command "pulumi stack export"
              :description "Export stack state"
              :flags ["--file FILE"]
              :examples ["pulumi stack export > backup.json"
                        "pulumi stack export --file backup.json"]
              :use-cases ["State backup"
                         "Stack migration"
                         "Disaster recovery"]}
     
     :import {:command "pulumi stack import"
              :description "Import stack state"
              :flags ["--file FILE"]
              :examples ["pulumi stack import < backup.json"
                        "pulumi stack import --file backup.json"]
              :use-cases ["State restoration"
                         "Stack migration"
                         "Disaster recovery"]}}
   
   :configuration
    {:config-set {:command "pulumi config set"
                  :description "Set configuration value"
                  :flags ["--secret" "--plaintext"]
                  :examples ["pulumi config set app:name my-app"
                            "pulumi config set --secret dbPassword secret123"
                            "pulumi config set aws:region us-west-2"]
                  :use-cases ["Environment configuration"
                             "Secret management"
                             "Provider setup"]}
     
     :config-get {:command "pulumi config get"
                  :description "Get configuration value"
                  :examples ["pulumi config get app:name"
                            "pulumi config get dbPassword"]
                  :use-cases ["Value retrieval"
                             "Script automation"]}
     
     :config-rm {:command "pulumi config rm"
                 :description "Remove configuration value"
                 :examples ["pulumi config rm app:debug"]
                 :use-cases ["Cleanup old config"
                            "Remove secrets"]}
     
     :config-ls {:command "pulumi config"
                 :description "List all configuration"
                 :flags ["--json" "--show-secrets"]
                 :examples ["pulumi config"
                           "pulumi config --json"
                           "pulumi config --show-secrets"]
                 :use-cases ["Configuration audit"
                            "Environment comparison"]}}
   
   :state-management
    {:state {:command "pulumi state"
             :description "Manage stack state"
             :subcommands ["delete" "rename" "unprotect"]
             :examples ["pulumi state delete 'aws:s3/bucket:old-bucket'"
                       "pulumi state rename 'aws:s3/bucket:old' 'aws:s3/bucket:new'"]
             :use-cases ["Fix broken state"
                        "Resource cleanup"
                        "State migration"]}
     
     :import-resource {:command "pulumi import"
                       :description "Import existing resource"
                       :examples ["pulumi import aws:s3/bucket:existing existing-bucket-name"]
                       :use-cases ["Adopt existing infrastructure"
                                  "Migrate to Pulumi"
                                  "Fix missing resources"]}}
   
   :debugging
    {:logs {:command "pulumi logs"
            :description "Show stack logs"
            :flags ["--follow" "--since DURATION" "--resource RESOURCE"]
            :examples ["pulumi logs"
                      "pulumi logs --follow"
                      "pulumi logs --resource aws:lambda/function:my-function"]
            :use-cases ["Debug deployments"
                       "Monitor applications"
                       "Troubleshoot issues"]}
     
     :console {:command "pulumi console"
               :description "Open Pulumi Console"
               :examples ["pulumi console"]
               :use-cases ["Visual stack management"
                          "Resource exploration"
                          "Team collaboration"]}
     
     :about {:command "pulumi about"
             :description "Show environment info"
             :examples ["pulumi about"]
             :use-cases ["Debug environment"
                        "Version checking"
                        "Support tickets"]}}
   
   :advanced
    {:watch {:command "pulumi watch"
             :description "Continuously deploy on file changes"
             :examples ["pulumi watch"]
             :use-cases ["Development workflow"
                        "Rapid iteration"
                        "Local testing"]}
     
     :cancel {:command "pulumi cancel"
              :description "Cancel running operation"
              :examples ["pulumi cancel"]
              :use-cases ["Stop failed deployments"
                         "Emergency stops"]}
     
     :whoami {:command "pulumi whoami"
              :description "Show current user"
              :flags ["--verbose"]
              :examples ["pulumi whoami"
                        "pulumi whoami --verbose"]
              :use-cases ["Identity verification"
                         "Backend checking"]}
     
     :login {:command "pulumi login"
             :description "Log into backend"
             :examples ["pulumi login"
                       "pulumi login --local"
                       "pulumi login s3://my-state-bucket"]
             :use-cases ["Backend switching"
                        "Authentication"
                        "Self-hosted setup"]}
     
     :logout {:command "pulumi logout"
              :description "Log out of backend"
              :examples ["pulumi logout"]
              :use-cases ["Switch accounts"
                         "Clear credentials"]}}})

;; Export common CLI workflows
(pulumi.export "cli-workflows"
  {:development-cycle
    {:description "Typical development workflow"
     :steps ["pulumi stack select dev"
             "pulumi config set app:debug true"
             "pulumi preview"
             "pulumi up"
             "pulumi logs --follow"]
     :automation "#!/bin/bash\nset -e\npulumi stack select dev\npulumi up --yes\necho 'Development deployment complete'"}
   
   :production-deployment
    {:description "Production deployment workflow"
     :steps ["pulumi stack select prod"
             "pulumi config set app:debug false"
             "pulumi preview --diff"
             "pulumi up --yes"
             "pulumi refresh"]
     :automation "#!/bin/bash\nset -e\npulumi stack select prod\npulumi preview --diff\nread -p 'Deploy to production? (y/N) ' -n 1 -r\nif [[ $REPLY =~ ^[Yy]$ ]]; then\n  pulumi up --yes\nfi"}
   
   :disaster-recovery
    {:description "Backup and restore workflow"
     :backup-steps ["pulumi stack export > backup-$(date +%Y%m%d).json"
                   "aws s3 cp backup-*.json s3://backup-bucket/"]
     :restore-steps ["aws s3 cp s3://backup-bucket/backup-latest.json ."
                    "pulumi stack import < backup-latest.json"
                    "pulumi refresh"]
     :automation "#!/bin/bash\nBACKUP_FILE=\"backup-$(date +%Y%m%d-%H%M%S).json\"\npulumi stack export > $BACKUP_FILE\necho \"Stack backed up to $BACKUP_FILE\""}
   
   :multi-stack-management
    {:description "Manage multiple stacks"
     :steps ["for stack in dev staging prod; do"
             "  pulumi stack select $stack"
             "  pulumi config set version v1.2.3"
             "  pulumi up --yes"
             "done"]
     :automation "#!/bin/bash\nSTACKS=(\"dev\" \"staging\" \"prod\")\nfor stack in \"${STACKS[@]}\"; do\n  echo \"Deploying to $stack\"\n  pulumi stack select $stack\n  pulumi up --yes\ndone"}})

;; Export CLI flags reference
(pulumi.export "cli-flags-reference"
  {:global-flags
    ["--color WHEN" "Colorize output (always, never, auto)"
     "--cwd DIR" "Run from specific directory"
     "--non-interactive" "Disable interactive prompts"
     "--verbose LEVEL" "Verbose logging (1-9)"
     "--logflow" "Log flow debugging"
     "--tracing URL" "OpenTracing endpoint"]
   
   :common-flags
    {:yes "Skip confirmation prompts"
     :diff "Show detailed diffs"
     :json "Output in JSON format"
     :target "Target specific resources"
     :skip-preview "Skip preview step"
     :parallel "Number of parallel operations"
     :refresh "Refresh state before operation"}
   
   :environment-variables
    {:PULUMI_ACCESS_TOKEN "Authentication token"
     :PULUMI_CONFIG_PASSPHRASE "Encryption passphrase"
     :PULUMI_BACKEND_URL "Backend URL override"
     :PULUMI_SKIP_UPDATE_CHECK "Skip version check"
     :PULUMI_DEBUG_COMMANDS "Debug CLI commands"}})

;; Export practical examples for each command
(pulumi.export "practical-examples"
  {:daily-operations
    {:check-what-changed "pulumi preview --diff"
     :deploy-specific-resource f"pulumi up --target {(. demo-bucket urn)}"
     :backup-stack "pulumi stack export > backup.json"
     :switch-environment "pulumi stack select staging"
     :view-config "pulumi config"
     :check-logs "pulumi logs --follow"}
   
   :troubleshooting
    {:fix-state-drift "pulumi refresh --yes"
     :force-delete-resource "pulumi state delete 'aws:s3/bucket:broken'"
     :import-existing "pulumi import aws:s3/bucket:existing bucket-name"
     :cancel-stuck-operation "pulumi cancel"
     :debug-verbose "pulumi up --verbose 9"}
   
   :automation
    {:ci-cd-deploy "pulumi up --yes --non-interactive"
     :validate-config "pulumi config"
     :export-for-backup "pulumi stack export --file backup.json"
     :list-all-stacks "pulumi stack ls --json"}})

;; Export testing commands for LocalStack
(pulumi.export "localstack-cli-examples"
  {:setup "export AWS_ENDPOINT_URL=http://localhost:4566"
   :deploy "pulumi up --yes"
   :test-lambda f"aws lambda invoke --function-name {(. cli-test-lambda function-name)} --endpoint-url $AWS_ENDPOINT_URL response.json"
   :list-buckets "aws s3 ls --endpoint-url $AWS_ENDPOINT_URL"
   :check-ssm f"aws ssm get-parameter --name /pulumi/{app-name}/cli-examples --endpoint-url $AWS_ENDPOINT_URL"})

;; Export tips and best practices
(pulumi.export "cli-best-practices"
  {:general ["Always run 'pulumi preview' before 'pulumi up'"
             "Use '--yes' flag only in automation"
             "Regular state backups with 'pulumi stack export'"
             "Use stack-specific configuration"]
   :development ["Use 'pulumi watch' for rapid iteration"
                "Keep dev stacks separate from production"
                "Use local backend for experimentation"]
   :production ["Always review diffs before deployment"
               "Use version control for all code"
               "Implement proper backup procedures"
               "Monitor logs during deployment"]
   :automation ["Use '--non-interactive' in CI/CD"
               "Set PULUMI_ACCESS_TOKEN for auth"
               "Validate configuration before deployment"
               "Implement proper error handling"]})

;; Export resource information for CLI targeting
(pulumi.export "resource-references"
  {:demo-bucket-urn (. demo-bucket urn)
   :lambda-function-urn (. cli-test-lambda urn)
   :ssm-parameter-urn (. cli-config-param urn)
   :targeting-examples [f"pulumi up --target {(. demo-bucket urn)}"
                       f"pulumi destroy --target {(. cli-test-lambda urn)}"
                       f"pulumi refresh --target {(. cli-config-param urn)}"]})

;; Output CLI cheat sheet
(pulumi.export "cli-cheat-sheet"
  "# Pulumi CLI Quick Reference
  
## Core Operations
pulumi up                    # Deploy changes
pulumi preview               # Show planned changes  
pulumi destroy               # Delete all resources
pulumi refresh               # Sync state with reality

## Stack Management
pulumi stack init <name>     # Create new stack
pulumi stack select <name>   # Switch stacks
pulumi stack ls              # List all stacks
pulumi stack export          # Backup state

## Configuration
pulumi config set key value  # Set config value
pulumi config set --secret   # Set secret value
pulumi config get key        # Get config value
pulumi config                # List all config

## Debugging
pulumi logs                  # View logs
pulumi logs --follow         # Stream logs
pulumi state delete URN      # Remove from state
pulumi import TYPE NAME ID   # Import existing resource

## Useful Flags
--yes                        # Skip confirmations
--diff                       # Show detailed changes
--target URN                 # Target specific resource
--non-interactive           # Disable prompts
--verbose 9                 # Maximum verbosity")