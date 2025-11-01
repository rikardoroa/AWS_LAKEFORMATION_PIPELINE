variable "curated_bucket" {
  description = "Curated bucket"
  type        = string
  default     = "coinbase-currency-data"
}

variable "domain_execution_role_name"{
  type = string

}

variable "domain_environment_role_name"{
  type = string
}