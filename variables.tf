locals {
  default_nsg_rules = [
    {
      name                                       = "allow-dns-lb"
      priority                                   = 100
      direction                                  = "Inbound"
      access                                     = "Allow"
      protocol                                   = "*"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = "53"
      destination_port_ranges                    = null
      source_address_prefix                      = "AzureLoadBalancer"
      source_address_prefixes                    = null
      destination_address_prefix                 = null
      destination_address_prefixes               = null
      destination_application_security_group_ids = [azurerm_application_security_group.dns_forwarding.id]
      source_application_security_group_ids      = null
      description                                = "Allow Inbound DNS to the VMSS"
    },
    {
      name                                       = "allow-dns"
      priority                                   = 110
      direction                                  = "Inbound"
      access                                     = "Allow"
      protocol                                   = "*"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = "53"
      destination_port_ranges                    = null
      source_address_prefix                      = "VirtualNetwork"
      source_address_prefixes                    = null
      destination_address_prefix                 = null
      destination_address_prefixes               = null
      destination_application_security_group_ids = [azurerm_application_security_group.dns_forwarding.id]
      source_application_security_group_ids      = null
      description                                = "Allow Inbound DNS to the VMSS"
    },
    {
      name                                       = "deny-inbound-telnet-ftp"
      priority                                   = 200
      direction                                  = "Inbound"
      access                                     = "Deny"
      protocol                                   = "Tcp"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = null
      destination_port_ranges                    = [20, 21, 23]
      source_address_prefix                      = "*"
      source_address_prefixes                    = null
      destination_address_prefix                 = null
      destination_address_prefixes               = null
      destination_application_security_group_ids = [azurerm_application_security_group.dns_forwarding.id]
      source_application_security_group_ids      = null
      description                                = "Deny inbound port 20,21,23 (telnet and FTP) to vnet"
    },
    {
      name                                       = "allow-inbound-ssh"
      priority                                   = 4001
      direction                                  = "Inbound"
      access                                     = "Allow"
      protocol                                   = "Tcp"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = "22"
      destination_port_ranges                    = null
      source_address_prefix                      = null
      source_address_prefixes                    = var.dgn_cidrs
      destination_address_prefix                 = null
      destination_address_prefixes               = null
      destination_application_security_group_ids = [azurerm_application_security_group.dns_forwarding.id]
      source_application_security_group_ids      = null
      description                                = "Allow inbound SSH from the DGN"
    },
    {
      name                                       = "deny-outbound-telnet-ftp"
      priority                                   = 101
      direction                                  = "Outbound"
      access                                     = "Deny"
      protocol                                   = "Tcp"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = null
      destination_port_ranges                    = [20, 21, 23]
      source_address_prefix                      = null
      source_address_prefixes                    = null
      destination_address_prefix                 = "*"
      destination_address_prefixes               = null
      destination_application_security_group_ids = null
      source_application_security_group_ids      = [azurerm_application_security_group.dns_forwarding.id]
      description                                = "Deny outbound port 20, 21 (FTP), 23 (telnet) from vnet"
    },
    {
      name                                       = "allow-outbound-dns"
      priority                                   = 105
      direction                                  = "Outbound"
      access                                     = "Allow"
      protocol                                   = "*"
      source_port_range                          = "*"
      source_port_ranges                         = null
      destination_port_range                     = "*"
      destination_port_ranges                    = null
      source_address_prefix                      = null
      source_address_prefixes                    = null
      destination_address_prefix                 = "AzureLoadBalancer"
      destination_address_prefixes               = null
      destination_application_security_group_ids = null
      source_application_security_group_ids      = [azurerm_application_security_group.dns_forwarding.id]
      description                                = "Allow outbound to LB"
    }
  ]

  # List of regions that support Availability Zones so we can determine which regions the LB can be zone-redundant
  availability_zones = [
    "westus2",
    "westus3",
    "eastus",
    "eastus2",
    "centralus",
    "northeurope",
    "uksouth",
    "francecentral",
    "westeurope",
    "southeastasia",
    "japaneast",
    "swedencentral",
    "germanywestcentral",
    "norwayeast"
  ]
}

variable "admin_password" {
  type        = string
  description = "The admin password of the admin_username for the VM's in the VMSS. Either admin_username & admin_password must be used OR public_key & public_key_username must be used"
  default     = null
}

variable "admin_username" {
  type        = string
  description = "The username of the local administrator on each Virtual Machine Scale Set instance"
  default     = null
}

variable "automatic_instance_repair" {
  type        = bool
  description = "Should the VMSS automatically repair unhealthy hosts"
  default     = true
}

variable "common_tags" {
  type = map(string)
  default = {
    managed_by = "terraform"
    repo       = "https://gitlab.disney.com/terraform/modules/azure/terraform-azure-dnsforwarding"
    project    = "Azure DNS forwarding"
  }
}

variable "custom_source_image" {
  type        = bool
  description = "Use a custom specified image for the VM's in the Scale Set, as opposed to the default image which is the latest Ubuntu 20 image from the DMI image gallery"
  default     = false
}

variable "custom_tags" {
  description = "Map of tags you would like to have added to the common_tags to tag all applicable resources"
  type        = map(string)
  default     = {}
}

