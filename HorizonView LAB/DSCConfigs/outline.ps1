
 

# ----- Add Instant-clone Domain Admin

if ( $HV.ExtensionData.InstantCloneEngineDomainAdministrator.InstantCloneEngineDomainAdministrator_List() -ne $ICAcct.Username ) {

 

 

}

 

# ----- Create instant-clone pool

New-HVPool -InstantClone -PoolName KW-Surf -PoolDisplayName "KW Surf" -UserAssignment FLOATING -ParentVM KWSurfMA -SnapshotVM ...

 

 

 

# ----- Cleanup

Disconnect-HVServer