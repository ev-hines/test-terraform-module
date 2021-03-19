variable "regions" {
  type = set(string)
}

variable "public_ssh_keys" {
  type = set(string)
}

provider "azurerm" {
  features {}
}

module "region_vm" {
  for_each = var.regions
  source   = "./sub_modules/"

  region          = each.value
  public_ssh_keys = var.public_ssh_keys
}

output "ssh" {
  value = [for x in module.region_vm : x.ssh]
}