variable "dgn_cidrs" {
  description = "List of DGN CIDR's to permit inbound to ssh into the backend VM's"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "dns_zones" {
  description = "List of DNS Zones who's requests should be forwarded to Disney on-prem DNS servers"
  type        = list(string)
  default = [
    "bcs.pvt",
    "corp.dig.com",
    "dig.com",
    "disney.com",
    "disney.network",
    "disney.pvt",
    "espn.pvt",
    "espn3.com",
    "go.com",
    "mgmt.prod",
    "mscorp.loc",
    "starwave.com",
    "wcntc.com",
    "wdig.com",
    "wdig.root",
    "wdw.disney.com",
    "woc.prod"
  ]
}

variable "grace_period_instance_repair" {
  description = "Amount of time (in minutes, between 30 and 90, defaults to 30 minutes) for which automatic repairs will be delayed. The grace period starts right after the VM is found unhealthy. The time duration should be specified in ISO 8601 format."
  type        = string
  default     = "PT30M"
}

variable "image_gallery_gallery_name" {
  type        = string
  description = "Name of image gallery where image comes from"
  default     = "dmi"
}

variable "image_gallery_image_name" {
  description = "Name of the image from the gallery"
  type        = string
  default     = "base-dtss-ubuntu-20"
}

variable "image_gallery_name" {
  description = "Name of the image. 'latest' pulls the latest image"
  type        = string
  default     = "latest"
}

variable "image_gallery_resource_group_name" {
  description = "Name of the resource group where the image gallery resides"
  type        = string
  default     = "dmi"
}

variable "lb_front_end_ip_subnet" {
  type        = string
  description = "Subnet ID of the Load Balancer front end IP addresses"
}

variable "load_balancer_static_ip" {
  type        = string
  description = "A static IP that will be the front end IP of the load balancer"
}

variable "os_disk_caching" {
  type        = string
  description = "The Type of Caching which should be used for the Internal OS Disk. Possible values are None, ReadOnly and ReadWrite"
  default     = "None"
}

variable "os_disk_storage_account_type" {
  type        = string
  description = "The Type of Storage Account which should back this the Internal OS Disk. Possible values include Standard_LRS, StandardSSD_LRS and Premium_LRS"
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  type        = number
  description = "The Size of the Internal OS Disk in GB, if you wish to vary from the size used in the image this Virtual Machine Scale Set is sourced from"
  default     = 40
}

variable "public_key" {
  type        = string
  description = "The Public Key which should be used for authentication, which needs to be at least 2048-bit and in ssh-rsa format. Either admin_username & admin_password must be used OR public_key & public_key_username must be used"
  default     = null
}

variable "public_key_username" {
  type        = string
  description = "The Username for which this Public SSH Key should be configured"
  default     = null
}

variable "quantity_of_instances" {
  type        = number
  description = "The number of Virtual Machines in the Scale Set"
  default     = 2
}

variable "querylog" {
  type        = string
  description = "Querylog enabled in named.conf.options"
  default     = "false"
}

variable "resource_group_name" {
  type    = string
  default = "rg-dns-forwarding"
}

variable "subnet_has_nat_gateway" {
  type        = bool
  description = "The subnet where this module is to be deployed already has a NAT Gateway (required for the VMSS VM's to get access to the Internet)"
}

variable "vm_sku" {
  description = "The SKU of the VM to run the DNS forwarding services"
  type        = string
  default     = "Standard_D2_v5"
}

variable "vmss_encryption_at_host_enabled" {
  type        = bool
  description = "Should all of the disks (including the temp disk) attached to this Virtual Machine be encrypted by enabling Encryption at Host. This has to be enabled at the individual subscription level, which is why it is false by default."
  default     = false
}

variable "vmss_image_offer" {
  description = "Must be specified if var.custom_source_image is true. Specifies the offer of the image used to create the virtual machines"
  type        = string
  default     = null
}

variable "vmss_image_publisher" {
  description = "Must be specified if var.custom_source_image is true. Specifies the publisher of the image used to create the virtual machines"
  type        = string
  default     = null
}

variable "vmss_image_sku" {
  description = "Must be specified if var.custom_source_image is true. Specifies the SKU of the image used to create the virtual machines"
  type        = string
  default     = null
}

variable "vmss_image_version" {
  description = "Must be specified if var.custom_source_image is true. Specifies the version of the image used to create the virtual machines."
  type        = string
  default     = null
}

variable "vmss_name" {
  description = "Virtual Machine Scale Set (VMSS) name"
  type        = string
  default     = "vmss-dns-forwarding"
}

variable "vmss_subnet_id" {
  type        = string
  description = "The ID of the subnet where you want to place the Virtual Machine Scale Set"
}

variable "vnet_cidr" {
  description = "The CIDR notation of the VNet where you are deploying DNS forwarding, such as 10.100.34.0/24"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vnet_cidr))
    error_message = "You must enter a valid CIDR notation for the variable vnet_cidr."
  }
}

variable "vnet_location" {
  description = "The location, such as 'westus' of the Virtual Network where you want DNS Forwarding services"
  type        = string
}

