locals {
  environment = lower(var.environment)
  name_prefix = substr(replace(lower("${var.prefix}-${local.environment}"), "_", "-"), 0, 40)

  default_tags = {
    course = "terraform-azure"
    lab    = "04-expressions-functions"
  }

  tags = merge(
    local.default_tags,
    var.extra_tags,
    {
      env   = local.environment
      owner = coalesce(trimspace(var.owner), "unknown")
    }
  )

  subnet_configs = {
    for key, subnet in var.subnets : key => merge(subnet, {
      name = format("snet-%s-%s", local.name_prefix, key)
      cidr = cidrsubnet(var.address_space, subnet.newbits, subnet.index)
    })
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}-expr"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnet_configs

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]
  service_endpoints    = each.value.service_endpoints
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnet_configs

  name                = "nsg-${local.name_prefix}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = each.value.security_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnet_configs

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}