;; Serverless API with Lambda and API Gateway
(import pulumi)
(import [pulumi-aws :as aws])
(import json)

;; Lambda execution role
(setv lambda-role
  (aws.iam.Role "lambda-role"
    :assume-role-policy (json.dumps
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "lambda.amazonaws.com"}
                    :Effect "Allow"}]})))

;; Attach basic execution policy
(setv policy-attachment
  (aws.iam.RolePolicyAttachment "lambda-logs"
    :role (. lambda-role name)
    :policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"))

;; Lambda function code
(setv lambda-code """
def handler(event, context):
    import json
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Pulumi Lambda!',
            'path': event.get('path', '/'),
            'method': event.get('httpMethod', 'GET')
        })
    }
""")

;; Create Lambda function
(setv api-lambda
  (aws.lambda.Function "api"
    :code (pulumi.AssetArchive 
            {:".": (pulumi.FileArchive "./lambda.zip")})
    :role (. lambda-role arn)
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 30
    :memory-size 256
    :environment {:variables {:ENV "workshop"}}))

;; API Gateway
(setv api-gw
  (aws.apigatewayv2.Api "http-api"
    :protocol-type "HTTP"
    :cors-configuration 
      {:allow-origins ["*"]
       :allow-methods ["GET" "POST" "OPTIONS"]
       :allow-headers ["*"]}))

;; Lambda integration
(setv integration
  (aws.apigatewayv2.Integration "lambda"
    :api-id (. api-gw id)
    :integration-type "AWS_PROXY"
    :integration-uri (. api-lambda invoke-arn)))

;; Routes
(setv default-route
  (aws.apigatewayv2.Route "default"
    :api-id (. api-gw id)
    :route-key "$default"
    :target (pulumi.Output.concat "integrations/" (. integration id))))

;; Stage
(setv stage
  (aws.apigatewayv2.Stage "dev"
    :api-id (. api-gw id)
    :name "dev"
    :auto-deploy True))

;; Lambda permission for API Gateway
(setv lambda-permission
  (aws.lambda.Permission "api-gw"
    :action "lambda:InvokeFunction"
    :function (. api-lambda name)
    :principal "apigateway.amazonaws.com"
    :source-arn (pulumi.Output.concat 
                  (. api-gw execution-arn) "/*/*")))

;; Outputs
(pulumi.export "api_endpoint" (. api-gw api-endpoint))
(pulumi.export "lambda_arn" (. api-lambda arn))
