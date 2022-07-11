variable "vnet_name" {
  description = "Name of the VNET"
  type        = string
  default     = "vnet1"
}

variable "rg_name" {
  description = "Name of the VNET Shared Resource Group"
  type        = string
  default     = "rg"
}

variable "subnet_name" {
  description = "Name of the Subnet"
  type        = string
  default     = "subnet1"
}

variable "nic_name" {
  description = "Name of the Subnet"
  type        = string
  default     = "nic1"
}

variable "nsg_name" {
  description = "Name of the Subnet"
  type        = string
  default     = "nsg1"
}

variable "location" {
  description = "Location of resources"
  type        = string
  default     = "francecentral"
}

variable "location_code" {
  description = "Location code identifier"
  type        = string
  default     = "frc"
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default = {
    env   = "Test"
    state = "donotdelete"
    owner = "Uma"
  }
}

variable "vm_size" {
  description = "Size of the Azure VM"
  type        = string
  default     = "Standard_D4_v3"
}

