# --- variables.tf ---

variable "mysql_admin_login" {
  description = "Admin username for the MySQL server"
  type        = string
  sensitive   = true 
}

variable "mysql_admin_password" {
  description = "Admin password for the MySQL server"
  type        = string
  sensitive   = true
}

variable "aks_admin_group_object_id" {
  description = "The Object ID of the Entra ID (Azure AD) group for AKS admins"
  type        = string
}