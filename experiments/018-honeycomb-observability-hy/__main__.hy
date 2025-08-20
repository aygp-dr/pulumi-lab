;; Honeycomb.io observability setup in Hy
;; Based on https://www.pulumi.com/registry/packages/honeycombio/

(import pulumi)
(import [pulumi-honeycombio :as honeycombio])
(import [pulumi-aws :as aws])

;; Configuration
(setv config (pulumi.Config))
(setv dataset (config.require "dataset"))
(setv environment (pulumi.get-stack))
(setv app-name (config.get "app-name" "workshop"))

;; Create Honeycomb dataset
(setv workshop-dataset
  (honeycombio.Dataset "workshop-dataset"
    :name dataset
    :description f"Dataset for {app-name} {environment} observability"))

;; Create a simple marker
(setv deployment-marker
  (honeycombio.Marker "deployment"
    :message f"Deployment of {app-name} to {environment}"
    :dataset dataset
    :url "https://github.com/aygp-dr/pulumi-lab"))

;; Create SLO for application performance
(setv response-time-slo
  (honeycombio.Slo "response-time"
    :name f"{app-name}-{environment}-response-time"
    :description "API response time SLO"
    :dataset dataset
    :sli {:alias "p95_response_time"
          :column "duration_ms"
          :op "P95"}
    :target-percentage 99.5
    :time-period 30))

;; Create derived column for better analysis
(setv status-code-category
  (honeycombio.DerivedColumn "status-category"
    :alias "status_category" 
    :expression "IF($status_code >= 500, \"error\", IF($status_code >= 400, \"client_error\", \"success\"))"
    :dataset dataset
    :description "Categorize HTTP status codes"))

;; Create query for error rates
(setv error-rate-query
  (honeycombio.Query "error-rate"
    :dataset dataset
    :query-json (pulumi.Output.json-stringify
      {:breakdowns ["status_category"]
       :calculations [{:op "COUNT"}
                      {:op "RATE_AVG"
                       :column "status_category"
                       :argument "error"}]
       :filters [{:column "status_category"
                  :op "exists"}]
       :time_range 3600  ;; 1 hour
       :granularity 300  ;; 5 minutes
       :limit 1000})))

;; Create board for monitoring
(setv monitoring-board
  (honeycombio.Board "monitoring"
    :name f"{app-name}-{environment}-monitoring"
    :description f"Monitoring dashboard for {app-name}"
    :style "visual"))

;; Create query specification for the board
(setv board-query-spec
  (honeycombio.QuerySpec "latency-spec"
    :dataset dataset
    :query-json (pulumi.Output.json-stringify
      {:breakdowns ["endpoint"]
       :calculations [{:op "P95"
                       :column "duration_ms"}
                      {:op "COUNT"}]
       :filters [{:column "duration_ms"
                  :op ">"
                  :value 0}]
       :time_range 1800
       :granularity 60})))

;; Create board query using the spec
(setv latency-board-query
  (honeycombio.BoardQuery "latency-query"
    :board-id (. monitoring-board id)
    :query-spec-id (. board-query-spec id)
    :graph-settings {:graph-type "line"
                     :y-axis {:label "Response Time (ms)"
                             :min 0}
                     :x-axis {:label "Time"}}))

;; Create webhook for alerting
(setv slack-webhook
  (honeycombio.Webhook "slack-alerts"
    :name f"{app-name}-slack-webhook"
    :webhook-url (config.require-secret "slack-webhook-url")
    :shared False))

;; Create trigger for high error rate
(setv error-rate-trigger
  (honeycombio.Trigger "high-error-rate"
    :name f"{app-name}-{environment}-high-error-rate"
    :description "Alert when error rate exceeds 5%"
    :dataset dataset
    :query-json (pulumi.Output.json-stringify
      {:calculations [{:op "RATE_AVG"
                       :column "status_category"
                       :argument "error"}]
       :time_range 900  ;; 15 minutes
       :filters [{:column "status_category"
                  :op "exists"}]})
    :threshold {:op ">"
                :value 0.05}  ;; 5% error rate
    :alert-type "on_change"
    :frequency 300  ;; Check every 5 minutes
    :disabled False))

;; Create burn alert for SLO
(setv slo-burn-alert
  (honeycombio.BurnAlert "slo-burn"
    :slo-id (. response-time-slo id)
    :alert-type "slow_burn"
    :exhaustion-minutes 60
    :webhook-id (. slack-webhook id)))

;; Environment-specific configuration
(setv env-config
  (cond
    [(= environment "prod")
     {:alert-threshold 0.01  ;; 1% error rate for prod
      :slo-target 99.9
      :frequency 60}]  ;; Check every minute
    [(= environment "staging") 
     {:alert-threshold 0.05  ;; 5% error rate for staging
      :slo-target 99.5
      :frequency 300}]  ;; Check every 5 minutes
    [True
     {:alert-threshold 0.1   ;; 10% error rate for dev
      :slo-target 95.0
      :frequency 900}]))  ;; Check every 15 minutes

