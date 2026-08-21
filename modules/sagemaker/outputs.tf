output "notebook_name" {
  description = "Name of the pass SageMaker notebook instance."
  value       = aws_sagemaker_notebook_instance.pass.name
}

output "model_name" {
  description = "Name of the pass SageMaker model."
  value       = aws_sagemaker_model.pass.name
}
