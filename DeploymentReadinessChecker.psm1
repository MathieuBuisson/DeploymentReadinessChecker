#Requires -Version 3
#Requires -Modules 'Pester'

Function Test-DeploymentReadiness {

<#
.SYNOPSIS
    

.DESCRIPTION
    

.PARAMETER ParamName

.PARAMETER ParamName

.EXAMPLE

.EXAMPLE

.NOTES
    Author : Mathieu Buisson
    
.LINK

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
