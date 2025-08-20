;; Advanced Dynamic Providers - Git repository and CI/CD pipeline management
;; Based on https://www.pulumi.com/docs/iac/concepts/resources/dynamic-providers/

(import pulumi)
(import [pulumi.dynamic :as dynamic])
(import [pulumi-aws :as aws])
(import subprocess)
(import json)
(import requests)
(import os)
(import tempfile)
(import shutil)

;; Custom provider for Git repository operations
(defclass GitRepositoryProvider [dynamic.ResourceProvider]
  
  (defn create [self inputs]
    "Create and configure a Git repository"
    (setv repo-name (get inputs "name"))
    (setv repo-url (get inputs "url"))
    (setv branch (get inputs "branch" "main"))
    (setv local-path (get inputs "local_path" f"/tmp/{repo-name}"))
    
    (try
      ;; Clone repository
      (subprocess.run ["git" "clone" repo-url local-path] 
                      :check True :capture-output True)
      
      ;; Switch to branch
      (subprocess.run ["git" "checkout" "-b" branch]
                      :cwd local-path :check True :capture-output True)
      
      ;; Configure repository
      (when (get inputs "configure_hooks")
        (setv hooks-dir (os.path.join local-path ".git" "hooks"))
        (with [f (open (os.path.join hooks-dir "pre-commit") "w")]
          (.write f "#!/bin/bash\necho 'Running pre-commit checks...'\n"))
        (os.chmod (os.path.join hooks-dir "pre-commit") 0o755))
      
      (setv outputs
        {:id repo-name
         :name repo-name
         :url repo-url
         :branch branch
         :local_path local-path
         :status "created"
         :commit_hash (-> (subprocess.run ["git" "rev-parse" "HEAD"]
                                         :cwd local-path :capture-output True :text True)
                          (. stdout)
                          (.strip))})
      
      (dynamic.CreateResult repo-name outputs)
      
      (except [Exception as e]
        (raise (Exception f"Failed to create repository: {e}")))))
  
  (defn update [self id old-inputs new-inputs]
    "Update repository configuration"
    (setv local-path (get old-inputs "local_path"))
    (setv new-branch (get new-inputs "branch"))
    
    (try
      ;; Pull latest changes
      (subprocess.run ["git" "fetch" "origin"]
                      :cwd local-path :check True)
      
      ;; Switch to new branch if changed
      (when (!= (get old-inputs "branch") new-branch)
        (subprocess.run ["git" "checkout" new-branch]
                        :cwd local-path :check True))
      
      (setv outputs (dict new-inputs))
      (assoc outputs "id" id)
      (assoc outputs "status" "updated")
      (assoc outputs "commit_hash" 
             (-> (subprocess.run ["git" "rev-parse" "HEAD"]
                                :cwd local-path :capture-output True :text True)
                 (. stdout)
                 (.strip)))
      
      (dynamic.UpdateResult outputs)
      
      (except [Exception as e]
        (raise (Exception f"Failed to update repository: {e}")))))
  
  (defn delete [self id props]
    "Clean up repository"
    (setv local-path (get props "local_path"))
    (try
      (when (os.path.exists local-path)
        (shutil.rmtree local-path))
      (except [Exception as e]
        (print f"Warning: Failed to cleanup {local-path}: {e}")))))

