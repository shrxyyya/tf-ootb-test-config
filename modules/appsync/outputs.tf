output "graphql_api_id" {
  description = "ID of the pass AppSync GraphQL API."
  value       = aws_appsync_graphql_api.pass.id
}

output "graphql_api_uris" {
  description = "Map of URIs for the pass AppSync GraphQL API."
  value       = aws_appsync_graphql_api.pass.uris
}
