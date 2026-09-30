# Lab accounts (cloudlabs4deakin) cannot create resource groups, so by
# default we use an existing one. Set create_resource_group = true in
# terraform.tfvars if your account is allowed to create it.
resource "azurerm_resource_group" "rg" {
    count    = var.create_resource_group ? 1 : 0
    name     = var.resource_group_name
    location = var.location

    tags = merge(
        var.tags,
        {
            Environment = var.environment
        }
    )
}

data "azurerm_resource_group" "existing" {
    count = var.create_resource_group ? 0 : 1
    name  = var.resource_group_name
}

locals {
    rg_name     = var.create_resource_group ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.existing[0].name
    rg_location = var.create_resource_group ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.existing[0].location
}
