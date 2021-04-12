variable vsphere_server {}
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