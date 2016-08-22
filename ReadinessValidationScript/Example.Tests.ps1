#Requires -Modules 'Pester'

<#
PURPOSE: Pester script to validate that a machine meets the prerequisites for a software deployment/upgrade.  
    It generates a NUnit-style test result file for each computer and a summary report in HTML format.
    This script is designed to be run remotely (not from the target machine).
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [ValidateScript({ Test-Connection -ComputerName $_ -Quiet })]
    [string]$ComputerName,

    [Parameter(Mandatory=$True)]
    [pscredential]$Credential,

    [Parameter(Mandatory=$True)]
    [string]$DeploymentServerName,

    [Parameter(Mandatory=$True)]
    [string]$ManagementServerName
)

$RemoteSession = New-PSSession -ComputerName $ComputerName -Credential $Credential

Describe 'Hardware prerequisites' {
    
    It 'Has at least 4096 MB of total RAM' {

        Invoke-Command -Session $RemoteSession {
        (Get-CimInstance -ClassName Win32_PhysicalMemory).Capacity / 1MB } |
        Should Not BeLessThan 4096
    }
}
Describe 'Networking prerequisites' {

    It 'Can ping the Management server by name' {

        Invoke-Command -Session $RemoteSession { param($ManagementServerName)
        Test-Connection -ComputerName $ManagementServerName -Quiet } -ArgumentList $ManagementServerName |
        Should Be $True
    }
    It 'Can ping the Deployment server by name' {

        Invoke-Command -Session $RemoteSession { param($DeploymentServerName)
        Test-Connection -ComputerName $DeploymentServerName -Quiet } -ArgumentList $DeploymentServerName |
        Should Be $True
    }
    It 'Has connectivity to the Management server on TCP port 80' {

        Invoke-Command -Session $RemoteSession { param($ManagementServerName)
        (Test-NetConnection -ComputerName $ManagementServerName -CommonTCPPort HTTP).TcpTestSucceeded } -ArgumentList $ManagementServerName |
        Should Be $True
    }
    It 'Has the firewall profile set to "Domain" or "Private"' {

        Invoke-Command -Session $RemoteSession {
        $FirewallProfile = (Get-NetConnectionProfile)[0].NetworkCategory.ToString();
        $FirewallProfile -eq 'Domain' -or $FirewallProfile -eq 'Private' } |
        Should Be $True
    }
}
Describe 'OS and runtime prerequisites' {

    It 'Has the Windows Update KB2883200' {

        Invoke-Command -Session $RemoteSession {
        Get-HotFix -Id KB2883200 -ErrorAction SilentlyContinue } |
        Should Not BeNullOrEmpty
    }
    It 'Has the required version of the C++ 2010 runtime' {

        Invoke-Command -Session $RemoteSession {
        Get-CimInstance -ClassName Win32_Product -Filter "Name='Microsoft Visual C++ 2010  x64 Redistributable - 10.0.40219'" } |
        Should Not BeNullOrEmpty
    }
    It 'Has the shell set to "explorer.exe" at the global level (HKLM)' {

        Invoke-Command -Session $RemoteSession {
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon').Shell } |
        Should Be 'explorer.exe'
    }
}
Describe 'PowerShell prerequisites' {

    It 'Has the execution policy set to "RemoteSigned" or "Unrestricted"' {
        
        Invoke-Command -Session $RemoteSession {
        $Policy = (Get-ExecutionPolicy); $Policy -eq 'RemoteSigned' -or $Policy -eq 'Unrestricted' } |
        Should Be $True
    }
    It 'Has PowerShell version 4.0 or later' {
        
        Invoke-Command -Session $RemoteSession {
        $PSVersionTable.PSVersion -ge [System.Version]'4.0' } |
        Should Be $True
    }
    It 'Has the PackageManagement module installed' {
        
        Invoke-Command -Session $RemoteSession {
        Get-Module -Name 'PackageManagement' -ListAvailable } |
        Should Not BeNullOrEmpty
    }
}