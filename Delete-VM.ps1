$VM =get-vm kw-dc1
stop-vm -VM $VM -Confirm:$False
Remove-VM -VM $VM -DeletePermanently -Confirm:$False