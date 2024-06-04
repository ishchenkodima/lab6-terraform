variable "aws_region" {
  default = "eu-central-1"
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = var.aws_region
  s3_use_path_style           = false
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = false

  endpoints {
    cloudwatch = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    s3         = "http://s3.localhost.localstack.cloud:4566"
    iam        = "http://localhost:4566"
  }
}

# S3 Bucket Definitions
resource "aws_s3_bucket" "start_bucket" {
  bucket = "s3-start"
}

resource "aws_s3_bucket_lifecycle_configuration" "start_bucket_lifecycle" {
  bucket = aws_s3_bucket.start_bucket.id

  rule {
    id      = "cleanup-rule"
    status  = "Enabled"
    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket" "finish_bucket" {
  bucket = "s3-finish"
}

# Archive Python Code
data "archive_file" "python_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/Python"
  output_path = "${path.module}/handler.zip"
}

# IAM Role and Policy for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_basic_execution_role" {
  name       = "lambda-basic-execution"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.lambda_role.name]
}

# Lambda Function Definition
resource "aws_lambda_function" "s3_copy_lambda" {
  filename         = data.archive_file.python_code_zip.output_path
  function_name    = "s3-copy-lambda"
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = data.archive_file.python_code_zip.output_base64sha256

  environment {
    variables = {
      REGION = var.aws_region
    }
  }
}

# Lambda Permission for S3 Bucket
resource "aws_lambda_permission" "s3_bucket_permission" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_copy_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.start_bucket.arn
}

# S3 Bucket Notification for Lambda Trigger
resource "aws_s3_bucket_notification" "start_bucket_notification" {
  bucket = aws_s3_bucket.start_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_bucket_permission]
}
