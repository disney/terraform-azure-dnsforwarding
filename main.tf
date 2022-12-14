locals {
  nic_name       = "nic-${var.vmss_name}"
  ip_config_name = "ipcfg-${var.vmss_name}"
  lb_name        = "lb-${var.vmss_name}"
  asg_name       = "asg-${var.vmss_name}"
  nsg_name       = "nsg-${var.vmss_name}"
  nat_gw_name    = "nat-${var.vmss_name}"
  nat_gw_ip_name = "nat-pub-ip-${var.vmss_name}"
  tags           = merge(var.common_tags, var.custom_tags)

  base_cloudinit = templatefile(
    "${path.module}/templates/cloud-init.tftpl",
    {
      vnet_cidr_block        = var.vnet_cidr,
      dns_zones              = var.dns_zones,
      querylog               = var.querylog,
      frontend_ip            = var.load_balancer_static_ip,
      allowed-query-networks = [var.permitted_to_query_dns_forwarders],
      dnssec-enabled         = var.dnssec_enable,
      dnssec-validation      = var.dnssec_validation
    }
  )

  base_cloudinit_every_boot = templatefile(
    "${path.module}/templates/cloud-init-every-boot.tftpl",
    {
      frontend_ip = var.load_balancer_static_ip
    }
  )
}

resource "azurerm_resource_group" "dns_forwarding" {
  name     = var.resource_group_name
  location = var.vnet_location

  tags = local.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "dns_forwarding" {
  name                       = var.vmss_name
  resource_group_name        = azurerm_resource_group.dns_forwarding.name
  location                   = var.vnet_location
  sku                        = var.vm_sku
  instances                  = var.quantity_of_instances
  health_probe_id            = azurerm_lb_probe.dns_forwarding.id
  source_image_id            = var.custom_source_image == false ? data.azurerm_shared_image_version.image_from_gallery.id : null
  encryption_at_host_enabled = var.vmss_encryption_at_host_enabled

  # Either admin_username & admin_password must be specified OR public_key & public_key_username must be specified
  admin_username                  = var.admin_username
  admin_password                  = var.public_key != null ? null : var.admin_password
  disable_password_authentication = var.admin_password != null ? false : true

  dynamic "admin_ssh_key" {
    for_each = var.public_key != null ? [1] : []
    content {
      public_key = var.public_key
      username   = var.public_key_username
    }
  }

  dynamic "source_image_reference" {
    for_each = var.custom_source_image == true ? [1] : []
    content {
      publisher = var.vmss_image_publisher
      offer     = var.vmss_image_offer
      sku       = var.vmss_image_sku
      version   = var.vmss_image_version
    }
  }

  os_disk {
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name                          = local.nic_name
    network_security_group_id     = azurerm_network_security_group.dns_forwarding.id
    dns_servers                   = ["168.63.129.16"]
    enable_accelerated_networking = true
    primary                       = true

    ip_configuration {
      name                                   = local.ip_config_name
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.dns_forwarding.id]
      subnet_id                              = var.vmss_subnet_id
      primary                                = true
      application_security_group_ids         = [azurerm_application_security_group.dns_forwarding.id]
    }
  }

  automatic_instance_repair {
    enabled      = var.automatic_instance_repair
    grace_period = var.grace_period_instance_repair
  }

  identity {
    type = "SystemAssigned"
  }

  user_data = data.cloudinit_config.dns_forwarding.rendered

  depends_on = [
    azurerm_lb_rule.dns_forwarding,
    azurerm_subnet_nat_gateway_association.dns_forwarding
  ]

  tags = local.tags
}

data "azurerm_shared_image_version" "image_from_gallery" {
  name                = var.image_gallery_name
  image_name          = var.image_gallery_image_name
  gallery_name        = var.image_gallery_gallery_name
  resource_group_name = var.image_gallery_resource_group_name

  provider = azurerm.image_gallery
}

data "cloudinit_config" "dns_forwarding" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = var.custom_base_cloudinit != null ? var.custom_base_cloudinit : local.base_cloudinit
  }

  # adding a loopback or dummy interface is not persistent so we do it in an x-shellscript-per-boot part
  part {
    content_type = "text/x-shellscript-per-boot"
    content      = local.base_cloudinit_every_boot
  }

  dynamic "part" {
    for_each = var.additional_cloud_config_content != null ? [1] : []
    content {
      content_type = "text/cloud-config"
      content      = var.additional_cloud_config_content
      merge_type   = var.additional_cloud_config_merge_type
    }
  }

  dynamic "part" {
    for_each = var.user_data_script != null ? [1] : []
    content {
      content_type = "text/x-shellscript"
      content      = var.user_data_script
    }
  }
}

resource "azurerm_application_security_group" "dns_forwarding" {
  name                = local.asg_name
  location            = var.vnet_location
  resource_group_name = azurerm_resource_group.dns_forwarding.name

  tags = local.tags
}

