# Academy supplies this profile and its LabRole permissions.
# This lab does not create roles or change IAM policies.
data "aws_iam_instance_profile" "app" {
  name = var.instance_profile_name
}
