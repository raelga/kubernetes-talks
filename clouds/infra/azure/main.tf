terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.cluster_name}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_kubernetes_cluster" "lab" {
  name     = var.cluster_name
  location = azurerm_resource_group.lab.location

  resource_group_name = azurerm_resource_group.lab.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  api_server_access_profile {
    authorized_ip_ranges = var.cluster_api_allowed_cidrs
  }

  node_provisioning_profile {
    mode               = "Manual"
    default_node_pools = "None"
  }
  sku_tier = "Free"

  default_node_pool {
    name                        = "system"
    node_count                  = 1
    vm_size                     = "Standard_B2s"
    os_disk_size_gb             = 30
    type                        = "VirtualMachineScaleSets"
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  tags = local.common_tags
}

locals {
  common_tags = {
    Project   = "kubernetes-clouds-lab"
    ManagedBy = "Terraform"
  }
}
