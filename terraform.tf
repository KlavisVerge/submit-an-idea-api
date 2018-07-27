terraform {
  backend "local" {
    path = "tf_backend/submit-an-idea-api.tfstate"
  }
}

variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "REST_API_ID" {}
variable "PARENT_ID" {}

data "aws_iam_role" "role" {
  name = "apis-for-all-service-account"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

resource "aws_dynamodb_table" "submit-an-idea" {
  name           = "submit-an-idea"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "email"
  range_key      = "rangekey"

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "rangekey"
    type = "S"
  }

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.submit-an-idea.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_read_target.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.submit-an-idea.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_write_target.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_write_target.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_api_gateway_resource" "submit-an-idea-api-resource" {
  rest_api_id = "${var.REST_API_ID}"
  parent_id   = "${var.PARENT_ID}"
  path_part   = "submit-an-idea-api"
}

resource "aws_lambda_function" "submit-an-idea-api-function" {
  filename      = "submit-an-idea-api.zip"
  function_name = "submit-an-idea-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/submit-an-idea-api.handler"
  source_code_hash = "${base64sha256(file("submit-an-idea-api.zip"))}"
  runtime          = "nodejs6.10"
  timeout          = 20
}

resource "aws_lambda_permission" "submit-an-idea-permission" {
  function_name = "${aws_lambda_function.submit-an-idea-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "submit-an-idea-api-method-post" {
  rest_api_id   = "${var.REST_API_ID}"
  resource_id   = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "submit-an-idea-api-integration" {
  rest_api_id             = "${var.REST_API_ID}"
  resource_id             = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.submit-an-idea-api-function.invoke_arn}"
}

module "CORS_FUNCTION_DETAILS" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  rest_api_id = "${var.REST_API_ID}"
}
