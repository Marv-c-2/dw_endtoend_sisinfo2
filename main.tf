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

# Genera un número aleatorio para evitar conflictos en los nombres de recursos
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# -----------------------------------------------------------------------------
# 1. INFRAESTRUCTURA BASE
# -----------------------------------------------------------------------------

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-dwventas-examen-${random_integer.suffix.result}"
  location = "chilecentral"
}

# -----------------------------------------------------------------------------
# 2. DATA LAKE STORAGE (AZURE DATA LAKE GEN2) - Capas Bronze, Silver, Gold
# -----------------------------------------------------------------------------

# Storage Account (Habilita Data Lake Gen2 con is_hns_enabled = true)
resource "azurerm_storage_account" "sa" {
  name                     = "sadwventasdelta${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

# Contenedor BRONZE (Datos Crudos)
resource "azurerm_storage_container" "raw_advent" {
  name                  = "bronze-advent"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# Contenedor SILVER (Datos Limpios y Transformados)
resource "azurerm_storage_container" "silver_advent" {
  name                  = "silver-advent"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# Contenedor GOLD (Datos Finales para Reporte si usas Synapse/Databricks)
resource "azurerm_storage_container" "gold_advent" {
  name                  = "gold-advent"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# -----------------------------------------------------------------------------
# 3. CARGA DE ARCHIVOS CSV (Capa Bronze)
# -----------------------------------------------------------------------------

# ATENCIÓN: Asegúrate de que los archivos existan en un directorio local llamado 'data/'
# donde ejecutas 'terraform apply'.

resource "azurerm_storage_blob" "clientes_csv" {
  name                   = "Clientes.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Clientes.csv"
}

resource "azurerm_storage_blob" "detalle_ventas_csv" {
  name                   = "Detalle_ventas.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Detalle_ventas.csv"
}

resource "azurerm_storage_blob" "productos_csv" {
  name                   = "Productos.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Productos.csv"
}

resource "azurerm_storage_blob" "productos_cat_mant_csv" {
  name                   = "Productos_CAT_MANT.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Productos_CAT_MANT.csv"
}

resource "azurerm_storage_blob" "clientes_bd_gen_csv" {
  name                   = "Clientes_BD-GEN (1).csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Clientes_BD-GEN (1).csv"
}

resource "azurerm_storage_blob" "clientes_location_csv" {
  name                   = "Clientes_location (1).csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_advent.name
  type                   = "Block"
  source                 = "./Dataset/Clientes_location (1).csv"
}

# -----------------------------------------------------------------------------
# 4. DATA WAREHOUSE (Capa Gold)
# -----------------------------------------------------------------------------

# SQL Server
resource "azurerm_mssql_server" "db" {
  name                         = "sql-dwventas-advent-${random_integer.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
}

# Regla de Firewall para permitir la conexión desde Azure services (requerido por ADF)
resource "azurerm_mssql_firewall_rule" "rulefirewall" {
  name             = "AllowAzureServicesAndIP"
  server_id        = azurerm_mssql_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "dw_ventas" {
  name                  = "dw_ventas_advent"
  server_id             = azurerm_mssql_server.db.id
  collation             = "SQL_Latin1_General_CP1_CI_AS"
  license_type          = "LicenseIncluded"
  max_size_gb           = 2
  sku_name              = "S0"
  enclave_type          = "VBS"
  storage_account_type  = "Local" 

  tags = {
    project = "ExamenDW"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# 5. AZURE DATA FACTORY (Motor ETL)
# -----------------------------------------------------------------------------

# Data Factory
resource "azurerm_data_factory" "df" {
  name                = "adf-dwventas-advent-${random_integer.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# -----------------------------------------------------------------------------
# 6. OUTPUTS
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "Nombre de la Storage Account (Data Lake)"
  value       = azurerm_storage_account.sa.name
}

output "data_factory_name" {
  description = "Nombre de la Azure Data Factory"
  value       = azurerm_data_factory.df.name
}

output "sql_server_fqdn" {
  description = "Fully Qualified Domain Name del SQL Server"
  value       = azurerm_mssql_server.db.fully_qualified_domain_name
}