;; Custom provider for CI/CD pipeline management
(defclass CIPipelineProvider [dynamic.ResourceProvider]
  
  (defn create [self inputs]
    "Create CI/CD pipeline configuration"
    (setv pipeline-name (get inputs "name"))
    (setv repo-path (get inputs "repository_path"))
    (setv pipeline-type (get inputs "type" "github-actions"))
    
    (try
      (cond
        ;; GitHub Actions workflow
        [(= pipeline-type "github-actions")
         (setv workflow-dir (os.path.join repo-path ".github" "workflows"))
         (os.makedirs workflow-dir :exist-ok True)
         
         (setv workflow-content
           f"name: {pipeline-name}
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    - name: Run tests
      run: |
        python -m pytest
    - name: Run linting
      run: |
        python -m flake8 .
  
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Deploy to staging
      run: |
        echo 'Deploying to staging...'
        # Add deployment commands here")
         
         (setv workflow-file (os.path.join workflow-dir f"{pipeline-name}.yml"))
         (with [f (open workflow-file "w")]
           (.write f workflow-content))]
        
        ;; GitLab CI
        [(= pipeline-type "gitlab-ci")
         (setv gitlab-config
           f"stages:
  - test
  - deploy

variables:
  PIP_CACHE_DIR: \"$CI_PROJECT_DIR/.cache/pip\"

cache:
  paths:
    - .cache/pip/

test:
  stage: test
  image: python:3.9
  script:
    - pip install -r requirements.txt
    - python -m pytest
    - python -m flake8 .

deploy:
  stage: deploy
  image: python:3.9
  script:
    - echo 'Deploying application...'
  only:
    - main")
         
         (with [f (open (os.path.join repo-path ".gitlab-ci.yml") "w")]
           (.write f gitlab-config))]
        
        ;; Jenkins pipeline
        [(= pipeline-type "jenkins")
         (setv jenkinsfile-content
           f"pipeline {{
    agent any
    
    stages {{
        stage('Test') {{
            steps {{
                sh 'python -m pip install --upgrade pip'
                sh 'pip install -r requirements.txt'
                sh 'python -m pytest'
                sh 'python -m flake8 .'
            }}
        }}
        
        stage('Deploy') {{
            when {{
                branch 'main'
            }}
            steps {{
                sh 'echo \"Deploying to production...\"'
            }}
        }}
    }}
    
    post {{
        always {{
            junit 'test-results.xml'
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: false,
                keepAll: true,
                reportDir: 'htmlcov',
                reportFiles: 'index.html',
                reportName: 'Coverage Report'
            ])
        }}
    }}
}}")
         
         (with [f (open (os.path.join repo-path "Jenkinsfile") "w")]
           (.write f jenkinsfile-content))])
      
      (setv outputs
        {:id pipeline-name
         :name pipeline-name
         :type pipeline-type
         :repository_path repo-path
         :status "created"
         :config_file (cond
                        [(= pipeline-type "github-actions") f".github/workflows/{pipeline-name}.yml"]
                        [(= pipeline-type "gitlab-ci") ".gitlab-ci.yml"]
                        [(= pipeline-type "jenkins") "Jenkinsfile"])})
      
      (dynamic.CreateResult pipeline-name outputs)
      
      (except [Exception as e]
        (raise (Exception f"Failed to create CI pipeline: {e}")))))
  
  (defn update [self id old-inputs new-inputs]
    "Update pipeline configuration"
    ;; For this example, we'll recreate the pipeline
    (self.delete id old-inputs)
    (self.create new-inputs))
  
  (defn delete [self id props]
    "Remove pipeline configuration"
    (setv repo-path (get props "repository_path"))
    (setv pipeline-type (get props "type"))
    (setv config-file (get props "config_file"))
    
    (try
      (setv file-path (os.path.join repo-path config-file))
      (when (os.path.exists file-path)
        (os.remove file-path))
      (except [Exception as e]
        (print f"Warning: Failed to remove {config-file}: {e}")))))

;; Custom provider for application health checks
(defclass HealthCheckProvider [dynamic.ResourceProvider]
  
  (defn create [self inputs]
    "Create health check configuration"
    (setv check-name (get inputs "name"))
    (setv url (get inputs "url"))
    (setv expected-status (get inputs "expected_status" 200))
    (setv timeout (get inputs "timeout" 30))
    
    (try
      ;; Test the health check
      (setv response (requests.get url :timeout timeout))
      (setv is-healthy (= response.status-code expected-status))
      
      (setv outputs
        {:id check-name
         :name check-name
         :url url
         :expected_status expected-status
         :timeout timeout
         :status "active"
         :last_check_status response.status-code
         :last_check_healthy is-healthy
         :last_check_time (.isoformat (.utcnow datetime.datetime))})
      
      (dynamic.CreateResult check-name outputs)
      
      (except [Exception as e]
        (setv outputs
          {:id check-name
           :name check-name
           :url url
           :expected_status expected-status
           :timeout timeout
           :status "error"
           :error_message (str e)})
        
        (dynamic.CreateResult check-name outputs))))
  
  (defn update [self id old-inputs new-inputs]
    "Update health check"
    (self.create new-inputs))
  
  (defn delete [self id props]
    "Remove health check"
    (print f"Health check {id} removed")))

;; Resource classes
(defclass GitRepository [dynamic.Resource]
  (defn __init__ [self name props &optional [opts None]]
    (super.__init__ 
      (GitRepositoryProvider)
      name
      props
      opts)))

(defclass CIPipeline [dynamic.Resource]
  (defn __init__ [self name props &optional [opts None]]
    (super.__init__
      (CIPipelineProvider)
      name
      props
      opts)))

(defclass HealthCheck [dynamic.Resource]
  (defn __init__ [self name props &optional [opts None]]
    (super.__init__
      (HealthCheckProvider)
      name
      props
      opts)))

;; Configuration
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))

;; Create a test repository (using a temporary location)
(setv workshop-repo
  (GitRepository "workshop-repo"
    {:name f"{app-name}-repo"
     :url "https://github.com/aygp-dr/pulumi-lab.git"
     :branch "main"
     :local_path f"/tmp/{app-name}-{environment}"
     :configure_hooks True}))

