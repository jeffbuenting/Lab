vsphere_server = "192.168.1.16"
datacenter = "KW-HQ"

BuildVM = {
	Name = "FMT-SQL-03"
	Datastore = "Local-14-R10"
	# ----- cluster = null if no cluster exists.  otherwise this should be the name of the cluster where the VM will be created
	Cluster = null
	# ----- Host is the name of the ESXi Host to deploy the VM.  Should be null if Cluster is used.
	Host = "192.168.1.14"
	# ----- ResoucePool is null if the default (root) resource pool is to be used.
	ResourcePool = null
	Folder = "LAB/FMT"
	Network = "192.168.1.x"
	Template = "WIN2016STDGUI_T"
}
