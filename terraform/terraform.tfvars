location            = "Australia East"
resource_group_name = "koalatech-week07-rg"
create_resource_group = true

# Replace with a unique name for your Azure Container Registry 
acr_name             = "koalatechacr225736433"

# Replace with a unique name for your Azure Storage Account
storage_account_name = "koalatechst225736433"

# SIT722 Task 10.3HD: globally unique App Service name for course-service
# (lowercase letters, numbers and hyphens), e.g. "koalatech-course-kr1716"
course_app_name = "koalatech-course-225736433"

environment = "development"

tags = {
    Project    = "KoalaTech Course Platform"
    ManagedBy  = "Terraform"
    Practical  = "Week07"
    Environment = "Development"
}
