output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.rg_name
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account"
  value       = azurerm_storage_account.storage_account.name
}

output "storage_connection_string" {
  description = "Connection string used by the application to access Blob Storage"
  value       = azurerm_storage_account.storage_account.primary_connection_string
  sensitive   = true
}

output "student_profile_container" {
  description = "Student profile photo Blob container"
  value       = azurerm_storage_container.student_profile_photo.name
}

output "lecturer_profile_container" {
  description = "Lecturer profile photo Blob container"
  value       = azurerm_storage_container.lecturer_profile_photo.name
}


output "acr_login_command" {
  description = "Azure CLI command used to log in to ACR"
  value       = "az acr login --name ${azurerm_container_registry.acr.name}"
}


# ---------------------------------------------------------------------
# SIT722 Task 10.3HD - blue/green deployment outputs
# ---------------------------------------------------------------------

output "course_web_app_name" {
  description = "App Service name - set this as the COURSE_WEBAPP_NAME GitHub variable"
  value       = azurerm_linux_web_app.course.name
}

output "course_production_url" {
  description = "Production slot URL for course-service"
  value       = "https://${azurerm_linux_web_app.course.default_hostname}"
}

output "course_staging_url" {
  description = "Staging slot URL for course-service"
  value       = "https://${azurerm_linux_web_app_slot.course_staging.default_hostname}"
}

output "postgres_fqdn" {
  description = "PostgreSQL server host name"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "course_jwt_secret" {
  description = "JWT secret configured on course-service (use the same one in user-service if you deploy it)"
  value       = random_password.jwt_secret.result
  sensitive   = true
}
