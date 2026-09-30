variable "location" {
    description = "Azure region where the resources will be created"
    type        = string
    default     = "Australia East"
}

variable "resource_group_name" {
    description = "Name of the Azure Resource Group"
    type        = string
}

variable "acr_name" {
    description = "Globally unique name of the Azure Container Registry"
    type        = string

    validation {
        condition     = can(regex("^[a-zA-Z0-9]+$", var.acr_name))
        error_message = "The ACR name must contain only alphanumeric characters."
    }
}

variable "storage_account_name" {
    description = "Globally unique name of the Azure Storage Account"
    type        = string

    validation {
        condition = (
            length(var.storage_account_name) >= 3 &&
            length(var.storage_account_name) <= 24 &&
            can(regex("^[a-z0-9]+$", var.storage_account_name))
        )

        error_message = "The storage account name must contain 3–24 lowercase letters and numbers."
    }
}

variable "environment" {
    description = "Environment name applied to resource tags"
    type        = string
    default     = "development"
}


variable "tags" {
    description = "Tags applied to Azure resources"
    type        = map(string)

    default = {
        Project    = "KoalaTech Course Platform"
        ManagedBy  = "Terraform"
        Practical  = "Week07"
    }
}


# ---------------------------------------------------------------------
# SIT722 Task 10.3HD - blue/green deployment of course-service
# ---------------------------------------------------------------------

variable "course_app_name" {
    description = "Globally unique App Service name for course-service (becomes <name>.azurewebsites.net)"
    type        = string

    validation {
        condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.course_app_name))
        error_message = "Use 3-42 lowercase letters, numbers and hyphens (it is also used for the database name)."
    }
}

variable "course_image_name" {
    description = "Repository name of the course-service image in ACR"
    type        = string
    default     = "koalatech-course-service"
}

variable "app_service_sku" {
    description = "App Service plan SKU. Deployment slots need S1 (Standard) or higher."
    type        = string
    default     = "S1"
}

variable "postgres_location" {
    description = "Region for PostgreSQL. Leave null to use the resource group location; set it if your subscription blocks PostgreSQL in that region."
    type        = string
    default     = null
}

variable "create_resource_group" {
    description = "true = Terraform creates the resource group; false = use an existing one (lab accounts)"
    type        = bool
    default     = false
}
