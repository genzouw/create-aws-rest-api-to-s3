#!/usr/bin/env bash
set -o errexit
set -o nounset

##################################################
# Designed by genzouw ( https://genzouw.com ) from Japan
#   * Twitter   : @genzouw ( https://twitter.com/genzouw )
#   * Facebook  : genzouw ( https://www.facebook.com/genzouw )
#   * Gmail     : genzouw@gmail.com
#
# Please feel free to contact us if you have any questions,
# request for friends, consultation, assistance with development, etc.
##################################################

#-Configuration------------------------------------
# Before execution, change the following variables to your preferred values.
#
# Alternatively, add the environment variable settings at the beginning of the command as follows:
#
#   IAM_ROLE_NAME='value1' \
#     S3_BUCKET_NAME='value2' \
#     APIGATEWAY_RESTAPI_NAME='value2' \
#     create-aws-rest-api-to-s3.sh
#
IAM_ROLE_NAME="${IAM_ROLE_NAME:-ANY_IAM_ROLE_NAME}"
S3_BUCKET_NAME=${S3_BUCKET_NAME:-ANY_S3_BUCKET_NAME}
APIGATEWAY_RESTAPI_NAME=${APIGATEWAY_RESTAPI_NAME:-ANY_APIGATEWAY_RESTAPI_NAME}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-ap-northeast-1}

cat <<EOF
The following tools are required to run this script:

* [aws-cli](https://aws.amazon.com/jp/cli/)
* [jq](https://stedolan.github.io/jq/)

Run the script with the following environment variable values:

* IAM_ROLE_NAME           = "${IAM_ROLE_NAME}"
* S3_BUCKET_NAME          = "${S3_BUCKET_NAME}"
* APIGATEWAY_RESTAPI_NAME = "${APIGATEWAY_RESTAPI_NAME}"
* AWS_DEFAULT_REGION      = "${AWS_DEFAULT_REGION}"


EOF

#----IAM-------------------------------------------
# First create the initial policy file of "API Gateway"
cat <<'EOF' >/tmp/${IAM_ROLE_NAME}-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create a role based on the created policy file. At the same time, save the IAM ROLE ID.
IAM_ROLE_ID=$(
  aws iam create-role \
    --role-name "${IAM_ROLE_NAME}" \
    --assume-role-policy-document file:///tmp/${IAM_ROLE_NAME}-policy.json | jq -r '.Role.RoleId'
)

# Check
if [[ -z $IAM_ROLE_ID ]]; then
  echo 'Could not get ${IAM_ROLE_ID}.'
  exit 255
fi

cat <<EOF
The following AWS objects have been created.
* IAM_ROLE_ID                 = "${IAM_ROLE_ID}"
EOF

aws iam attach-role-policy \
  --role-name "${IAM_ROLE_NAME}" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

#---S3---------------------------------------------
# Create S3 bucket
aws s3 mb s3://${S3_BUCKET_NAME}

#---API Gateway[REST API]--------------------------
# Save the REST API ID
APIGATEWAY_REST_API_ID=$(
  aws apigateway create-rest-api \
    --name "${APIGATEWAY_RESTAPI_NAME}" | jq -r '.id'
)

# Check
if [[ -z $APIGATEWAY_REST_API_ID ]]; then
  echo 'Could not get ${APIGATEWAY_REST_API_ID}.'
  exit 255
fi

cat <<EOF
The following AWS objects have been created.
* APIGATEWAY_REST_API_ID      = "${APIGATEWAY_REST_API_ID}"
EOF

#---API Gateway[Resource]--------------------------
# Save "Root Resource ID"
APIGATEWAY_RESOURCE_ID_ROOT=$(
  aws apigateway get-resources \
    --rest-api-id "$APIGATEWAY_REST_API_ID" | jq -r '.items[0].id'
)

# Save "Resource ID"
APIGATEWAY_RESOURCE_ID_S3_BUCKET_NAME=$(
  aws apigateway create-resource \
    --rest-api-id "${APIGATEWAY_REST_API_ID}" \
    --parent-id "${APIGATEWAY_RESOURCE_ID_ROOT}" \
    --path-part '{s3_bucket_name}' | jq -r '.id'
)

# Save "Resource ID"
APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY=$(
  aws apigateway create-resource \
    --rest-api-id "${APIGATEWAY_REST_API_ID}" \
    --parent-id "${APIGATEWAY_RESOURCE_ID_S3_BUCKET_NAME}" \
    --path-part '{s3_object_key}' | jq -r '.id'
)

# Check
if [[ -z $APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY ]]; then
  echo 'Could not get ${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}.'
  exit 255
fi

cat <<EOF
The following AWS objects have been created.
* APIGATEWAY_RESOURCE_ID_S3_BUCKET_NAME = "${APIGATEWAY_RESOURCE_ID_S3_BUCKET_NAME}"
EOF

cat <<EOF
The following AWS objects have been created.
* APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY  = "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}"
EOF

#---API Gateway[Method]----------------------------
# Enable GET for REST API Resources
aws apigateway put-method \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --authorization-type AWS_IAM \
  --request-parameters "method.request.path.s3_bucket_name=true,method.request.path.s3_object_key=true" \
  --no-api-key-required \
  ;

#---API Gateway[Method Request/Response]-----------
aws apigateway put-method-response \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --status-code 200 \
  --response-models '{"application/json": "Empty"}'

aws apigateway update-method-response \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --status-code 200 \
  --patch-operations op="add",path="/responseParameters/method.response.header.Content-Type",value="false"

aws apigateway put-method-response \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --status-code 400 \
  --response-models '{"application/json": "Empty"}'

aws apigateway put-method-response \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --status-code 500 \
  --response-models '{"application/json": "Empty"}'

aws apigateway put-integration \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --type AWS \
  --integration-http-method GET \
  --uri "arn:aws:apigateway:${AWS_DEFAULT_REGION}:s3:path/{s3_bucket_name}/{s3_object_key}" \
  --credentials $(
    aws iam get-role \
      --role-name "${IAM_ROLE_NAME}" | jq -r '.Role.Arn'
  ) \
  --request-parameters 'integration.request.path.s3_bucket_name=method.request.path.s3_bucket_name,integration.request.path.s3_object_key=method.request.path.s3_object_key'

aws apigateway put-integration-response \
  --rest-api-id "${APIGATEWAY_REST_API_ID}" \
  --resource-id "${APIGATEWAY_RESOURCE_ID_S3_OBJECT_KEY}" \
  --http-method GET \
  --status-code 200 \
  --response-templates '{"application/json": ""}'

cat <<'EOF'
+----------------------------+
|   Process Successful !!!   |
+----------------------------+
EOF

#=================================================
# The MIT License
#
# Copyright (c) {year} {copyright holders}
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#=================================================
