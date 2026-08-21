output "wafv2_web_acl_arn" {
  description = "ARN of the pass WAFv2 Web ACL."
  value       = aws_wafv2_web_acl.pass.arn
}

output "wafv2_web_acl_id" {
  description = "ID of the pass WAFv2 Web ACL."
  value       = aws_wafv2_web_acl.pass.id
}
