;; Multi-stack application deployment
(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-kubernetes :as k8s])

(setv config (pulumi.Config))
(setv stack (pulumi.get-stack))

;; Stack-specific configuration
(cond
  ;; Development stack
  [(= stack "dev")
   (do
     (setv instance-type "t3.micro")
     (setv replica-count 1)
     (setv environment "development"))]
  
  ;; Staging stack
  [(= stack "staging")
   (do
     (setv instance-type "t3.small")
     (setv replica-count 2)
     (setv environment "staging"))]
  
  ;; Production stack
  [(= stack "prod")
   (do
     (setv instance-type "t3.medium")
     (setv replica-count 3)
     (setv environment "production"))])

;; Shared infrastructure component
(defclass ApplicationStack [pulumi.ComponentResource]
  
  (defn __init__ [self name opts None]
    (super.__init__ "custom:app:Stack" name {} opts)
    
    ;; ECS Cluster
    (setv cluster
      (aws.ecs.Cluster f"{name}-cluster"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Application Load Balancer
    (setv alb
      (aws.lb.LoadBalancer f"{name}-alb"
        :load-balancer-type "application"
        :subnets (config.require-object "subnet_ids")
        :security-groups [(config.require "alb_sg_id")]
        :tags {:Environment environment
               :Stack stack}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Target Group
    (setv target-group
      (aws.lb.TargetGroup f"{name}-tg"
        :port 80
        :protocol "HTTP"
        :vpc-id (config.require "vpc_id")
        :target-type "ip"
        :health-check {:enabled True
                       :path "/health"
                       :interval 30}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Listener
    (setv listener
      (aws.lb.Listener f"{name}-listener"
        :load-balancer-arn (. alb arn)
        :port 80
        :protocol "HTTP"
        :default-actions [{:type "forward"
                          :target-group-arn (. target-group arn)}]
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Store references
    (setv self.cluster-id (. cluster id))
    (setv self.alb-dns (. alb dns-name))
    
    (self.register-outputs
      {:cluster_id self.cluster-id
       :alb_endpoint self.alb-dns})))

;; Deploy stack
(setv app-stack (ApplicationStack environment))

;; Stack outputs
(pulumi.export "environment" environment)
(pulumi.export "endpoint" (. app-stack alb-dns))
(pulumi.export "replicas" replica-count)
