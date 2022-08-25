variable "repository_name" {
  description = "ECR repository name"
  type        = string
  default     = null
}

variable "access_key" {
  description = "AWS ACCESS_KEY_ID"
  type        = string
  default     = null
}

variable "secret_key" {
  description = "AWS SECRET_ACCESS_KEY"
  type        = string
  default     = null
}
