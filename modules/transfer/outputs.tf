output "server_id" {
  description = "ID of the pass Transfer Family server."
  value       = aws_transfer_server.pass.id
}

output "server_endpoint" {
  description = "Endpoint of the pass Transfer Family server."
  value       = aws_transfer_server.pass.endpoint
}
