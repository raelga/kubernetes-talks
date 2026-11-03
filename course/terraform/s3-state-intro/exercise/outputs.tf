output "exercise_bucket_name" {
  value = awscc_s3_bucket.exercise.bucket_name
}

output "hello_object_id" {
  value = aws_s3_object.hello.id
}
