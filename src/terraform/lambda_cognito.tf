# Create an IAM role for the Lambda function
resource "aws_iam_role" "my_lambda_role" {
  name               = "my-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach a policy to the IAM role to allow Lambda to access Cognito
resource "aws_iam_policy_attachment" "lambda_cognito_policy_attachment" {
  name       = "lambda-cognito-policy-attachment"
  roles      = [aws_iam_role.my_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create a Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.my_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.my_user_pool.id
    }
  }
}

# Create an Amazon Cognito user pool
resource "aws_cognito_user_pool" "my_user_pool" {
  name = var.cognito_user_pool_name
}

# Define IAM policy for the Lambda function to access Cognito
data "aws_iam_policy_document" "lambda_cognito_policy" {
  statement {
    actions   = [
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminDeleteUser",
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminUpdateUserAttributes",
      "cognito-idp:ListUsers"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

# Attach the IAM policy to the Lambda function's role
resource "aws_iam_policy" "lambda_policy" {
  name   = "lambda-cognito-policy"
  policy = data.aws_iam_policy_document.lambda_cognito_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.my_lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "my_api_gateway" {
  name        = var.api_gateway_name
  description = "My API Gateway"
}

# Create a resource for the API Gateway
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.my_api_gateway.root_resource_id
  path_part   = "my-resource"
}

# Create a method for the resource
resource "aws_api_gateway_method" "my_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api_gateway.id
  resource_id   = aws_api_gateway_resource.my_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrate the method with the Lambda function
resource "aws_api_gateway_integration" "my_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api_gateway.id
  resource_id             = aws_api_gateway_resource.my_resource.id
  http_method             = aws_api_gateway_method.my_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda_function.invoke_arn
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "my_deployment" {
  depends_on  = [aws_api_gateway_integration.my_integration]
  rest_api_id = aws_api_gateway_rest_api.my_api_gateway.id
  stage_name  = "prod"
}