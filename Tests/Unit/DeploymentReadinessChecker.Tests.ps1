Import-Module "$($PSScriptRoot)\..\..\DeploymentReadinessChecker.psd1" -Force
$ModuleName = 'DeploymentReadinessChecker'
$OutputPath = 'TestDrive:\OutputFolder'
$ComputerNames = 'Computer1','Computer2','Computer3'
$ScriptInfo = Get-Command (Get-ChildItem -Path "$PSScriptRoot\..\..\ReadinessValidationScript\" -Filter '*.Tests.ps1')[0].FullName

Describe 'General Module behaviour' {
       
    $ModuleInfo = Get-Module -Name $ModuleName

    It 'Exports only the function "Test-DeploymentReadiness"' {

        $ModuleInfo.ExportedFunctions.Values.Name |
        Should Be 'Test-DeploymentReadiness'
    }
    It 'Exports only the alias "tdr"' {

        $ModuleInfo.ExportedAliases.Values.Name |
        Should Be 'tdr'
    }
    It 'The only required module should be Pester' {
        
        $ModuleInfo.RequiredModules.Name |
        Should Be 'Pester'
    }
}
Describe 'Test-DeploymentReadiness' {
    
    Context 'Parameters behaviour' {
        
        Mock -ModuleName $ModuleName Invoke-Pester { }
        Mock -ModuleName $ModuleName Get-ChildItem { } -ParameterFilter {$Path -eq "$OutputPath\Index.html"}
        Mock -ModuleName $ModuleName Invoke-ReportUnit { }

        It "If the directory specified via the parameter 'OutputPath' doesn't exist, it should create it" {
            
            Test-DeploymentReadiness -ComputerName $ComputerNames[0] -OutputPath $OutputPath
            Test-Path -Path $OutputPath -PathType Container |
            Should Be $True
        }
        It 'Should call Invoke-Pester once per Computer specified via the ComputerName parameter' {
            
            Test-DeploymentReadiness -ComputerName $ComputerNames -OutputPath $OutputPath
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
        It 'Should call Invoke-Pester once per Computer specified via pipeline input' {
            
            $ComputerNames | Test-DeploymentReadiness -OutputPath $OutputPath
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
        It 'If the Credential parameter is specified, it should add it into the Script parameter of Invoke-Pester' {

            $Password = ConvertTo-SecureString 'TestPasswd' -AsPlainText -Force
            $TestCred = New-Object System.Management.Automation.PSCredential ('TestUser', $Password)

            Test-DeploymentReadiness -ComputerName $ComputerNames -OutputPath $OutputPath -Credential $TestCred
            Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
            $Script.Parameters.Credential -eq $TestCred
            }
        }
        It 'If the TestParameters parameter is specified, it should add all its key-value pairs into the Script parameter of Invoke-Pester' {
            
            $TestParams = @{PesterScriptParam1 = 'Param1Value'
                            PesterScriptParam2 = 'Param2Value'
                        }
            Test-DeploymentReadiness -ComputerName $ComputerNames[0] -TestParameters $TestParams
            Foreach ( $Key in $TestParams.Keys ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $Script.Parameters.$Key -eq $TestParams.$Key
                }
            }
        }
        It 'Should pass all values in the Tag parameter to Invoke-Pester' {
            
            $TestTags = 'Tag1','Tag2','Tag3'
            Test-DeploymentReadiness -ComputerName $ComputerNames[0] -Tag $TestTags
            Foreach ( $TestTag in $TestTags ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $Tag -contains $TestTag
                }
            }
        }
        It 'Should pass all values in the ExcludeTag parameter to Invoke-Pester' {
            
            $TestExcludeTags = 'ExcludeTag1','ExcludeTag2'
            Test-DeploymentReadiness -ComputerName $ComputerNames[0] -ExcludeTag $TestExcludeTags
            Foreach ( $TestExcludeTag in $TestExcludeTags ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $ExcludeTag -contains $TestExcludeTag
                }
            }
        }
    }
    Context 'General Function behaviour' {
        
        Mock -ModuleName $ModuleName Invoke-Pester { }
        Mock -ModuleName $ModuleName Get-ChildItem { } -ParameterFilter {$Path -eq "$OutputPath\Index.html"}
        Mock -ModuleName $ModuleName Invoke-ReportUnit { }

        It 'Should call ReportUnit only once, even when there are multiple computers' {
            
            Test-DeploymentReadiness -ComputerName $ComputerNames -OutputPath $OutputPath
            Assert-MockCalled Invoke-ReportUnit -Exactly 1 -Scope It -ModuleName $ModuleName
        }
        It 'Should call ReportUnit only once, even with multiple computers specified via pipeline input' {
            
            $ComputerNames | Test-DeploymentReadiness -OutputPath $OutputPath
            Assert-MockCalled Invoke-ReportUnit -Exactly 1 -Scope It -ModuleName $ModuleName
        }
    }
}

Describe 'Dynamic parameter "ValidationScript"' {
        
    Mock -ModuleName $ModuleName Invoke-Pester { }
    Mock -ModuleName $ModuleName Get-ChildItem { } -ParameterFilter {$Path -eq "$OutputPath\Index.html"}
    Mock -ModuleName $ModuleName Get-ChildItem {
	        [PSCustomObject]@{ FullName = 'TestDrive:\Example1.Tests.ps1'; Name = 'Example1.Tests.ps1' },
	        [PSCustomObject]@{ FullName = 'TestDrive:\Example2.Tests.ps1'; Name = 'Example2.Tests.ps1' }
	    } -ParameterFilter {$Path -like '*ReadinessValidationScript*' -and $Filter -eq '*.Tests.ps1'}
    Mock -ModuleName $ModuleName Invoke-ReportUnit { }
    Mock -ModuleName $ModuleName Get-Command { $ScriptInfo }

    It "Should throw when the value for the ValidationScript doesn't belong to the ValidateSet" {

        {Test-DeploymentReadiness -ComputerName $ComputerNames[0] -ValidationScript 'NotThere.Tests.ps1'} |
        Should Throw 'does not belong to the set "Example1.Tests.ps1,Example2.Tests.ps1"'
    }
    It 'Should call Invoke-Pester with the validation script specified via the ValidationScript parameter' {

        Test-DeploymentReadiness -ComputerName $ComputerNames[0] -ValidationScript 'Example1.Tests.ps1'
        Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
            $Script.Path -like '*\ReadinessValidationScript\Example1.Tests.ps1'
        }
    }
}

Describe 'Invoke-ReportUnit' {
    
    InModuleScope $ModuleName {
        
        $OutputPath = 'TestDrive:\OutputFolder'

        Mock Invoke-Pester { }
        Mock Get-ChildItem { } -ParameterFilter {$Path -eq "$OutputPath\Index.html"}
        Mock Write-Host { }

        It 'Should call Get-ChildItem on "$OutputPath\Index.html"' {
            
            Invoke-ReportUnit -OutputPath $OutputPath
            Assert-MockCalled Get-ChildItem -Scope It -ParameterFilter {
                $Path -eq "$OutputPath\Index.html"
            }
        }
    }
}
