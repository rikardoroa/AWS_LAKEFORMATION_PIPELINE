output "athena_workgroup_name" {
  description = "Athena workgroup name exposed by the Athena module"
  value       = module.bucket_utils.athena_workgroup
}

output "glue_crawler" {
  description = "Glue Crawler exposed by the glue catalog module"
  value       = module.glue_catalog_utils.crawler
}


output "datazone_domain_id" {
  description = "The DataZone domain id"
  value       = module.datazone_utils.datazone_domain_id
}

output "datazone_project_id" {
  description = "The DataZone project id"
  value       = module.datazone_utils.datazone_project_id
}