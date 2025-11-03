variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "multi-cloud-devsecops"
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Subnet address prefixes"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "subnet_names" {
  description = "Subnet names"
  type        = list(string)
  default     = ["aks-subnet", "appgw-subnet"]
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.31.11"
}

variable "aks_node_vm_size" {
  description = "VM size for AKS node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_node_count" {
  description = "Number of nodes in AKS node pool"
  type        = number
  default     = 2
}

variable "aks_node_min_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "aks_node_max_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 4
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "multi-cloud-devsecops"
    ManagedBy = "Terraform"
  }
}