;; Custom column for user tracking
(setv user-activity-column
  (honeycombio.DerivedColumn "user-activity"
    :alias "user_activity_score"
    :expression "IF($user_id, 1, 0) + IF($session_id, 1, 0) + IF($page_views > 0, 1, 0)"
    :dataset dataset
    :description "Score user activity based on multiple factors"))

;; Query annotation for deployment tracking
(setv deployment-annotation
  (honeycombio.QueryAnnotation "deployment-annotation"
    :name f"Deployment {environment}"
    :description f"Track deployments for {app-name}"
    :query-id (. error-rate-query id)))

;; Create environment-specific marker
(setv environment-marker
  (honeycombio.Marker "environment-setup"
    :message f"Environment {environment} configured with Honeycomb observability"
    :dataset dataset
    :type "deploy"
    :url f"https://ui.honeycomb.io/teams/workshop/datasets/{dataset}"))

;; Lambda function instrumentation example
(when (config.get-bool "enable-lambda")
  ;; This would typically be done in application code
  (setv lambda-marker
    (honeycombio.Marker "lambda-instrumented"
      :message f"Lambda functions instrumented for {environment}"
      :dataset dataset
      :type "deploy")))

;; Database query optimization tracking
(setv db-performance-column
  (honeycombio.DerivedColumn "db-performance"
    :alias "db_query_efficiency"
    :expression "IF($db_query_time_ms > 1000, \"slow\", IF($db_query_time_ms > 100, \"medium\", \"fast\"))"
    :dataset dataset
    :description "Categorize database query performance"))

;; API endpoint performance tracking
(setv endpoint-performance-query
  (honeycombio.Query "endpoint-performance"
    :dataset dataset
    :query-json (pulumi.Output.json-stringify
      {:breakdowns ["endpoint" "method"]
       :calculations [{:op "P50" :column "duration_ms"}
                      {:op "P95" :column "duration_ms"} 
                      {:op "P99" :column "duration_ms"}
                      {:op "MAX" :column "duration_ms"}
                      {:op "COUNT"}]
       :filters [{:column "endpoint" :op "exists"}
                 {:column "method" :op "in" :value ["GET" "POST" "PUT" "DELETE"]}]
       :orders [{:column "duration_ms" :op "P95" :order "desc"}]
       :time_range 7200  ;; 2 hours
       :limit 50})))

;; Feature flag analysis
(setv feature-flag-analysis
  (honeycombio.DerivedColumn "feature-impact"
    :alias "feature_flag_impact"
    :expression "CONCAT($feature_flag_name, \":\", IF($feature_enabled, \"enabled\", \"disabled\"))"
    :dataset dataset
    :description "Track feature flag impact on performance"))

;; Exports
(pulumi.export "dataset-name" (. workshop-dataset name))
(pulumi.export "dataset-slug" dataset)
(pulumi.export "slo-id" (. response-time-slo id))
(pulumi.export "board-id" (. monitoring-board id))
(pulumi.export "webhook-id" (. slack-webhook id))
(pulumi.export "trigger-id" (. error-rate-trigger id))

;; Dashboard URLs
(pulumi.export "honeycomb-dashboard-url" 
  f"https://ui.honeycomb.io/teams/workshop/datasets/{dataset}")
(pulumi.export "board-url"
  (pulumi.Output.concat 
    "https://ui.honeycomb.io/teams/workshop/boards/"
    (. monitoring-board id)))

;; Configuration summary
(pulumi.export "observability-config"
  {:dataset dataset
   :environment environment
   :app-name app-name
   :slo-target (get env-config :slo-target)
   :alert-threshold (get env-config :alert-threshold)
   :check-frequency (get env-config :frequency)})

;; Sample instrumentation code
(pulumi.export "sample-instrumentation"
  {:python "import beeline\nbeeline.init(writekey='your-key', dataset='{dataset}', service_name='{app-name}')"
   :javascript "const beeline = require('honeycomb-beeline');\nbeeline({writeKey: 'your-key', dataset: '{dataset}', serviceName: '{app-name}'});"
   :go "import \"github.com/honeycombio/beeline-go\"\nbeeline.Init(beeline.Config{WriteKey: \"your-key\", Dataset: \"{dataset}\", ServiceName: \"{app-name}\"})"})

;; Monitoring checklist
(pulumi.export "monitoring-checklist"
  {:setup ["Dataset created"
           "SLO configured"
           "Dashboard deployed"
           "Alerts configured"
           "Webhooks setup"]
   :instrumentation ["Application instrumented"
                     "Custom fields added"
                     "Error tracking enabled"
                     "Performance metrics collected"]
   :alerting ["Error rate alerts"
              "SLO burn alerts"
              "Performance degradation alerts"
              "Webhook notifications"]})