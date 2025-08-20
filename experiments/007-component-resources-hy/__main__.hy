;; Component Resources - higher-level abstractions in Hy

(import pulumi)
(import [pulumi-aws :as aws])

;; Define a component resource for a static website
(defclass StaticWebsite [pulumi.ComponentResource]
  
  (defn __init__ [self name domain-name opts None]
    ;; Initialize parent
    (.__init__ (super) "custom:web:StaticWebsite" name {} opts)
    
    ;; Create S3 bucket for website content
    (setv website-bucket
      (aws.s3.BucketV2 f"{name}-bucket"
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Configure bucket for static website hosting
    (setv website-config
      (aws.s3.BucketWebsiteConfigurationV2 f"{name}-website"
        :bucket (. website-bucket id)
        :index-document {:suffix "index.html"}
        :error-document {:key "404.html"}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Disable public access block for website
    (setv public-access
      (aws.s3.BucketPublicAccessBlock f"{name}-public-access"
        :bucket (. website-bucket id)
        :block-public-acls False
        :block-public-policy False
        :ignore-public-acls False
        :restrict-public-buckets False
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Create bucket policy for public read
    (setv policy-doc
      (aws.iam.get-policy-document
        :statements [{:sid "PublicRead"
                      :effect "Allow"
                      :principals [{:type "*"
                                   :identifiers ["*"]}]
                      :actions ["s3:GetObject"]
                      :resources [(pulumi.Output.concat
                                  (. website-bucket arn) "/*")]}]))
    
    (setv bucket-policy
      (aws.s3.BucketPolicy f"{name}-policy"
        :bucket (. website-bucket id)
        :policy (. policy-doc json)
        :opts (pulumi.ResourceOptions 
               :parent self
               :depends-on [public-access])))
    
    ;; Create CloudFront distribution
    (setv cdn
      (aws.cloudfront.Distribution f"{name}-cdn"
        :enabled True
        :default-root-object "index.html"
        :origins [{:domain-name (. website-bucket bucket-regional-domain-name)
                   :origin-id (. website-bucket id)
                   :s3-origin-config {:origin-access-identity ""}}]
        :default-cache-behavior 
          {:target-origin-id (. website-bucket id)
           :viewer-protocol-policy "redirect-to-https"
           :allowed-methods ["GET" "HEAD" "OPTIONS"]
           :cached-methods ["GET" "HEAD" "OPTIONS"]
           :forwarded-values {:query-string False
                              :cookies {:forward "none"}}
           :min-ttl 0
           :default-ttl 86400
           :max-ttl 31536000}
        :restrictions {:geo-restriction {:restriction-type "none"}}
        :viewer-certificate {:cloudfront-default-certificate True}
        :opts (pulumi.ResourceOptions :parent self)))
    
    ;; Store outputs
    (setv self.bucket website-bucket)
    (setv self.website-url 
      (pulumi.Output.concat "https://" (. cdn domain-name)))
    
    ;; Register outputs
    (self.register-outputs
      {:bucket-name (. website-bucket bucket)
       :website-url self.website-url
       :cdn-domain (. cdn domain-name)})))

;; Create instances of the component
(setv portfolio-site
  (StaticWebsite "portfolio" "portfolio.example.com"))

(setv blog-site
  (StaticWebsite "blog" "blog.example.com"))

;; Export component outputs
(pulumi.export "portfolio_url" (. portfolio-site website-url))
(pulumi.export "blog_url" (. blog-site website-url))