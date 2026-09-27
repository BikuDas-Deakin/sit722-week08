location            = "Australia East"
resource_group_name = "koalatech-week08-rg-s225010182"

# Replace with a unique name for your Azure Container Registry
acr_name             = "acrs225010182w08"

# Replace with a unique name for your Azure Storage Account
storage_account_name = "stors225010182w08"

# Replace with a unique name for your Azure Kubernetes Service cluster
aks_cluster_name = "aks-s225010182-week08"
aks_dns_prefix   = "koalatech-s225010182-w08"

aks_node_count   = 3
aks_node_vm_size = "Standard_D2s_v3"

environment = "development"

tags = {
    Project    = "KoalaTech Course Platform"
    ManagedBy  = "Terraform"
    Practical  = "Week08"
    Environment = "Development"
}
