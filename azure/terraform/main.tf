# --- main.tf ---

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~>3.0" }
    random  = { source = "hashicorp/random", version = "~>3.1" }
  }
}
provider "azurerm" {
  features {}
}
data "azurerm_client_config" "current" {}
resource "random_string" "unique" {
  length  = 5
  special = false
  upper   = false
}

locals {
  location      = "eastus"
  unique_suffix = random_string.unique.result
  rg_name       = "capstone-rg-${local.unique_suffix}"
  vnet_name     = "capstone-vnet-${local.unique_suffix}"
  app_nsg_name  = "capstone-nsg-app-${local.unique_suffix}"
  acr_name      = "capstoneacr${local.unique_suffix}"
  kv_name       = "capstone-kv-${local.unique_suffix}"
  aks_name      = "capstone-aks-${local.unique_suffix}"
  identity_name = "capstone-id-${local.unique_suffix}"
  mysql_name    = "capstone-mysql-${local.unique_suffix}"
  redis_name    = "capstone-redis-${local.unique_suffix}"
  cosmos_name   = "capstone-cosmos-${local.unique_suffix}"
  storage_name  = "capstonest${local.unique_suffix}"
  log_analytics_name = "capstone-log-${local.unique_suffix}"
  prometheus_name    = "capstone-monitoring-${local.unique_suffix}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = local.location
}
resource "azurerm_network_security_group" "app_nsg" {
  name                = local.app_nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_subnet" "application_subnet" {
  name                 = "Application-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
# --- Link the NSG to the Application Subnet ---
resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.application_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}
resource "azurerm_subnet" "db_subnet" {
  name                 = "DB-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = local.identity_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "capstone-aks"
  default_node_pool {
    name       = "default"
    vm_size    = "Standard_B2s"
    node_count = 1
    vnet_subnet_id = azurerm_subnet.application_subnet.id 
  }
  identity {
    type         = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_identity.id
  }
  azure_active_directory_role_based_access_control {
    managed = true
    admin_group_object_ids = [var.aks_admin_group_object_id]
  }
}
resource "azurerm_key_vault" "keyvault" {
  name                = local.kv_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}
resource "azurerm_key_vault_secret" "mysql_admin_password" {
  name         = "mysql-admin-password"
  value        = var.mysql_admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
}
resource "azurerm_mysql_flexible_server" "mysql" {
  name                = local.mysql_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  administrator_login    = var.mysql_admin_login
  administrator_password = var.mysql_admin_password
  sku_name               = "B_Standard_B1ms"
}
resource "azurerm_redis_cache" "redis" {
  name                = local.redis_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
}
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = local.cosmos_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy { consistency_level = "Session" }
  geo_location {
  location          = azurerm_resource_group.rg.location
  failover_priority = 0
}
}
resource "azurerm_storage_account" "storage" {
  name                = local.storage_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  account_tier        = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_log_analytics_workspace" "logs" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}
resource "azurerm_monitor_workspace" "prometheus" {
  name                = local.prometheus_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}