resource "azurerm_network_security_group" "dns_forwarding" {
  name                = local.nsg_name
  location            = var.vnet_location
  resource_group_name = azurerm_resource_group.dns_forwarding.name

  tags = local.tags
}

resource "azurerm_network_security_rule" "dns_forwarding" {
  for_each                                   = var.custom_nsg_rules != null ? { for r in var.custom_nsg_rules : r.name => r } : { for r in local.default_nsg_rules : r.name => r }
  name                                       = each.value["name"]
  resource_group_name                        = azurerm_resource_group.dns_forwarding.name
  network_security_group_name                = azurerm_network_security_group.dns_forwarding.name
  description                                = each.value["description"]
  protocol                                   = each.value["protocol"]
  source_port_range                          = each.value["source_port_range"]
  source_port_ranges                         = each.value["source_port_ranges"]
  destination_port_range                     = each.value["destination_port_range"]
  destination_port_ranges                    = each.value["destination_port_ranges"]
  source_address_prefix                      = each.value["source_address_prefix"]
  source_address_prefixes                    = each.value["source_address_prefixes"]
  source_application_security_group_ids      = each.value["source_application_security_group_ids"]
  destination_address_prefix                 = each.value["destination_address_prefix"]
  destination_address_prefixes               = each.value["destination_address_prefixes"]
  destination_application_security_group_ids = each.value["destination_application_security_group_ids"]
  access                                     = each.value["access"]
  priority                                   = each.value["priority"]
  direction                                  = each.value["direction"]
}

resource "azurerm_lb" "dns_forwarding" {
  name                = local.lb_name
  location            = var.vnet_location
  resource_group_name = azurerm_resource_group.dns_forwarding.name
  sku                 = "Standard"

  frontend_ip_configuration {
    # Standard SKU Load Balancer that do not specify a zone are zone redundant by default.
    name                          = "lb-front-end-ip-${regex("[^.]*$", var.load_balancer_static_ip)}" # regex gets last octect of front end IP
    private_ip_address            = var.load_balancer_static_ip
    private_ip_address_allocation = "Static"
    private_ip_address_version    = "IPv4"
    subnet_id                     = var.lb_front_end_ip_subnet
    zones                         = contains(keys(local.availability_zones), var.vnet_location) ? local.availability_zones[var.vnet_location] : null
  }

  tags = local.tags
}

resource "azurerm_lb_probe" "dns_forwarding" {
  loadbalancer_id = azurerm_lb.dns_forwarding.id
  name            = "dns-forwarding-probe"
  port            = 53
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "dns_forwarding" {
  for_each                       = toset(["Tcp", "Udp"])
  loadbalancer_id                = azurerm_lb.dns_forwarding.id
  name                           = "LBRule-${each.value}-${regex("[^.]*$", var.load_balancer_static_ip)}"
  protocol                       = each.value
  frontend_port                  = 53
  backend_port                   = 53
  enable_floating_ip             = true
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dns_forwarding.id]
  frontend_ip_configuration_name = "lb-front-end-ip-${regex("[^.]*$", var.load_balancer_static_ip)}"
  probe_id                       = azurerm_lb_probe.dns_forwarding.id
}

resource "azurerm_lb_backend_address_pool" "dns_forwarding" {
  name            = "BackEndAddressPool"
  loadbalancer_id = azurerm_lb.dns_forwarding.id
}

# Setup Azure Virtual Network NAT for outbound internet access for the VM's in the VMSS
# This must be done because the LB in front of the VMSS is internally facing and therefore does
# not provide outbound access
resource "azurerm_nat_gateway" "dns_forwarding" {
  count               = var.subnet_has_nat_gateway == true ? 0 : 1
  name                = local.nat_gw_name
  location            = var.vnet_location
  resource_group_name = azurerm_resource_group.dns_forwarding.name
  sku_name            = "Standard"

  tags = local.tags
}

resource "azurerm_public_ip" "dns_forwarding" {
  count               = var.subnet_has_nat_gateway == true ? 0 : 1
  name                = local.nat_gw_ip_name
  location            = var.vnet_location
  resource_group_name = azurerm_resource_group.dns_forwarding.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = contains(keys(local.availability_zones), var.vnet_location) ? local.availability_zones[var.vnet_location] : null
  ip_version          = "IPv4"

  tags = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "dns_forwarding" {
  count                = var.subnet_has_nat_gateway == true ? 0 : 1
  nat_gateway_id       = azurerm_nat_gateway.dns_forwarding[count.index].id
  public_ip_address_id = azurerm_public_ip.dns_forwarding[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "dns_forwarding" {
  count          = var.subnet_has_nat_gateway == true ? 0 : 1
  subnet_id      = var.vmss_subnet_id
  nat_gateway_id = azurerm_nat_gateway.dns_forwarding[count.index].id
}
