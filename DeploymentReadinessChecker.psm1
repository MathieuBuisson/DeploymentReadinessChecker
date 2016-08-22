#Requires -Version 4
#Requires -Modules 'Pester'

Function Test-DeploymentReadiness {

<#
.SYNOPSIS
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.

.DESCRIPTION
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.
    The list of computers to check is specified via the ComputerName parameter.
    The deployment or upgrade prerequisites are specified in one or more Pester-based test scripts
    located in the same directory as the module or in a sub-directory.

    It generates a NUnit-style test results file for each computer and a summary report in HTML format.

.PARAMETER ComputerName
    To specify one or more computers against which the prerequisites checks will be performed.

.PARAMETER Credential
    To specify the credentials to connect remotely to the target computers.

.PARAMETER OutputPath
    To specify in which directory the output test results files and the summary report should be located.
    If the directory doesn't exist, it will be created.
    If not specified, the defaut output path is the current directory.

.PARAMETER TestParameters
    If the test script(s) used to validate the prerequisites take parameters, their names and values can be specified as a hashtable via this parameter.
    Then, the function will pass these into the Script parameter of Invoke-Pester, when calling the test script(s).
    
.EXAMPLE
    Test-DeploymentReadiness -ComputerName (Get-Content .\Computers_List.txt) -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport

.EXAMPLE

.NOTES
    Author : Mathieu Buisson
    
.LINK
    https://github.com/MathieuBuisson/DeploymentReadinessChecker
#>

[cmdletbinding()]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string[]]$ComputerName,

        [Parameter(Mandatory=$True, Position=1)]
        [pscredential]$Credential,

        [Parameter(Position=2)]
        [string]$OutputPath = $($pwd.ProviderPath),

        [Parameter(Position=3)]
        [hashtable]$TestParameters #= @{ ComputerName = $ComputerName
                                           #     Credential = $Credential
                                           #     DeploymentServerName = $DeploymentServerName
                                           #     ManagementServerName = $ManagementServerName
                                           # }
    )

    Begin {
    }
    Process {

        Foreach ( $Computer in $ComputerName ) {
        
            $ScriptParameters = @{
                Path = "$PSScriptRoot\*"
                Parameters = $TestParameters
            }

            Invoke-Pester -Script $ScriptParameters -OutputFile "$OutputPath\$Computer.xml" -OutputFormat NUnitXml
        }
    }
    End {
    }
}
New-Alias -Name 'tdr' -Value 'Test-DeploymentReadiness'
Export-ModuleMember -Function 'Test-DeploymentReadiness' -Alias 'tdr'