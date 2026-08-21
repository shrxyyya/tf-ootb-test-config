output "job_name" {
  description = "Name of the pass Glue job."
  value       = aws_glue_job.pass.name
}