;; Create CI/CD pipeline
(setv github-pipeline
  (CIPipeline "github-actions"
    {:name f"{app-name}-ci"
     :repository_path (. workshop-repo local-path)
     :type "github-actions"}
    :opts (pulumi.ResourceOptions :depends-on [workshop-repo])))

(setv gitlab-pipeline
  (CIPipeline "gitlab-ci"
    {:name f"{app-name}-gitlab"
     :repository_path (. workshop-repo local-path)
     :type "gitlab-ci"}
    :opts (pulumi.ResourceOptions :depends-on [workshop-repo])))

;; Create health checks for different environments
(setv api-health-check
  (HealthCheck "api-health"
    {:name f"{app-name}-api-health"
     :url f"https://api.{app-name}.example.com/health"
     :expected_status 200
     :timeout 10}))

(setv website-health-check
  (HealthCheck "website-health"
    {:name f"{app-name}-website-health"
     :url f"https://{app-name}.example.com"
     :expected_status 200
     :timeout 15}))

;; Create AWS Lambda function that uses our custom resources
(setv lambda-role
  (aws.iam.Role "health-check-lambda-role"
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "lambda.amazonaws.com"}
                    :Effect "Allow"}]})))

(setv lambda-policy-attachment
  (aws.iam.RolePolicyAttachment "lambda-execution"
    :role (. lambda-role name)
    :policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"))

;; Lambda function that performs health checks
(setv health-check-lambda
  (aws.lambda.Function "health-checker"
    :role (. lambda-role arn)
    :code (pulumi.AssetArchive
            {"index.py" (pulumi.StringAsset
              f"import json
import requests
import datetime

def handler(event, context):
    health_checks = [
        {{
            'name': '{(. api-health-check name)}',
            'url': '{(. api-health-check url)}',
            'expected_status': {(. api-health-check expected-status)}
        }},
        {{
            'name': '{(. website-health-check name)}',
            'url': '{(. website-health-check url)}',
            'expected_status': {(. website-health-check expected-status)}
        }}
    ]
    
    results = []
    for check in health_checks:
        try:
            response = requests.get(check['url'], timeout=10)
            is_healthy = response.status_code == check['expected_status']
            results.append({{
                'name': check['name'],
                'url': check['url'],
                'status': response.status_code,
                'healthy': is_healthy,
                'timestamp': datetime.datetime.utcnow().isoformat()
            }})
        except Exception as e:
            results.append({{
                'name': check['name'],
                'url': check['url'],
                'error': str(e),
                'healthy': False,
                'timestamp': datetime.datetime.utcnow().isoformat()
            }})
    
    return {{
        'statusCode': 200,
        'body': json.dumps({{
            'checks': results,
            'overall_healthy': all(r.get('healthy', False) for r in results)
        }})
    }}")})
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 60
    :memory-size 256))

;; CloudWatch Event to run health checks periodically
(setv health-check-schedule
  (aws.cloudwatch.EventRule "health-check-schedule"
    :description "Run health checks every 5 minutes"
    :schedule-expression "rate(5 minutes)"))

(setv lambda-permission
  (aws.lambda.Permission "health-check-permission"
    :action "lambda:InvokeFunction"
    :function (. health-check-lambda name)
    :principal "events.amazonaws.com"
    :source-arn (. health-check-schedule arn)))

(setv event-target
  (aws.cloudwatch.EventTarget "health-check-target"
    :rule (. health-check-schedule name)
    :arn (. health-check-lambda arn)))

;; Outputs
(pulumi.export "repository-info"
  {:name (. workshop-repo name)
   :local-path (. workshop-repo local-path)
   :commit-hash (. workshop-repo commit-hash)
   :status (. workshop-repo status)})

(pulumi.export "pipeline-configs"
  {:github-actions (. github-pipeline config-file)
   :gitlab-ci (. gitlab-pipeline config-file)})

(pulumi.export "health-checks"
  {:api {:name (. api-health-check name)
         :url (. api-health-check url)
         :status (. api-health-check last-check-status)}
   :website {:name (. website-health-check name)
             :url (. website-health-check url)
             :status (. website-health-check last-check-status)}})

(pulumi.export "lambda-function-name" (. health-check-lambda function-name))
(pulumi.export "health-check-schedule" (. health-check-schedule name))

;; Dynamic provider capabilities demonstration
(pulumi.export "dynamic-provider-features"
  {:git-operations ["clone" "branch-switching" "hook-configuration"]
   :ci-cd-platforms ["github-actions" "gitlab-ci" "jenkins"]
   :health-monitoring ["http-checks" "status-validation" "periodic-testing"]
   :aws-integration ["lambda-functions" "cloudwatch-events" "iam-roles"]})