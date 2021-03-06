# Don't run everything, thanks @alexandair!
break

# IF THIS SCRIPT IS RUN ON LOCAL SQL INSTANCES, YOU MUST RUN ISE OR POWERSHELL AS ADMIN
# Otherwise, a bunch of commands won't work.
cls

# Paths that auto-load modules
$env:PSModulePath -Split ";"

# This is the [development] aka beta branch
Import-Module C:\github\dbatools -Force
cd C:\github\dbatools

# Set some vars
$new = "localhost\sql2016"
$old = $instance = "localhost"
$allservers = $old, $new

# Alternatively, use Registerd Servers? 
Get-DbaRegisteredServer -SqlInstance $instance | Out-GridView

# Quick overview of commands
Start-Process https://dbatools.io/commands

#region backuprestore

# standard
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak"
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak" -WithReplace

# ola!
Invoke-Item \\workstation\backups\WORKSTATION\SharePoint_Config
Invoke-Item \\workstation\backups\sql2012 
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance $new

#endregion

# Make a quick backup!
Get-DbaDatabase -SqlInstance $new | Backup-DbaDatabase

# Test your backups
# Did you see? SqlServer module is now in the Powershell Gallery too!
Get-Help Test-DbaLastBackup -Online
Import-Module SqlServer
Invoke-Item (Get-Item SQLSERVER:\SQL\WORKSTATION\SQL2016).DefaultFile

Test-DbaLastBackup -SqlInstance $new | Out-GridView

# Exports
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# Other Exports
Get-DbaAgentJob -SqlInstance $old | Export-DbaScript -Path C:\temp\jobs.sql

# What if you just want to script out your restore?
Get-ChildItem -Directory \\workstation\backups\subset\ | Restore-DbaDatabase -SqlInstance $new -OutputScriptOnly -WithReplace | Out-File -Filepath c:\temp\restore.sql
Invoke-Item c:\temp\restore.sql

# Surprise beard! Perform a beautiful migration
$startDbaMigrationSplat = @{
	Source = $old
	Destination = $new
	BackupRestore = $true
    NetworkShare = 'C:\temp'
    NoSysDbUserObjects = $true
    NoCredentials = $true
    NoBackupDevices = $true
    NoEndPoints = $true
}
		
Start-DbaMigration @startDbaMigrationSplat -Force | Select * | Out-GridView

# Snapshots!
New-DbaDatabaseSnapshot -SqlInstance $new -Database db1 -Name db1_snapshot
Get-DbaDatabaseSnapshot -SqlInstance $new
Get-DbaProcess -SqlInstance $new -Database db1 | Stop-DbaProcess
Restore-DbaFromDatabaseSnapshot -SqlInstance $new -Database db1 -Snapshot db1_snapshot
Remove-DbaDatabaseSnapshot -SqlInstance $new -Snapshot db1_snapshot # or -Database db1

# Checkdb & Jobs
$old | Get-DbaLastGoodCheckDb | Out-GridView
$old | Get-DbaAgentJob | Where Name -match integrity | Start-DbaAgentJob
$old | Get-DbaRunningJob
$old | Get-DbaLastGoodCheckDb | Out-GridView

# build info!
Start-Process https://dbatools.io/builds
$allservers | Get-DbaSqlBuildReference

# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!
$new | Find-DbaStoredProcedure -Pattern dbatools
$new | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$new | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'

# Find user owned objects
Find-DbaUserObject -SqlInstance $instance -Pattern workstation\loulou | Out-GridView
 
# Find detached databases
Detach-DbaDatabase -SqlInstance $instance -Database AdventureWorks2012
Find-DbaOrphanedFile -SqlInstance $instance | Out-GridView

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView

# View and change service account
Get-DbaSqlService -ComputerName workstation | Out-GridView
Get-DbaSqlService -ComputerName workstation | Select * | Out-GridView
Get-DbaSqlService -Instance SQL2016 -Type Agent | Update-DbaSqlServiceAccount -Username 'Local system'

# Spconfigure
Get-DbaSpConfigure -SqlInstance $new | Out-GridView
Get-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled
# Need to add config value to output
Set-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled -Value $true

# DB Cloning too!
Remove-Module sqlserver
Remove-DbaDatabase -SqlInstance $new -Database db1_clone
Invoke-DbaDatabaseClone -SqlInstance $new -Database db1 -CloneDatabase db1_clone | Out-GridView

# XEvents - more coming soon, like easy replays on remote servers

# Easy start/stop
Get-DbaXESession -SqlInstance $new
$session = Get-DbaXESession -SqlInstance $new -Session system_health | Stop-DbaXESession
$session | Start-DbaXESession

# Read and watch
Get-DbaXEventSession -SqlInstance $new -Session system_health | Read-DbaXEventFile
Get-DbaXEventSession -SqlInstance $new -Session system_health | Read-DbaXEventFile | Select -ExpandProperty Fields | Out-GridView

Invoke-Item C:\github\community-presentations\rob-sewell-chrissy-lemaire\watch-xeventsession.png

# Reset-DbaAdmin
Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose
Get-DbaDatabase -SqlInstance $instance -SqlCredential (Get-Credential sqladmin)

