#Requires -Version 4
#Requires -Modules 'Pester'

Function Test-DeploymentReadiness {

<#
.SYNOPSIS
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.

.DESCRIPTION
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.
    The list of computers to check is specified via the ComputerName parameter.
    
    The deployment or upgrade prerequisites are specified in a Pester-based validation script
    located in the sub-directory .\ReadinessValidationScript.
    All the prerequisites tests should be in a single validation script, so there should be only
    one file named *.Tests.ps1 in the ReadinessValidationScript sub-directory.

    It generates a NUnit-style test results file for each computer and a summary report in HTML format.

.PARAMETER ComputerName
    To specify one or more computers against which the prerequisites checks will be performed.

    If the validation script has a ComputerName parameter, the function passes one computer at a time
    to its ComputerName parameter, via the Script parameter of Invoke-Pester.

.PARAMETER Credential
    To specify the credentials to connect remotely to the target computers.

.PARAMETER OutputPath
    To specify in which directory the output test results files and the summary report should be located.
    If the directory doesn't exist, it will be created.
    If not specified, the defaut output path is the current directory.

.PARAMETER TestParameters
    If the test script(s) used to validate the prerequisites take parameters, their names and values can be specified as a hashtable via this parameter.
    Then, the function will pass these into the Script parameter of Invoke-Pester, when calling the test script(s).
    To see the format of the hashtable for this parameter, please refer to the examples by running : Get-Help Test-DeploymentReadiness -Examples
    
.EXAMPLE
    Test-DeploymentReadiness -ComputerName (Get-Content .\Computers_List.txt) -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport

.EXAMPLE
    $TestParams = @{Credential = (Get-Credential); DeploymentServerName = $DeploymentServerName; ManagementServerName = $ManagementServerName}
    Test-DeploymentReadiness -ComputerName 'Server1','Server2' -Credential (Get-Credential) 


.NOTES
    Author : Mathieu Buisson
    
.LINK
    https://github.com/MathieuBuisson/DeploymentReadinessChecker
#>

[cmdletbinding()]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string[]]$ComputerName,

        [Parameter(Position=1)]
        [pscredential]$Credential,

        [Parameter(Position=2)]
        [string]$OutputPath = $($pwd.ProviderPath),

        [Parameter(Position=3)]
        [hashtable]$TestParameters #= @{ Credential = $Credential
                                   #     DeploymentServerName = $DeploymentServerName
                                   #     ManagementServerName = $ManagementServerName
                                   # }
    )

    Begin {
        
        If ( -not(Test-Path -Path $OutputPath) ) {
            New-Item -ItemType Directory -Path $OutputPath -Force
        }

        # Checking if the validation script has a ComputerName parameter
        [System.Boolean]$HasComputerNameParameter = $False

        $ValidationScriptFile = (Get-ChildItem -Path "$PSScriptRoot\ReadinessValidationScript\" -Recurse -Filter '*.Tests.ps1').FullName
        If ( $ValidationScriptFile.Count -gt 1 ) {
            Throw "Having more than 1 file named *.Tests.ps1 in the 'ReadinessValidationScript' directory is not supported."
        }
        
        $ScriptInfo = Get-Command $ValidationScriptFile
        $HasComputerNameParameter = $ScriptInfo.Parameters.Keys -contains 'ComputerName'

    }
    Process {

        Foreach ( $Computer in $ComputerName ) {
            
            # If the validation script has a ComputerName parameter, the function
            # passes one computer at a time to its ComputerName parameter, via
            # the Script parameter of Invoke-Pester
            If ( $HasComputerNameParameter ) {

                If ( $TestParameters ) {
                    $TestParameters.Add('ComputerName', $Computer)
                }
                Else {
                    $TestParameters = @{ ComputerName = $Computer }
                }
            }

            # Building the hashtable to pass parameters to the Pester validation script via the Script parameter of Invoke-Pester
            If ( $TestParameters ) {
                $ScriptParameters = @{
                    Path = "$PSScriptRoot\ReadinessValidationScripts\*"
                    Parameters = $TestParameters
                }
            }
            Else {
                $ScriptParameters = @{
                    Path = "$PSScriptRoot\ReadinessValidationScripts\*"
                }
            }

            Invoke-Pester -Script $ScriptParameters -OutputFile "$OutputPath\$Computer.xml" -OutputFormat NUnitXml
        }
    }
    End {
    }
}
New-Alias -Name 'tdr' -Value 'Test-DeploymentReadiness'
Export-ModuleMember -Function 'Test-DeploymentReadiness' -Alias 'tdr'