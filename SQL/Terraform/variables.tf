variable vsphere_server {}
variable datacenter {}
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
	})
}