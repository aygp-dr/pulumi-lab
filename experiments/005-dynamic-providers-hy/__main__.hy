;; Dynamic Providers - custom resource management in Hy

(import pulumi)
(import [pulumi.dynamic :as dynamic])
(import hashlib)
(import json)

;; Define a custom dynamic provider
(defclass CustomResourceProvider [dynamic.ResourceProvider]
  
  (defn create [self inputs]
    "Create a new custom resource"
    (setv resource-id 
      (.hexdigest 
        (hashlib.sha256 
          (.encode (json.dumps inputs) "utf-8"))))
    
    (setv outs (dict inputs))
    (assoc outs "resource_id" resource-id)
    (assoc outs "status" "created")
    
    (dynamic.CreateResult resource-id outs))
  
  (defn update [self id old-inputs new-inputs]
    "Update existing custom resource"
    (setv outs (dict new-inputs))
    (assoc outs "resource_id" id)
    (assoc outs "status" "updated")
    (assoc outs "previous_version" (get old-inputs "version" "1.0"))
    
    (dynamic.UpdateResult outs))
  
  (defn delete [self id props]
    "Delete custom resource"
    ;; Cleanup logic here
    None))

;; Create provider instance
(setv custom-provider (CustomResourceProvider))

;; Define custom resource class
(defclass CustomResource [dynamic.Resource]
  (defn __init__ [self name props opts None]
    (.__init__ 
      (super) 
      custom-provider 
      name 
      (dict :name name
            :version "2.0"
            :config props)
      opts)))

;; Use the custom resource
(setv my-resource 
  (CustomResource "my-custom-resource"
    {:setting1 "value1"
     :setting2 42
     :enabled True}))

;; Export custom resource outputs
(pulumi.export "custom_resource_id" (. my-resource resource-id))
(pulumi.export "custom_resource_status" (. my-resource status))