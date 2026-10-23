variable "location" {
  description = "Azure region. Limited to the regions the Azure for Students policy allows."
  type        = string
  default     = "koreacentral"

  validation {
    condition     = contains(["southeastasia", "uaenorth", "koreacentral", "malaysiawest", "austriaeast"], var.location)
    error_message = "This subscription's policy only allows southeastasia, uaenorth, koreacentral, malaysiawest or austriaeast."
  }
}

variable "cost_center" {
  description = "CostCenter tag value applied to every resource."
  type        = string
  default     = "portfolio"
}

variable "admin_ip" {
  description = "Your current public IP, allowed through the Key Vault and Storage firewalls only while Terraform creates them."
  type        = string

  validation {
    condition     = can(cidrhost("${var.admin_ip}/32", 0)) && var.admin_ip != "0.0.0.0"
    error_message = "Give a single public IPv4 address, e.g. 20.1.2.3."
  }
}
