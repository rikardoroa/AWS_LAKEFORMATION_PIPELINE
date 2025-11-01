output "athena_workgroup_name" {
  description = "Athena workgroup name exposed by the Athena module"
  value       = module.bucket_utils.athena_workgroup
}