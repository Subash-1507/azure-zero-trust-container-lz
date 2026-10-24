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
  description = "Your current public IP for just-in-time access (API server, Key Vault, Storage). Empty = door closed."
  type        = string
  default     = ""

  validation {
    condition     = var.admin_ip == "" || (can(cidrhost("${var.admin_ip}/32", 0)) && var.admin_ip != "0.0.0.0")
    error_message = "Give a single public IPv4 address, e.g. 20.1.2.3, or leave it empty."
  }
}

variable "aks_node_size" {
  description = "VM size of the single system node (x64, 4 vCPU, 16 GB; see ADR 0001)."
  type        = string
  default     = "Standard_B4s_v2"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes minor version; patches are applied automatically."
  type        = string
  default     = "1.36"
}
