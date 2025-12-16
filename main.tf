terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.23.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# -----------------------------------------------------------------------------
# 1. INFRAESTRUCTURA BASE
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-apple-sales-${random_integer.suffix.result}"
  location = "chilecentral"
}

# -----------------------------------------------------------------------------
# 2. DATA LAKE STORAGE (Bronze, Silver, Gold)
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "sa" {
  name                     = "adlsapplesales${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# -----------------------------------------------------------------------------
# 3. CARGA DE ARCHIVOS CSV (Bronze)
# -----------------------------------------------------------------------------

resource "azurerm_storage_blob" "products_csv" {
  name                   = "products.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.bronze.name
  type                   = "Block"
  source                 = "./Dataset/products.csv"
}

resource "azurerm_storage_blob" "stores_csv" {
  name                   = "stores.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.bronze.name
  type                   = "Block"
  source                 = "./Dataset/stores.csv"
}

resource "azurerm_storage_blob" "warranty_csv" {
  name                   = "warranty.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.bronze.name
  type                   = "Block"
  source                 = "./Dataset/warranty.csv"
}

# -----------------------------------------------------------------------------
# 4. DATA WAREHOUSE (SQL Server + DW_APPLE)
# -----------------------------------------------------------------------------

resource "azurerm_mssql_server" "sql" {
  name                         = "sqlserverapplesales${random_integer.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
}

resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "dw" {
  name                  = "DW_APPLE"
  server_id             = azurerm_mssql_server.sql.id
  collation             = "SQL_Latin1_General_CP1_CI_AS"
  sku_name              = "S0"
  max_size_gb           = 2
  license_type          = "LicenseIncluded"
  enclave_type          = "VBS"
  storage_account_type  = "Local"
  tags = {
    project = "DW_APPLE"
  }
}

# -----------------------------------------------------------------------------
# 5. AZURE DATA FACTORY
# -----------------------------------------------------------------------------

resource "azurerm_data_factory" "adf" {
  name                = "adf-applesales-${random_integer.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# -----------------------------------------------------------------------------
# 6. OUTPUTS
# -----------------------------------------------------------------------------

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "data_factory_name" {
  value = azurerm_data_factory.adf.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}
