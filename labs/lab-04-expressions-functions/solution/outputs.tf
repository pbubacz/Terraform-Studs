output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.this.name
}

output "subnet_cidrs" {
  description = "Map of subnet key to computed CIDR."
  value       = { for key, subnet in local.subnet_configs : key => subnet.cidr }
}

output "subnet_ids" {
  description = "Map of subnet key to Azure subnet ID."
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}

output "nsg_names" {
  description = "Map of subnet key to network security group name."
  value       = { for key, nsg in azurerm_network_security_group.this : key => nsg.name }
}