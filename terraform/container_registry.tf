resource "azurerm_container_registry" "acr" {
    name                = var.acr_name
    resource_group_name = local.rg_name
    location            = local.rg_location

    sku           = "Basic"
    admin_enabled = true

    tags = merge(
        var.tags,
        {
            Environment = var.environment
        }
    )
}