;; AWS EC2 instance with security group in Hy

(import pulumi)
(import pulumi-aws :as aws)

;; Create security group for web access
(setv web-sg 
  (aws.ec2.SecurityGroup "web-sg"
    :description "Enable HTTP access"
    :ingress [(dict :protocol "tcp"
                    :from-port 80
                    :to-port 80
                    :cidr-blocks ["0.0.0.0/0"])]))

;; Create EC2 instance
(setv web-server
  (aws.ec2.Instance "web-server"
    :ami "ami-0319ef1a70c93d5c8"
    :instance-type "t2.micro"
    :vpc-security-group-ids [(. web-sg id)]))

;; Export outputs
(pulumi.export "public_ip" (. web-server public-ip))
(pulumi.export "public_dns" (. web-server public-dns))