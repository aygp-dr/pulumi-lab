;; Complete VPC setup in Hy
(import pulumi)
(import [pulumi-aws :as aws])

;; Create VPC
(setv main-vpc
  (aws.ec2.Vpc "main"
    :cidr-block "10.0.0.0/16"
    :enable-dns-hostnames True
    :enable-dns-support True
    :tags {:Name "workshop-vpc"}))

;; Create subnets
(setv public-subnet
  (aws.ec2.Subnet "public"
    :vpc-id (. main-vpc id)
    :cidr-block "10.0.1.0/24"
    :availability-zone "us-west-2a"
    :map-public-ip-on-launch True
    :tags {:Name "public-subnet"}))

(setv private-subnet
  (aws.ec2.Subnet "private"
    :vpc-id (. main-vpc id)
    :cidr-block "10.0.2.0/24"
    :availability-zone "us-west-2a"
    :tags {:Name "private-subnet"}))

;; Internet Gateway
(setv igw
  (aws.ec2.InternetGateway "main"
    :vpc-id (. main-vpc id)
    :tags {:Name "main-igw"}))

;; Route table
(setv public-route-table
  (aws.ec2.RouteTable "public"
    :vpc-id (. main-vpc id)
    :routes [{:cidr-block "0.0.0.0/0"
              :gateway-id (. igw id)}]
    :tags {:Name "public-routes"}))

;; Associate route table
(setv route-association
  (aws.ec2.RouteTableAssociation "public"
    :subnet-id (. public-subnet id)
    :route-table-id (. public-route-table id)))

;; NAT Gateway for private subnet
(setv eip
  (aws.ec2.Eip "nat"
    :domain "vpc"
    :tags {:Name "nat-eip"}))

(setv nat-gateway
  (aws.ec2.NatGateway "main"
    :subnet-id (. public-subnet id)
    :allocation-id (. eip id)
    :tags {:Name "main-nat"}))

;; Outputs
(pulumi.export "vpc_id" (. main-vpc id))
(pulumi.export "public_subnet_id" (. public-subnet id))
(pulumi.export "private_subnet_id" (. private-subnet id))
