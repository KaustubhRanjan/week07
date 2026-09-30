# =====================================================================
# SIT722 Task 10.3HD - Zero-downtime blue/green deployment
#
# course-service runs on Azure App Service with two deployment slots:
#   production  -> https://<course_app_name>.azurewebsites.net
#   staging     -> https://<course_app_name>-staging.azurewebsites.net
#
# The pipeline deploys each new image to "staging", smoke-tests it and
# then swaps staging <-> production. The previous version stays in the
# staging slot, so a rollback is a single swap back.
#
# Deployment slots require the Standard (S1) tier or higher.
# Run `terraform destroy` when you are not using it to save credit.
# =====================================================================

resource "random_password" "postgres_admin" {
  length  = 24
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# ---------------------------------------------------------------------
# PostgreSQL database shared by the blue and green slots
# ---------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = "${var.course_app_name}-pg"
  resource_group_name           = local.rg_name
  location                      = coalesce(var.postgres_location, local.rg_location)
  version                       = "16"
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  administrator_login           = "koalaadmin"
  administrator_password        = random_password.postgres_admin.result
  public_network_access_enabled = true

  tags = merge(var.tags, { Environment = var.environment })

  lifecycle {
    # Azure picks an availability zone; don't fight it on later applies.
    ignore_changes = [zone]
  }
}

# 0.0.0.0 - 0.0.0.0 is Azure's special rule for "allow Azure services"
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "courses" {
  name      = "courses"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ---------------------------------------------------------------------
# App Service plan (S1 = cheapest tier that supports deployment slots)
# ---------------------------------------------------------------------
resource "azurerm_service_plan" "plan" {
  name                = "${var.course_app_name}-plan"
  resource_group_name = local.rg_name
  location            = local.rg_location
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = merge(var.tags, { Environment = var.environment })
}

locals {
  course_database_url = format(
    "postgresql+psycopg2://%s:%s@%s:5432/%s?sslmode=require",
    azurerm_postgresql_flexible_server.postgres.administrator_login,
    random_password.postgres_admin.result,
    azurerm_postgresql_flexible_server.postgres.fqdn,
    azurerm_postgresql_flexible_server_database.courses.name,
  )

  # Settings that are identical in both slots (they travel with a swap,
  # which is fine because the values are the same).
  course_common_settings = {
    WEBSITES_PORT                       = "8000"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    WEBSITES_CONTAINER_START_TIME_LIMIT = "600"

    # Azure warms the staging slot on /health before it moves any traffic,
    # and only swaps once /health returns 200.
    WEBSITE_SWAP_WARMUP_PING_PATH     = "/health"
    WEBSITE_SWAP_WARMUP_PING_STATUSES = "200"

    DATABASE_URL   = local.course_database_url
    JWT_SECRET_KEY = random_password.jwt_secret.result
    JWT_ALGORITHM  = "HS256"
  }

  course_image = "${var.course_image_name}:latest"
}

# ---------------------------------------------------------------------
# Production slot (the web app itself)
# ---------------------------------------------------------------------
resource "azurerm_linux_web_app" "course" {
  name                = var.course_app_name
  resource_group_name = local.rg_name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  app_settings = merge(local.course_common_settings, {
    SLOT_NAME = "production"
  })

  # SLOT_NAME stays with the slot during a swap, so /health always
  # reports which slot answered.
  sticky_settings {
    app_setting_names = ["SLOT_NAME"]
  }

  site_config {
    always_on                         = true
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = local.course_image
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 35
      }
    }
  }

  tags = merge(var.tags, { Environment = var.environment, Slot = "production" })

  lifecycle {
    # The CI/CD pipeline owns which image is running. Without this,
    # `terraform apply` would roll production back to :latest.
    ignore_changes = [site_config[0].application_stack]
  }
}

# ---------------------------------------------------------------------
# Staging slot (receives every new release first)
# ---------------------------------------------------------------------
resource "azurerm_linux_web_app_slot" "course_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.course.id
  https_only     = true

  app_settings = merge(local.course_common_settings, {
    SLOT_NAME = "staging"
  })

  site_config {
    always_on                         = true
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = local.course_image
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 35
      }
    }
  }

  tags = merge(var.tags, { Environment = var.environment, Slot = "staging" })

  lifecycle {
    ignore_changes = [site_config[0].application_stack]
  }
}
