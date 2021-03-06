variable "description" {
  description = "Description of this API"
  default     = "Dynamically Managing IAM Groups API"
}

variable "name" {
  default     = "terraform-aws-authenticating-iam"
  description = "Creates a unique name beginning with the specified prefix, useful for searching later"
}

variable "bucket_name" {
  description = "S3 Bucketname used to store arguments"
}

variable "deployment_stage" {
  default     = "dev"
  description = "Api deployment stages, ex: staging, production..."
}

variable "time_to_expire" {
  default     = 600
  description = "Time to expiry for every rule (in seconds)"
}

variable "log_level" {
  default     = "INFO"
  description = "Set level of Cloud Watch Log to INFO or DEBUG"
}