# Configs and enterprise logging
Get-DbaConfig | Out-GridView
Invoke-Item (Get-DbaConfig -FullName path.dbatoolslogpath).Value

Get-DbaConfig -Module tabexpansion
Set-DbaConfig -Name tabexpansion.disable -Value $true

Get-DbatoolsLog | Out-GridView
New-DbatoolsSupportPackage

# Community projects

# sp_whoisactive
Install-DbaWhoIsActive -SqlInstance $instance -Database master
Invoke-DbaWhoIsActive -SqlInstance $instance -ShowOwnSpid -ShowSystemSpids

# Diagnostic query!
$instance | Invoke-DbaDiagnosticQuery -UseSelectionHelper | Export-DbaDiagnosticQuery -Path $home
Invoke-Item $home

# Ola, yall
$instance | Install-DbaMaintenanceSolution -ReplaceExisting -BackupLocation C:\temp -InstallJobs

# Startup parameters
Get-DbaStartupParameter -SqlInstance $instance
Set-DbaStartupParameter -SqlInstance $instance -SingleUser -WhatIf

# Database clone
Invoke-DbaDatabaseClone -SqlInstance $new -Database dbwithsprocs -CloneDatabase dbwithsprocs_clone

# Schema change and Pester tests
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "CREATE TABLE dbatoolsci_schemachange (id int identity)"
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "EXEC sp_rename 'dbatoolsci_schemachange', 'dbatoolsci_schemachange_new'"
Get-DbaSchemaChangeHistory -SqlInstance $new -Database tempdb
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "DROP TABLE dbatoolsci_schemachange_new"

Invoke-Item C:\github\dbatools\tests\Get-DbaSchemaChangeHistory.Tests.ps1
Start-Process https://dbatools.io/ci
Invoke-Item C:\github\dbatools\tests

# Get Db Free Space AND write it to table
Get-DbaDatabaseSpace -SqlInstance $instance | Out-GridView
Get-DbaDatabaseSpace -SqlInstance $instance -IncludeSystemDB | Out-DbaDataTable | Write-DbaDataTable -SqlInstance $instance -Database tempdb -Table DiskSpaceExample -AutoCreateTable
Invoke-Sqlcmd2 -ServerInstance $instance -Database tempdb -Query 'SELECT * FROM dbo.DiskSpaceExample' | Out-GridView

# History
Get-Command -Module dbatools *history*

# More histories
Get-DbaAgentJobHistory -SqlInstance $instance | Out-GridView
Get-DbaBackupHistory -SqlInstance $new | Out-GridView

# Identity usage
Test-DbaIdentityUsage -SqlInstance $instance | Out-GridView

# Test/Set SQL max memory
$allservers | Get-DbaMaxMemory
$allservers | Test-DbaMaxMemory | Format-Table
$allservers | Test-DbaMaxMemory | Where-Object { $_.SqlMaxMB -gt $_.TotalMB } | Set-DbaMaxMemory -WhatIf
Set-DbaMaxMemory -SqlInstance $instance -MaxMb 1023

# RecoveryModel
Test-DbaFullRecoveryModel -SqlInstance $new
Test-DbaFullRecoveryModel -SqlInstance $new | Where { $_.ConfiguredRecoveryModel -ne $_.ActualRecoveryModel }

# Testing sql server linked server connections
Test-DbaLinkedServerConnection -SqlInstance $instance

# See protocols
Get-DbaServerProtocol -ComputerName $instance | Out-GridView

# SQL Modules - View, TableValuedFunction, DefaultConstraint, StoredProcedure, Rule, InlineTableValuedFunction, Trigger, ScalarFunction
Get-DbaSqlModule -SqlInstance $instance | Out-GridView
Get-DbaSqlModule -SqlInstance $instance -ModifiedSince (Get-Date).AddDays(-7) | Select-String -Pattern sp_executesql

# Reads trace files - default trace by default
Read-DbaTraceFile -SqlInstance $instance | Out-GridView

# Get the registry root
Get-DbaSqlRegistryRoot -ComputerName $instance

# Thanks, Fred! 
[dbainstance]"sql2016"
[dbainstance]"sqlcluster\sharepoint"

# don't have remoting access? Explore the filesystem. Uses master.sys.xp_dirtree
Get-DbaFile -SqlInstance $instance -Depth 3 -Path 'C:\Program Files\Microsoft SQL Server' | Out-GridView
New-DbaSqlDirectory -SqlInstance $instance  -Path 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\test'

# Network Encryption
# - Requires a certificate with DNS names (complex)
# - Requires specific properties in the certificate
# - Requires that the service account have read access to the private key
# - Clusters cannot be configured via the SQL Configuration Manager

Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\forcednetwork.mp4"

#region SPN
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

# No domain - let's watch a video!

$servers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -WhatIf
Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\spn.mp4"

#endregion

# Log Files
Get-DbaDbVirtualLogFile -SqlInstance $new -Database db1
Get-DbaDbVirtualLogFile -SqlInstance $new -Database db1 | Measure-Object

# OGV madness
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -NetworkShare \\workstation\c$\temp -Force