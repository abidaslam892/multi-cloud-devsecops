# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-rg"
    }
  )
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-vnet"
    }
  )
}

# Subnets
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes[0]]
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_name, "-", "")}${var.environment}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-acr"
    }
  )
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.aks_kubernetes_version

  default_node_pool {
    name                = "default"
    vm_size             = var.aks_node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.aks_node_min_count
    max_count           = var.aks_node_max_count
    os_disk_size_gb     = 30

    tags = merge(
      var.tags,
      {
        Environment = var.environment
      }
    )
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "azure"
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-aks"
    }
  )
}

# Role Assignment: Allow AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# Network Security Group for AKS
resource "azurerm_network_security_group" "aks" {
  name                = "${var.project_name}-${var.environment}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-aks-nsg"
    }
  )
}

# Associate NSG with AKS subnet
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
