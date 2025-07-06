terraform {
  required_version = ">=1.6"
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

provider "aws" {
  region = var.region
}

/* 1. S3 bucket with public read and event notification */
resource "aws_s3_bucket" "images" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.images.arn}/*"
    }]
  })
}


/* 2. DynamoDB */
resource "aws_dynamodb_table" "meta" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_id"
  attribute {
    name = "image_id"
    type = "S"
  }
}


/* 3. IAM role for lambda */
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:Assumerole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "dynamodb_write" {
  name = "lambda-dynamodb-write"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.meta.arn
      }
    ]
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "rw" {
  name = "${var.project}-rw"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "S3RW", Effect = "Allow", Action = ["s3:*"], Resource = ["${aws_s3_bucket.images.arn}/*"] },
      { Sid = "DDBRW", Effect = "Allow", Action = ["dynamodb:*"], Resource = [aws_dynamodb_table.meta.arn] }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
        ],
        Resource = aws_dynamodb_table.meta.arn
      }
    ]
  })
}


/* 4. Lambda function */
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda.zip"
}


resource "aws_lambda_function" "store_meta" {
  function_name = "${var.project}-handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_func.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512
  filename      = data.archive_file.lambda.output_path
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.meta.name
    }
  }
}


/* 5. S3 -> lambda notif */
resource "aws_s3_bucket_notification" "trigger" {
  bucket = aws_s3_bucket.images.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.store_meta.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".jpg"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.store_meta.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".png"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.store_meta.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".jpeg"
  }
  depends_on = [aws_lambda_permission.allow_s3]
}


resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.store_meta.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}
