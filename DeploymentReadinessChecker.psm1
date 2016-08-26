#Requires -Version 4
#Requires -Modules 'Pester'

Function Test-DeploymentReadiness {

<#
.SYNOPSIS
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.

.DESCRIPTION
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.
    The list of computers to check is specified via the ComputerName parameter.
    
    The deployment or upgrade prerequisites are specified in a Pester-based validation script located in the sub-directory .\ReadinessValidationScript.
    All the prerequisites tests should be in a single validation script, so there should be only one file named *.Tests.ps1 in the ReadinessValidationScript sub-directory.

    It generates a NUnit-style test results file for each computer and a summary report in HTML format.

.PARAMETER ComputerName
    To specify one or more computers against which the prerequisites checks will be performed.

    If the validation script has a ComputerName parameter, the function passes one computer at a time to its ComputerName parameter, via the Script parameter of Invoke-Pester.

.PARAMETER Credential
    To specify the credentials to connect remotely to the target computers.

    If the validation script has a Credential parameter, the function passes the value of its own Credential parameter to the validation script, via the Script parameter of Invoke-Pester.

.PARAMETER OutputPath
    To specify in which directory the output test results files and the summary report should be located.
    If the directory doesn't exist, it will be created.
    If not specified, the defaut output path is the current directory.

.PARAMETER TestParameters
    If the test script used to validate the prerequisites take parameters, their names and values can be specified as a hashtable via this parameter.
    Then, the function will pass these into the Script parameter of Invoke-Pester, when calling the validation script.
    To see the format of the hashtable for this parameter, please refer to the examples by running : Get-Help Test-DeploymentReadiness -Examples

.PARAMETER Tag
    If the Pester validation script contains Describe blocks with tags, only the tests in Describe blocks with the specified Tag parameter value(s) are run.
    Wildcard characters and Tag values that include spaces or whitespace characters are not supported.

.PARAMETER ExcludeTag
    If the Pester validation script contains Describe blocks with tags, tests in Describe blocks with the specified Tag parameter values are omitted.
    Wildcard characters and Tag values that include spaces or whitespace characters are not supported.

    Just like the ExcludeTag parameter of Invoke-Pester, when you specify multiple ExcludeTag values, this omits tests that have any of the listed tags (it ORs the tags).
    
.EXAMPLE
    Test-DeploymentReadiness -ComputerName (Get-Content .\Computers_List.txt) -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport

.EXAMPLE
    $TestParams = @{ DeploymentServerName = $DeploymentServerName; ManagementServerName = $ManagementServerName }
    Test-DeploymentReadiness -ComputerName 'Server1','Server2' -Credential (Get-Credential) -TestParameters $TestParams
    
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
        [hashtable]$TestParameters, #= @{ DeploymentServerName = $DeploymentServerName
                                   #     ManagementServerName = $ManagementServerName
                                   # }
        [Parameter(Position=4)]
        [Alias('Tags')]
        [string[]]$Tag,

        [Parameter(Position=5)]
        [Alias('ExcludeTags')]
        [string[]]$ExcludeTag
    )

    Begin {
        
        If ( -not(Test-Path -Path $OutputPath) ) {
            New-Item -ItemType Directory -Path $OutputPath -Force
        }

        # Checking if the validation script has a ComputerName parameter
        $ValidationScriptFile = (Get-ChildItem -Path "$PSScriptRoot\ReadinessValidationScript\" -Recurse -Filter '*.Tests.ps1').FullName
        If ( $ValidationScriptFile.Count -gt 1 ) {
            Throw "Having more than 1 file named *.Tests.ps1 in the 'ReadinessValidationScript' directory is not supported."
        }
        Write-Verbose "The detected validation script file is : $ValidationScriptFile"
        
        $ScriptInfo = Get-Command $ValidationScriptFile
        [System.Boolean]$HasComputerNameParameter = $ScriptInfo.Parameters.Keys -contains 'ComputerName'
        Write-Verbose "Does the Pester validation script have a ComputerName parameter ? $($HasComputerNameParameter)."

        # Checking if credentials to connect to target computers were specified
        If ( $PSBoundParameters.ContainsKey('Credential') ) {
            $CredentialSpecified = $True
        }

        # Checking if the validation script has a Credential parameter
        [System.Boolean]$HasCredentialParameter = $ScriptInfo.Parameters.Keys -contains 'Credential'
        Write-Verbose "Does the Pester validation script have a Credential parameter ? $($HasCredentialParameter)."

        # Setting tag filtering parameters to pass to Invoke-Pester if the Tag or ExcludeTag parameter is specified
        If ( $PSBoundParameters.ContainsKey('Tag') -or $PSBoundParameters.ContainsKey('ExcludeTag') ) {
            
            [hashtable]$TagFilteringParameters = @{}
            Write-Verbose 'Tag filtering is ON.'

            If ( $PSBoundParameters.ContainsKey('Tag') ) {
                $TagFilteringParameters.Add('Tag', $Tag)
            }
            If ( $PSBoundParameters.ContainsKey('ExcludeTag') ) {
                $TagFilteringParameters.Add('ExcludeTag', $ExcludeTag)
            }
        }
    }
    Process {
        
        # If the validation script has a Credential parameter, the function passes the value of
        # its own Credential parameter to the validation script, via the Script parameter of Invoke-Pester.
        If ( $CredentialSpecified -and $HasCredentialParameter ) {

            If ( $PSBoundParameters.ContainsKey('TestParameters') ) {
                If ( $TestParameters.Credential ) {
                    $TestParameters.Credential = $Credential
                }
                Else {
                    $TestParameters.Add('Credential', $Credential)
                }
            }
            Else {
                $TestParameters = @{ Credential = $Credential }
            }
        }
        
        Foreach ( $Computer in $ComputerName ) {
            
            # If the validation script has a ComputerName parameter, the function passes one computer at a
            # time to the validation script's ComputerName parameter, via the Script parameter of Invoke-Pester.
            If ( $HasComputerNameParameter ) {

                If ( $TestParameters ) {
                    If ( $TestParameters.ComputerName ) {
                        $TestParameters.ComputerName = $Computer
                    }
                    Else {
                        $TestParameters.Add('ComputerName', $Computer)
                    }
                }
                Else {
                    $TestParameters = @{ ComputerName = $Computer }
                }
            }

            # Building the hashtable to pass parameters to the Pester validation script via the Script parameter of Invoke-Pester
            If ( $TestParameters ) {
                Foreach ( $Key in $TestParameters.Keys ) {
                    Write-Verbose "Parameter passed to the validation script. Key : $Key, Value : $($TestParameters.$Key)"
                }

                $ScriptParameters = @{
                    Path = "$PSScriptRoot\ReadinessValidationScript\*"
                    Parameters = $TestParameters
                }
            }
            Else {
                $ScriptParameters = @{
                    Path = "$PSScriptRoot\ReadinessValidationScript\*"
                }
            }

            Write-Verbose "Running Pester validation script against computer : $Computer"
            If ( $TagFilteringParameters ) {
                Invoke-Pester -Script $ScriptParameters -OutputFile "$OutputPath\$Computer.xml" -OutputFormat NUnitXml @TagFilteringParameters
            }
            Else {
                Invoke-Pester -Script $ScriptParameters -OutputFile "$OutputPath\$Computer.xml" -OutputFormat NUnitXml
            }
        }
    }
    End {
        $ReportUnitPath = "$PSScriptRoot\ReportUnit\ReportUnit.exe"
        $Null = & $ReportUnitPath $OutputPath
        If ( $LASTEXITCODE -eq 0 ) {
            Write-Host "`r`nThe deployment readiness report has been successfully created."
            Write-Host "To view the report, please open the following file : $OutputPath\Index.html"

            # It maybe be useful to output the file containing the overview report to the pipeline, in case the user wants to do something with it.
            Get-ChildItem -Path (Join-Path -Path $OutputPath -ChildPath 'Index.html')
        }
        Else {
            Write-Error "An error occurred when ReportUnit was generating HTML reports from the Pester test results. To troubleshoot this, try running '$PSScriptRoot\ReportUnit\ReportUnit.exe' manually to see the actual error message."
        }
    }
}
New-Alias -Name 'tdr' -Value 'Test-DeploymentReadiness'
Export-ModuleMember -Function 'Test-DeploymentReadiness' -Alias 'tdr'