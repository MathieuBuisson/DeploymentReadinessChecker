Import-Module "$($PSScriptRoot)\..\..\DeploymentReadinessChecker.psd1" -Force
$ModuleName = 'DeploymentReadinessChecker'

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

        It "If the directory specified via the parameter 'OutputPath' doesn't exist, it should create it" {
            
            Test-DeploymentReadiness -ComputerName Localhost -OutputPath 'TestDrive:\OutputFolder'
            Test-Path -Path 'TestDrive:\OutputFolder' -PathType Container |
            Should Be $True
        }
        It 'Should call Invoke-Pester once per Computer specified via the ComputerName parameter' {
            
            Test-DeploymentReadiness -ComputerName 'Server1','Server2','Server3' -OutputPath 'TestDrive:\OutputFolder'
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
        It 'If the Credential parameter is specified, it should add it into the Script parameter of Invoke-Pester' {

            $Password = ConvertTo-SecureString 'TestPasswd' -AsPlainText -Force
            $TestCred = New-Object System.Management.Automation.PSCredential ('TestUser', $Password)

            Test-DeploymentReadiness -ComputerName 'Server1','Server2' -OutputPath 'TestDrive:\OutputFolder' -Credential $TestCred
            Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
            $Script.Parameters.Credential -eq $TestCred
            }
        }
        It 'If the TestParameters parameter is specified, it should add all its key-value pairs into the Script parameter of Invoke-Pester' {
            
            $TestParams = @{PesterScriptParam1 = 'Param1Value'
                            PesterScriptParam2 = 'Param2Value'
                        }
            Test-DeploymentReadiness -ComputerName 'Server1' -TestParameters $TestParams
            Foreach ( $Key in $TestParams.Keys ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $Script.Parameters.$Key -eq $TestParams.$Key
                }
            }
        }
        It 'Should pass all values in the Tag parameter to Invoke-Pester' {
            
            $TestTags = 'Tag1','Tag2','Tag3'
            Test-DeploymentReadiness -ComputerName 'Server1' -Tag $TestTags
            Foreach ( $TestTag in $TestTags ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $Tag -contains $TestTag
                }
            }
        }
        It 'Should pass all values in the ExcludeTag parameter to Invoke-Pester' {
            
            $TestExcludeTags = 'ExcludeTag1','ExcludeTag2'
            Test-DeploymentReadiness -ComputerName 'Server1' -ExcludeTag $TestExcludeTags
            Foreach ( $TestExcludeTag in $TestExcludeTags ) {
                Assert-MockCalled Invoke-Pester -Scope It -ModuleName $ModuleName -ParameterFilter {
                    $ExcludeTag -contains $TestExcludeTag
                }
            }
        }
    }
}
