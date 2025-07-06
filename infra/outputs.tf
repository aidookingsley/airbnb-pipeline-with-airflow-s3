output "bucket_name" { value = aws_s3_bucket.images.bucket }
output "table_name"  { value = aws_dynamodb_table.meta.name }
output "lambda_name" { value = aws_lambda_function.store_meta.function_name }
