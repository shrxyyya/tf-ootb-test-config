output "environment_name" {
  description = "Name of the compliant (pass) Elastic Beanstalk environment."
  value       = aws_elastic_beanstalk_environment.pass.name
}

output "environment_endpoint" {
  description = "DNS endpoint URL of the compliant (pass) Elastic Beanstalk environment."
  value       = aws_elastic_beanstalk_environment.pass.endpoint_url
}
