app_vsphere_server = "192.168.1.16"
app_datacenter = "KW-HQ"

# ----- BuildVM
AppVM = {
	Name = "FMT-APP-03"
	Datastore = "Local-14-R10"
	# ----- cluster = null if no cluster exists.  otherwise this should be the name of the cluster where the VM will be created
	Cluster = null
	# ----- Host is the name of the ESXi Host to deploy the VM.  Should be null if Cluster is used.
	Host = "192.168.1.14"
	# ----- ResoucePool is null if the default (root) resource pool is to be used.
	ResourcePool = null
	Folder = "LAB/FMT"
	Network = "192.168.1.x"
	Template = "WIN2016STDGUI_Ansible_T"
	IP = "192.168.1.82"
	Subnet = 24
	DefaultGateway = "192.168.1.1"
	DNS = ["192.168.1.1"]
}