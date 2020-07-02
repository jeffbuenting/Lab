$VM =get-vm kw-SQL1
stop-vm -VM $VM -Confirm:$False
Remove-VM -VM $VM -DeletePermanently -Confirm:$False