output "zone_id" {
  description = "Zone ID of the pass Route53 hosted zone."
  value       = aws_route53_zone.pass.zone_id
}

output "zone_name" {
  description = "Name of the pass Route53 hosted zone."
  value       = aws_route53_zone.pass.name
}
