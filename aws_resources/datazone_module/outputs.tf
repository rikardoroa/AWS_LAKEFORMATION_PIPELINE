

output "datazone_domain_id" {
  description = "The DataZone domain id"
  value       = aws_datazone_domain.coinbase_domain.id
}

output "datazone_project_id" {
  description = "The DataZone project id"
  value       = aws_datazone_project.analytics_team.id
}

output "domain_environment_role_name"{
  value = aws_iam_role.datazone_environment_role.name
}

output "domain_execution_role_name"{
  value = aws_iam_role.datazone_domain_execution_role.name
}