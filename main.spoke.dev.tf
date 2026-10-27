# Dev workload subscription.
# This is the spare subscription currently named EEGA-Connectivity.
provider "azurerm" {
  alias                           = "dev"
  subscription_id                 = "02b28fea-769e-4362-a495-1a45361b4de0"
  resource_provider_registrations = "none"

  features {}
}

locals {
  dev_location = "eastus2"

  dev_tags = {
    environment = "dev"
    deployed_by = "terraform"
    project     = "eega-lab"
  }
}

# Read the existing hub; its existing module remains its owner.
data "azurerm_virtual_network" "dev_existing_hub" {
  provider = azurerm.connectivity

  name                = "vnet-hub-eastus2-001"
  resource_group_name = "rg-hub-eastus2"

  depends_on = [module.hub_and_spoke_vnet]
}

resource "azurerm_resource_group" "dev_spoke" {
  provider = azurerm.dev

  name     = "rg-spoke-dev-eastus2"
  location = local.dev_location
  tags     = local.dev_tags
}

resource "azurerm_virtual_network" "dev_spoke" {
  provider = azurerm.dev

  name                = "vnet-spoke-dev-eastus2-001"
  location            = azurerm_resource_group.dev_spoke.location
  resource_group_name = azurerm_resource_group.dev_spoke.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.dev_tags
}

resource "azurerm_network_security_group" "dev_app" {
  provider = azurerm.dev

  name                = "nsg-dev-app-eastus2"
  location            = azurerm_resource_group.dev_spoke.location
  resource_group_name = azurerm_resource_group.dev_spoke.name
  tags                = local.dev_tags
}

resource "azurerm_subnet" "dev_app" {
  provider = azurerm.dev

  name                            = "snet-app"
  resource_group_name             = azurerm_resource_group.dev_spoke.name
  virtual_network_name            = azurerm_virtual_network.dev_spoke.name
  address_prefixes                = ["10.10.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "dev_app" {
  provider = azurerm.dev

  subnet_id                 = azurerm_subnet.dev_app.id
  network_security_group_id = azurerm_network_security_group.dev_app.id
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  provider = azurerm.dev

  name                      = "peer-dev-to-hub"
  resource_group_name       = azurerm_resource_group.dev_spoke.name
  virtual_network_name      = azurerm_virtual_network.dev_spoke.name
  remote_virtual_network_id = data.azurerm_virtual_network.dev_existing_hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_dev" {
  provider = azurerm.connectivity

  name                      = "peer-hub-to-dev"
  resource_group_name       = data.azurerm_virtual_network.dev_existing_hub.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.dev_existing_hub.name
  remote_virtual_network_id = azurerm_virtual_network.dev_spoke.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [azurerm_virtual_network_peering.dev_to_hub]
}

output "dev_spoke_virtual_network_id" {
  value = azurerm_virtual_network.dev_spoke.id
}
