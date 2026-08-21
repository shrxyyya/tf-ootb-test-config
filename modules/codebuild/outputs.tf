output "project_name" {
  description = "Name of the pass CodeBuild project."
  value       = aws_codebuild_project.pass.name
}
