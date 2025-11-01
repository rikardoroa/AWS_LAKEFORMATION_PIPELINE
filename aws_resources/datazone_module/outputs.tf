

output "datazone_domain_id" {
  description = "The DataZone domain id"
  value       = aws_datazone_domain.coinbase_domain.id
}

output "datazone_project_id" {
  description = "The DataZone project id"
  value       = aws_datazone_project.analytics_team.id
}