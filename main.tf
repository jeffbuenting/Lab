
# ----- Create IIS Server

module "AppServer" {
	source = ".\\Modules\\VMware_VM"
	vsphere_server = var.app_vsphere_server	
	vsphere_password = var.vsphere_password
	vsphere_user = var.vsphere_user
	datacenter = app_var.datacenter
	AdminPW = var.AdminPW
	BuildVM = var.AppVM
}

