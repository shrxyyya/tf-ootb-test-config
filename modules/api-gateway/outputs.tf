output "rest_api_id" {
  description = "ID of the shared REST API."
  value       = aws_api_gateway_rest_api.main.id
}

output "stage_name" {
  description = "Name of the compliant (pass) REST API stage."
  value       = aws_api_gateway_stage.pass.stage_name
}

output "http_api_id" {
  description = "ID of the HTTP (V2) API used for APIGateway.8 route authorization testing."
  value       = aws_apigatewayv2_api.http.id
}
