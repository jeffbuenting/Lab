variable vsphere_server {}
variable vsphere_user {}
variable vsphere_password {}
variable datacenter {}
variable AdminPW {}
variable BuildVM {
	type = object({
		Name = string
		Datastore = string
		Cluster = string
		Host = string
		Network = string
		ResourcePool = string
		Folder = string
		Template = string
		IP = string
		Subnet = number
		DefaultGateway = string
		DNS = list(string)
	})
}