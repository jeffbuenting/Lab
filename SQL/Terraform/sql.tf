

provider "vsphere" {
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.BuildVM.Datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  count = var.BuildVM.Cluster == null ? 0 : 1
  name          = var.BuildVM.Cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
	count = var.BuildVM.Host == null ? 0 : 1
	name = var.BuildVM.Host
	datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "resourcepool" {
	name = var.BuildVM.Cluster == null ? "${var.BuildVM.Host}/Resources" : var.BuildVM.ResourcePool
	datacenter_id = data.vsphere_datacenter.dc.id	
}

data "vsphere_network" "network" {
  name          = var.BuildVM.Network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.BuildVM.Template
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  name             = var.BuildVM.Name
  folder = var.BuildVM.Folder
  resource_pool_id = data.vsphere_resource_pool.resourcepool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  firmware = data.vsphere_virtual_machine.template.firmware

  guest_id = data.vsphere_virtual_machine.template.guest_id
  
  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id = data.vsphere_network.network.id
	adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label = "disk0"
    size  = data.vsphere_virtual_machine.template.disks.0.size
  }
  
  clone {
	template_uuid = data.vsphere_virtual_machine.template.id
	customize {
		windows_options {
		  computer_name = var.BuildVM.Name
		  time_zone = 035
		}
		network_interface {}
	}
  }
}