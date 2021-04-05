resource "aws_iam_role" "this" {
  name               = "aws-lambda-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/source"
  output_path = "${path.module}/.temp/source.zip"
}

resource "aws_lambda_layer_version" "this" {
  layer_name       = "aws-lambda-${var.name}-custom-layer"
  filename         = "${path.module}/source/aws-layer/custom-layer.zip"
  source_code_hash = filebase64sha256("${path.module}/source/aws-layer/custom-layer.zip")
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  filename         = data.archive_file.source.output_path
  handler          = "lambda_function.lambda_handler"
  description      = var.description
  source_code_hash = data.archive_file.source.output_base64sha256
  runtime          = "python3.8"
  memory_size      = 256
  timeout          = 60
  role             = aws_iam_role.this.arn
  layers = [
    aws_lambda_layer_version.this.arn,
  ]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = [
      "content-type",
    ]
    allow_methods = [
      "POST",
    ]
    allow_origins = [
      "*",
    ]
  }
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.this.arn
    format = jsonencode(
      {
        httpMethod              = "$context.httpMethod"
        ip                      = "$context.identity.sourceIp"
        protocol                = "$context.protocol"
        requestId               = "$context.requestId"
        requestTime             = "$context.requestTime"
        responseLength          = "$context.responseLength"
        routeKey                = "$context.routeKey"
        status                  = "$context.status"
        integrationStatus       = "$context.integration.integrationStatus"
        integrationErrorMessage = "$context.integration.error"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "this" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = var.description
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.this.invoke_arn
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_lambda_permission" "this" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}
