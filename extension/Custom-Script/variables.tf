variable "location" {
  description = "Location of resources"
  type        = string
  default     = "West Europe"
}
variable "location_code" {
  description = "Location code identifier"
  type        = string
  default     = "weu"
}
variable "shared_kv_name" {
  description = "name of the KV"
  type        = string
  default     = "keyvault"
}
variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default = {
    env   = "Test"
  }
}
