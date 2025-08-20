;; Academic Infrastructure Components in Hy
;; Component resources for formal methods, proof systems, and research tools

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])
(import [pulumi-github :as github])

;; Configuration
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "academic"))
(setv environment (pulumi.get-stack))

;; 1. Lean4 Proof Environment Component
(defclass Lean4Environment [pulumi.ComponentResource]
  "Component for setting up Lean4 theorem proving infrastructure"
  
  (defn __init__ [self name args &optional [opts None]]
    (super.__init__ "academic:lean4:Environment" name {} opts)
    
    (setv lean-version (get args "version" "4.0.0"))
    (setv instance-type (get args "instance-type" "t3.large"))
    (setv storage-size (get args "storage-gb" 100))
    (setv enable-jupyterlab (get args "jupyter" True))
    
    ;; S3 bucket for proof artifacts and mathlib cache
    (setv self.artifacts-bucket
      (aws.s3.BucketV2 f"{name}-artifacts"
        :bucket f"{name}-lean4-artifacts-{(.hex (random.RandomId \"suffix\" :byte-length 4))}"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Versioning for proof history
    (setv artifacts-versioning
      (aws.s3.BucketVersioningV2 f"{name}-versioning"
        :bucket (. self.artifacts-bucket id)
        :versioning-configuration {:status "Enabled"}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; EC2 instance for Lean4 development
    (setv user-data-script f"""#!/bin/bash
set -e

# Update system
apt-get update && apt-get upgrade -y

# Install dependencies
apt-get install -y curl git build-essential cmake

# Install Lean4
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
source ~/.profile
elan install {lean-version}
elan default {lean-version}

# Install mathlib tools
. ~/.profile && lake exe cache get

# Install VS Code Server for remote development
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@$USER

{"# Install JupyterLab with Lean kernel" if enable-jupyterlab else ""}
{"pip3 install jupyterlab" if enable-jupyterlab else ""}
{"python3 -m pip install lean-jupyter-kernel" if enable-jupyterlab else ""}

# Create workspace directory
mkdir -p /home/ubuntu/lean4-workspace
chown -R ubuntu:ubuntu /home/ubuntu/lean4-workspace

echo 'Lean4 environment ready!' > /var/log/lean4-setup.log
""")
    
    (setv self.lean-instance
      (aws.ec2.Instance f"{name}-instance"
        :ami "ami-0c02fb55956c7d316"  ;; Ubuntu 20.04 LTS
        :instance-type instance-type
        :user-data user-data-script
        :root-block-device {:volume-size storage-size
                           :volume-type "gp3"
                           :encrypted True}
        :tags {:Name f"{name}-lean4-server"
               :Type "lean4-environment"
               :Version lean-version}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; CloudWatch Log Group for Lean4 logs
    (setv self.log-group
      (aws.cloudwatch.LogGroup f"{name}-logs"
        :name f"/aws/lean4/{name}"
        :retention-in-days 30
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Output registration
    (self.register-outputs
      {:instance-id (. self.lean-instance id)
       :instance-ip (. self.lean-instance public-ip)
       :artifacts-bucket (. self.artifacts-bucket bucket)
       :log-group-name (. self.log-group name)
       :lean-version lean-version})))

;; 2. TLA+ Specification and Model Checking Component
(defclass TLAPlusLab [pulumi.ComponentResource]
  "Component for TLA+ specification and TLC model checking infrastructure"
  
  (defn __init__ [self name args &optional [opts None]]
    (super.__init__ "academic:tlaplus:Lab" name {} opts)
    
    (setv tla-tools-version (get args "tla-version" "1.8.0"))
    (setv enable-distributed-tlc (get args "distributed" False))
    (setv worker-count (get args "workers" 4))
    
    ;; S3 bucket for TLA+ specifications and model checking results
    (setv self.specs-bucket
      (aws.s3.BucketV2 f"{name}-specs"
        :bucket f"{name}-tlaplus-specs-{(.hex (random.RandomId \"suffix\" :byte-length 4))}"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Lambda function for automated specification checking
    (setv self.spec-checker
      (aws.lambda.Function f"{name}-checker"
        :code (pulumi.AssetArchive
                {"index.py" (pulumi.StringAsset f"""
import json
import boto3
import subprocess
import tempfile
import os

def handler(event, context):
    s3 = boto3.client('s3')
    
    # Download TLA+ spec from S3
    bucket = event['bucket']
    key = event['key']
    
    with tempfile.NamedTemporaryFile(suffix='.tla', delete=False) as f:
        s3.download_fileobj(bucket, key, f)
        spec_file = f.name
    
    try:
        # Run TLC model checker
        result = subprocess.run([
            'java', '-cp', '/opt/tla2tools.jar',
            'tlc2.TLC', spec_file
        ], capture_output=True, text=True, timeout=300)
        
        # Upload results back to S3
        result_key = key.replace('.tla', '_result.txt')
        s3.put_object(
            Bucket=bucket,
            Key=result_key,
            Body=result.stdout + result.stderr
        )
        
        return {{
            'statusCode': 200,
            'body': json.dumps({{
                'success': result.returncode == 0,
                'output': result.stdout,
                'errors': result.stderr,
                'result_key': result_key
            }})
        }}
    except Exception as e:
        return {{
            'statusCode': 500,
            'body': json.dumps({{'error': str(e)}})
        }}
    finally:
        os.unlink(spec_file)
""")})
        :handler "index.handler"
        :runtime "python3.9"
        :timeout 600
        :memory-size 1024
        :layers ["arn:aws:lambda:us-west-2:123456789012:layer:tla-tools:1"]
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; ECS cluster for distributed TLC (if enabled)
    (when enable-distributed-tlc
      (setv self.tlc-cluster
        (aws.ecs.Cluster f"{name}-tlc-cluster"
          :name f"{name}-distributed-tlc"
          :opts (pulumi.ResourceOptions :parent self))))
    
    ;; Output registration
    (self.register-outputs
      {:specs-bucket (. self.specs-bucket bucket)
       :checker-function (. self.spec-checker function-name)
       :tla-version tla-tools-version})))

;; 3. Formal Verification Workbench Component
(defclass FormalVerificationWorkbench [pulumi.ComponentResource]
  "Component for multi-tool formal verification environment"
  
  (defn __init__ [self name args &optional [opts None]]
    (super.__init__ "academic:formal:Workbench" name {} opts)
    
    (setv tools (get args "tools" ["lean4" "coq" "agda" "isabelle"]))
    (setv enable-web-ide (get args "web-ide" True))
    (setv shared-storage-gb (get args "storage" 200))
    
    ;; EFS for shared theorem libraries and proofs
    (setv self.shared-fs
      (aws.efs.FileSystem f"{name}-shared-fs"
        :creation-token f"{name}-formal-methods"
        :performance-mode "generalPurpose"
        :throughput-mode "provisioned"
        :provisioned-throughput-in-mibps 100
        :encrypted True
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Container definitions for each tool
    (setv tool-containers {})
    (for [tool tools]
      (assoc tool-containers tool
        (aws.ecs.TaskDefinition f"{name}-{tool}-task"
          :family f"{name}-{tool}"
          :network-mode "awsvpc"
          :requires-compatibilities ["FARGATE"]
          :cpu 2048
          :memory 4096
          :container-definitions (pulumi.Output.json-stringify
            [{:name tool
              :image f"formal-methods/{tool}:latest"
              :memory 4096
              :cpu 2048
              :essential True
              :mountPoints [{:sourceVolume "shared-proofs"
                            :containerPath "/proofs"
                            :readOnly False}]
              :logConfiguration {:logDriver "awslogs"
                                :options {:awslogs-group f"/aws/ecs/{name}-{tool}"
                                         :awslogs-region "us-west-2"
                                         :awslogs-stream-prefix "ecs"}}}])
          :volumes [{:name "shared-proofs"
                    :efsVolumeConfiguration {:fileSystemId (. self.shared-fs id)
                                           :transitEncryption "ENABLED"}}]
          :opts (pulumi.ResourceOptions :parent self))))
    
    ;; JupyterHub for collaborative formal methods research
    (when enable-web-ide
      (setv self.jupyterhub-instance
        (aws.ec2.Instance f"{name}-jupyterhub"
          :ami "ami-0c02fb55956c7d316"
          :instance-type "t3.xlarge"
          :user-data """#!/bin/bash
# Install JupyterHub with formal methods kernels
pip3 install jupyterhub jupyterlab
pip3 install dockerspawner

# Configure for Lean4, Coq, Agda kernels
pip3 install lean-jupyter-kernel
pip3 install coq-jupyter-kernel

systemctl enable jupyterhub
systemctl start jupyterhub
"""
          :tags {:Name f"{name}-jupyterhub"
                 :Type "formal-methods-ide"}
          :opts (pulumi.ResourceOptions :parent self))))
    
    ;; Output registration
    (self.register-outputs
      {:shared-filesystem-id (. self.shared-fs id)
       :tools-available tools
       :jupyterhub-ip (if enable-web-ide (. self.jupyterhub-instance public-ip) "disabled")})))

;; 4. Research Paper Management Component  
(defclass AcademicPaperPipeline [pulumi.ComponentResource]
  "Component for academic paper writing, review, and publication pipeline"
  
  (defn __init__ [self name args &optional [opts None]]
    (super.__init__ "academic:papers:Pipeline" name {} opts)
    
    (setv latex-compiler (get args "latex" "pdflatex"))
    (setv enable-arxiv-sync (get args "arxiv" True))
    (setv enable-collaboration (get args "collaboration" True))
    
    ;; S3 bucket for paper manuscripts and assets
    (setv self.manuscripts-bucket
      (aws.s3.BucketV2 f"{name}-manuscripts"
        :bucket f"{name}-papers-{(.hex (random.RandomId \"suffix\" :byte-length 4))}"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Lambda for LaTeX compilation
    (setv self.latex-compiler
      (aws.lambda.Function f"{name}-latex-compiler"
        :code (pulumi.AssetArchive
                {"index.py" (pulumi.StringAsset f"""
import json
import boto3
import subprocess
import tempfile
import os
import zipfile

def handler(event, context):
    s3 = boto3.client('s3')
    
    bucket = event['bucket']
    tex_key = event['tex_file']
    
    with tempfile.TemporaryDirectory() as tmpdir:
        # Download and extract LaTeX project
        tex_file = os.path.join(tmpdir, 'paper.tex')
        s3.download_file(bucket, tex_key, tex_file)
        
        # Compile with {latex-compiler}
        result = subprocess.run([
            '{latex-compiler}', '-output-directory', tmpdir, tex_file
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            # Upload PDF result
            pdf_file = os.path.join(tmpdir, 'paper.pdf')
            if os.path.exists(pdf_file):
                pdf_key = tex_key.replace('.tex', '.pdf')
                s3.upload_file(pdf_file, bucket, pdf_key)
                
                return {{
                    'statusCode': 200,
                    'body': json.dumps({{
                        'success': True,
                        'pdf_key': pdf_key,
                        'output': result.stdout
                    }})
                }}
        
        return {{
            'statusCode': 400,
            'body': json.dumps({{
                'success': False,
                'error': result.stderr
            }})
        }}
""")})
        :handler "index.handler"
        :runtime "python3.9"
        :timeout 300
        :memory-size 2048
        :layers ["arn:aws:lambda:us-west-2:123456789012:layer:texlive:1"]
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; DynamoDB for paper metadata and collaboration
    (when enable-collaboration
      (setv self.collaboration-table
        (aws.dynamodb.Table f"{name}-collaboration"
          :name f"{name}-paper-collaboration"
          :billing-mode "PAY_PER_REQUEST"
          :hash-key "paper_id"
          :range-key "timestamp"
          :attributes [{:name "paper_id" :type "S"}
                      {:name "timestamp" :type "N"}
                      {:name "author" :type "S"}]
          :global-secondary-indexes [{:name "author-index"
                                     :hash-key "author"
                                     :projection-type "ALL"}]
          :opts (pulumi.ResourceOptions :parent self))))
    
    ;; GitHub repository for version control
    (setv self.paper-repo
      (github.Repository f"{name}-papers"
        :name f"{name}-academic-papers"
        :description "Academic papers and formal proofs repository"
        :visibility "private"
        :has-issues True
        :has-wiki True
        :auto-init True
        :gitignore-template "TeX"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Output registration
    (self.register-outputs
      {:manuscripts-bucket (. self.manuscripts-bucket bucket)
       :latex-compiler-arn (. self.latex-compiler arn)
       :repository-url (. self.paper-repo html-url)
       :collaboration-enabled enable-collaboration})))

;; 5. Academic Conference Management Component
(defclass ConferenceInfrastructure [pulumi.ComponentResource]
  "Component for managing academic conferences and workshops"
  
  (defn __init__ [self name args &optional [opts None]]
    (super.__init__ "academic:conference:Infrastructure" name {} opts)
    
    (setv conference-name (get args "conference"))
    (setv expected-attendees (get args "attendees" 100))
    (setv enable-livestream (get args "livestream" True))
    (setv paper-submission-deadline (get args "deadline"))
    
    ;; Website hosting for conference
    (setv self.conference-bucket
      (aws.s3.BucketV2 f"{name}-website"
        :bucket f"{conference-name}-conference-{(.hex (random.RandomId \"suffix\" :byte-length 4))}"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Website configuration
    (setv website-config
      (aws.s3.BucketWebsiteConfigurationV2 f"{name}-website-config"
        :bucket (. self.conference-bucket id)
        :index-document {:suffix "index.html"}
        :error-document {:key "404.html"}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Paper submission system (using Lambda + DynamoDB)
    (setv self.submissions-table
      (aws.dynamodb.Table f"{name}-submissions"
        :name f"{conference-name}-paper-submissions"
        :billing-mode "PAY_PER_REQUEST"
        :hash-key "submission_id"
        :attributes [{:name "submission_id" :type "S"}
                    {:name "track" :type "S"}
                    {:name "submitted_at" :type "N"}]
        :global-secondary-indexes [{:name "track-time-index"
                                   :hash-key "track"
                                   :range-key "submitted_at"
                                   :projection-type "ALL"}]
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Video streaming infrastructure (if enabled)
    (when enable-livestream
      (setv self.streaming-channel
        (aws.ivs.Channel f"{name}-stream"
          :name f"{conference-name}-livestream"
          :type "STANDARD"
          :latency-mode "NORMAL"
          :authorized False
          :tags {:Conference conference-name
                 :Type "academic-livestream"}
          :opts (pulumi.ResourceOptions :parent self))))
    
    ;; Registration system
    (setv self.registration-api
      (aws.apigatewayv2.Api f"{name}-registration"
        :name f"{conference-name}-registration"
        :protocol-type "HTTP"
        :cors-configuration {:allow-origins ["*"]
                           :allow-methods ["GET" "POST" "OPTIONS"]
                           :allow-headers ["*"]}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Output registration
    (self.register-outputs
      {:conference-website (. self.conference-bucket bucket-domain-name)
       :submissions-table (. self.submissions-table name)
       :registration-api (. self.registration-api api-endpoint)
       :livestream-url (if enable-livestream (. self.streaming-channel playback-url) "disabled")
       :expected-capacity expected-attendees})))

;; Create instances of academic components
(setv lean4-env
  (Lean4Environment "lean4-lab"
    {:version "4.0.0"
     :instance-type "t3.xlarge"
     :storage-gb 200
     :jupyter True}))

(setv tlaplus-lab
  (TLAPlusLab "tlaplus-research"
    {:tla-version "1.8.0"
     :distributed True
     :workers 8}))

(setv formal-workbench
  (FormalVerificationWorkbench "formal-methods"
    {:tools ["lean4" "coq" "agda" "isabelle" "dafny"]
     :web-ide True
     :storage 500}))

(setv paper-pipeline
  (AcademicPaperPipeline "research-papers"
    {:latex "lualatex"
     :arxiv True
     :collaboration True}))

(setv conference-infra
  (ConferenceInfrastructure "formal-methods-conf"
    {:conference "FormMeth2025"
     :attendees 250
     :livestream True
     :deadline "2025-03-15"}))

;; Export academic infrastructure
(pulumi.export "academic-infrastructure"
  {:lean4-environment {:instance-ip (. lean4-env instance-ip)
                      :artifacts-bucket (. lean4-env artifacts-bucket)}
   :tlaplus-lab {:specs-bucket (. tlaplus-lab specs-bucket)
                 :checker-function (. tlaplus-lab checker-function)}
   :formal-workbench {:shared-filesystem (. formal-workbench shared-filesystem-id)
                     :jupyterhub-ip (. formal-workbench jupyterhub-ip)}
   :paper-pipeline {:manuscripts-bucket (. paper-pipeline manuscripts-bucket)
                   :repository-url (. paper-pipeline repository-url)}
   :conference {:website-url (. conference-infra conference-website)
               :registration-api (. conference-infra registration-api)
               :livestream-url (. conference-infra livestream-url)}})

;; Export funny/useful patterns
(pulumi.export "academic-humor"
  {:proof-deadline-calculator "Lambda function that calculates optimal panic time based on proof complexity"
   :theorem-dependency-graph "Visualizes which theorems depend on axiom of choice"
   :conference-coffee-optimization "ML model for optimal coffee break scheduling"
   :peer-review-sentiment-analysis "NLP analysis of reviewer comments for emotional damage assessment"
   :latex-compilation-prayer-counter "Tracks how many times 'please compile' was muttered"
   :coq-tactic-suggestion-engine "Suggests 'auto' when stuck for more than 10 minutes"})

;; Export component patterns demonstrated
(pulumi.export "component-patterns"
  {:encapsulation "Complex infrastructure bundled into reusable components"
   :composition "Components can be combined and configured"
   :abstraction "Hide implementation details behind clean interfaces"
   :reusability "Same component deployed across environments"
   :best-practices "Enforce organizational standards through components"
   :multi-cloud "Components can abstract across different providers"})