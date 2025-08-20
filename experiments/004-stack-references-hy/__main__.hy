;; Stack References - sharing outputs between stacks in Hy

(import pulumi)
(import pulumi-aws :as aws)

(setv config (pulumi.Config))
(setv stack (pulumi.get-stack))
(setv org (config.get "org"))

;; Reference another stack's outputs
(when (= stack "dev")
  (setv infra-stack 
    (pulumi.StackReference f"{org}/infrastructure/prod"))
  
  ;; Get VPC ID from infrastructure stack
  (setv vpc-id 
    (infra-stack.get-output "vpc_id"))
  
  ;; Create subnet in referenced VPC
  (setv app-subnet
    (aws.ec2.Subnet "app-subnet"
      :vpc-id vpc-id
      :cidr-block "10.0.3.0/24"
      :availability-zone "us-west-2a"
      :map-public-ip-on-launch True))
  
  (pulumi.export "subnet_id" (. app-subnet id)))

;; For production stack, create base infrastructure
(when (= stack "prod")
  ;; Create VPC
  (setv main-vpc
    (aws.ec2.Vpc "main"
      :cidr-block "10.0.0.0/16"
      :enable-dns-hostnames True
      :enable-dns-support True))
  
  ;; Create Internet Gateway
  (setv igw
    (aws.ec2.InternetGateway "main"
      :vpc-id (. main-vpc id)))
  
  ;; Export for other stacks to reference
  (pulumi.export "vpc_id" (. main-vpc id))
  (pulumi.export "igw_id" (. igw id)))