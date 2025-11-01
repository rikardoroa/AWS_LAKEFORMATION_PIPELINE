output "athena_workgroup_name" {
  description = "Athena workgroup name exposed by the Athena module"
  value       = module.bucket_utils.athena_workgroup
}

output "glue_crawler" {
  description = "Glue Crawler exposed by the glue catalog module"
  value       = module.glue_catalog_utils.crawler
}