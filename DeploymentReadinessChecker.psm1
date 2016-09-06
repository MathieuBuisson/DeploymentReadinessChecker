#Requires -Version 4
#Requires -Modules 'Pester'

Function Test-DeploymentReadiness {

<#
.SYNOPSIS
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.

.DESCRIPTION
    Validates that one or more computers meet the prerequisites for a software deployment/upgrade.
    It generates a NUnit-style test result file for each computer and creates a visual, dynamic HTLM report encompassing data from all the test results.
    The list of computers to check is specified via the ComputerName parameter.
    
    The deployment or upgrade prerequisites are specified in a Pester-based validation script located in the sub-directory \ReadinessValidationScript.
    Test-DeploymentReadiness can only invoke one validation script at a time, even if there are multiple scripts named *.Tests.ps1 in the ReadinessValidationScript sub-directory.

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

.PARAMETER ValidationScript
    This is a dynamic parameter which is made available (and mandatory) whenever there is more than one test script in the sub-folder \ReadinessValidationScript\.
    This is because Test-DeploymentReadiness can only invoke one validation script at a time, so if there is more than one, the user has to specify which one.

    This parameter expects the name (not the full path) of one of the test file present in <ModuleFolder>\ReadinessValidationScript\.
    If no value is specified when there is more than one validation script available, the error message will tell the user what are the possible values.
    (See the last example in the Examples section of the help.)
    
.EXAMPLE
    Test-DeploymentReadiness -ComputerName (Get-Content .\Computers_List.txt) -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport

    Validates that all the computers with the name listed in the file Computers_list.txt meet the prerequisites specified in a validation script located in the sub-directory \ReadinessValidationScript.

.EXAMPLE
    $TestParams = @{ DeploymentServerName = $DeploymentServerName; ManagementServerName = $ManagementServerName }
    Test-DeploymentReadiness -ComputerName 'Server1','Server2' -Credential (Get-Credential) -TestParameters $TestParams

    Validates that all the computers with the name listed in the file Computers_list.txt meet the prerequisites specified in a validation script located in the sub-directory \ReadinessValidationScript.
    It uses a hashtable ($TestParams) to pass parameter names and values to the validation script.

.EXAMPLE
    'Computer1','Computer2','Computer3' | Test-DeploymentReadiness -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport
    
    Validates that all the computers specified via pipeline input meet the prerequisites specified in a validation script located in the sub-directory \ReadinessValidationScript.

.EXAMPLE
    Test-DeploymentReadiness -ComputerName (Get-Content .\Computers_List.txt) -Credential (Get-Credential) -OutputPath $env:USERPROFILE\Desktop\DeploymentReadinessReport
    
cmdlet Test-DeploymentReadiness at command pipeline position 1
Supply values for the following parameters:
(Type !? for Help.)
ValidationScript: 
Test-DeploymentReadiness : Cannot validate argument on parameter 
'ValidationScript'. The argument "" does not belong to the set 
"ClientDeployment.Tests.ps1,Example.Tests.ps1" specified by the ValidateSet 
attribute. Supply an argument that is in the set and then try the command again.
At line:1 char:1
+ Test-DeploymentReadiness -ComputerName 'Devops-test-dscnuc' -OutputPa ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidData: (:) [Test-DeploymentReadiness], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Test-DeploymentReadiness


    In this case, there is more than one validation script in the sub-folder \ReadinessValidationScript\, so the user has to specify the name of the validation script via the ValidationScript parameter.
    Note that the error message provides the set of possible values ("ClientDeployment.Tests.ps1" and "Example.Tests.ps1", here).
   
.NOTES
    Author : Mathieu Buisson
    
.LINK
    https://github.com/MathieuBuisson/DeploymentReadinessChecker
#>

[cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline=$True, Mandatory=$True, Position=0)]
        [string[]]$ComputerName,

        [Parameter(Position=1)]
        [pscredential]$Credential,

        [Parameter(Position=2)]
        [string]$OutputPath = $($pwd.ProviderPath),

        [Parameter(Position=3)]
        [hashtable]$TestParameters,

        [Parameter(Position=4)]
        [Alias('Tags')]
        [string[]]$Tag,

        [Parameter(Position=5)]
        [Alias('ExcludeTags')]
        [string[]]$ExcludeTag
    )
    DynamicParam {
        # The ValidationScript parameter is made available (and mandatory) only there is more than one test script in the sub-folder \ReadinessValidationScript\.
        If ( (Get-ChildItem -Path "$PSScriptRoot\ReadinessValidationScript\" -Filter '*.Tests.ps1').Count -gt 1 ) {
            
            $ParameterName = 'ValidationScript'
            
            # Creating a parameter dictionary 
            $RuntimeParameterDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary

            # Creating an empty collection of parameter attributes
            $AttributeCollection = New-Object -TypeName System.Collections.ObjectModel.Collection[System.Attribute]
            
            # Setting parameter attributes and values
            $ValidationScriptAttribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
            $ValidationScriptAttribute.Mandatory = $True
            $ValidationScriptAttribute.Position = 6
            $ValidationScriptAttribute.HelpMessage = "There was more than one test script found in $PSScriptRoot\ReadinessValidationScript\. `r`nPlease specify the name of the test script to use. `r`nTip : Use Tab completion to see the possible script names."

            # Adding the parameter attributes to the attributes collection
            $AttributeCollection.Add($ValidationScriptAttribute)

            # Generating dynamic values for a ValidateSet
            $SetValues = Get-ChildItem "$PSScriptRoot\ReadinessValidationScript" -Filter '*.Tests.ps1' | Select-Object -ExpandProperty Name
            $ValidateSetAttribute = New-Object -TypeName System.Management.Automation.ValidateSetAttribute($SetValues)

            # Adding the ValidateSet to the attributes collection
            $AttributeCollection.Add($ValidateSetAttribute)

            # Creating the dynamic parameter
            $RuntimeParameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
            return $RuntimeParameterDictionary
        }
    }

    Begin {
        
        If ( -not(Test-Path -Path $OutputPath) ) {
            New-Item -ItemType Directory -Path $OutputPath -Force
        }

        # Checking if the validation script has a ComputerName parameter
        If ( $PSBoundParameters.ContainsKey('ValidationScript') ) {
            $ValidationScriptFile = Join-Path -Path "$PSScriptRoot\ReadinessValidationScript" -ChildPath $PSBoundParameters.ValidationScript
        }
        Else {
            $ValidationScriptFile = (Get-ChildItem -Path "$PSScriptRoot\ReadinessValidationScript\" -Filter '*.Tests.ps1').FullName
        }
        Write-Verbose "The validation script file is : $ValidationScriptFile"
        
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
                    Path = $ValidationScriptFile
                    Parameters = $TestParameters
                }
            }
            Else {
                $ScriptParameters = @{
                    Path = $ValidationScriptFile
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
        Invoke-ReportUnit -OutputPath $OutputPath
    }
}

# Wrapper function to call ReportUnit.exe, this is mainly to be able to mock ReportUnit calls
Function Invoke-ReportUnit ($OutputPath) {
    
    $ReportUnitPath = "$PSScriptRoot\ReportUnit\ReportUnit.exe"
    $Null = & $ReportUnitPath $OutputPath
    If ( $LASTEXITCODE -eq 0 ) {
        Write-Host "`r`nThe deployment readiness report has been successfully created."
        Write-Host "To view the report, please open the following file : $(Join-Path -Path $OutputPath -ChildPath 'Index.html')"

        # It maybe be useful to output the file containing the overview report to the pipeline, in case the user wants to do something with it.
        Get-ChildItem -Path (Join-Path -Path $OutputPath -ChildPath 'Index.html')
    }
    Else {
        Write-Error "An error occurred when ReportUnit was generating HTML reports from the Pester test results. To troubleshoot this, try running '$PSScriptRoot\ReportUnit\ReportUnit.exe' manually to see the actual error message."
    }
}

New-Alias -Name 'tdr' -Value 'Test-DeploymentReadiness'
Export-ModuleMember -Function 'Test-DeploymentReadiness' -Alias 'tdr'