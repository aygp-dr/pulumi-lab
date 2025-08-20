;; Custom provider for external services
(import pulumi)
(import [pulumi.dynamic :as dynamic])
(import requests)
(import time)

;; Custom DNS provider
(defclass DnsProvider [dynamic.ResourceProvider]
  
  (defn create [self inputs]
    "Create DNS record in external system"
    (setv record-type (get inputs "type"))
    (setv name (get inputs "name"))
    (setv value (get inputs "value"))
    
    ;; Simulate API call
    (setv record-id f"{name}-{(int (time.time))}")
    
    ;; Would normally call external API here
    ;; (requests.post "https://dns-api.example.com/records" ...)
    
    (dynamic.CreateResult 
      record-id
      {:id record-id
       :name name
       :type record-type
       :value value
       :status "active"}))
  
  (defn update [self id old new]
    "Update DNS record"
    (dynamic.UpdateResult
      {:id id
       :name (get new "name")
       :type (get new "type")
       :value (get new "value")
       :status "updated"}))
  
  (defn delete [self id props]
    "Delete DNS record"
    ;; Would call delete API
    None))

;; DNS record resource
(defclass DnsRecord [dynamic.Resource]
  (defn __init__ [self name props opts None]
    (super.__init__
      (DnsProvider)
      name
      {:name (get props "name")
       :type (get props "type")
       :value (get props "value")}
      opts)))

;; Use custom provider
(setv web-dns
  (DnsRecord "web"
    {:name "workshop.example.com"
     :type "A"
     :value "10.0.1.50"}))

(setv api-dns
  (DnsRecord "api"
    {:name "api.workshop.example.com"
     :type "CNAME"
     :value "workshop.example.com"}))

(pulumi.export "web_dns_id" (. web-dns id))
(pulumi.export "api_dns_id" (. api-dns id))
