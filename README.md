# create-aws-rest-api-to-s3

This script is a Bash shell script for accessing "S3" from "AWS API Gateway".


## Author Information

[genzouw](https://genzouw.com)

* Twitter   : @genzouw ( https://twitter.com/genzouw )
* Facebook  : genzouw ( https://www.facebook.com/genzouw )
* Gmail     : genzouw@gmail.com


## Requirements

The following tools are required to run this script:

* [aws-cli](https://aws.amazon.com/jp/cli/)
* [jq](https://stedolan.github.io/jq/)


## Installation

Please see to "Requirements".

## Usage

Before execution, change the following variables to your preferred values.

* `IAM_ROLE_NAME`
* `S3_BUCKET_NAME`
* `APIGATEWAY_RESTAPI_NAME`
* `AWS_DEFAULT_REGION`

Alternatively, add the environment variable settings at the beginning of the command as follows:

```bash
$ IAM_ROLE_NAME='value1' \
    S3_BUCKET_NAME='value2' \
    APIGATEWAY_RESTAPI_NAME='value2' \
    create-aws-rest-api-to-s3.sh
```


## Configuration

Environmental Variables are follows:

`IAM_ROLE_NAME`
`S3_BUCKET_NAME`
`APIGATEWAY_RESTAPI_NAME`
`AWS_DEFAULT_REGION`


## Relase Note

| date       | version | note           |
| ---        | ---     | ---            |
| 2019-03-16 | 0.1     | first release. |


## License

This software is released under the MIT License, see LICENSE.


