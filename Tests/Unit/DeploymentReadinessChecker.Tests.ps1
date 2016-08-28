Import-Module "$($PSScriptRoot)\..\..\DeploymentReadinessChecker.psd1" -Force
$ModuleName = 'DeploymentReadinessChecker'
$OutputPath = 'TestDrive:\OutputFolder'

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
            
            Test-DeploymentReadiness -ComputerName Localhost -OutputPath $OutputPath
            Test-Path -Path $OutputPath -PathType Container |
            Should Be $True
        }
        It 'Should call Invoke-Pester once per Computer specified via the ComputerName parameter' {
            
            Test-DeploymentReadiness -ComputerName 'Server1','Server2','Server3' -OutputPath $OutputPath
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
        It 'Should call Invoke-Pester once per Computer specified via pipeline input' {
            
            '1','2','3' | Test-DeploymentReadiness -OutputPath $OutputPath
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
        It 'If the Credential parameter is specified, it should add it into the Script parameter of Invoke-Pester' {

            $Password = ConvertTo-SecureString 'TestPasswd' -AsPlainText -Force
            $TestCred = New-Object System.Management.Automation.PSCredential ('TestUser', $Password)

            Test-DeploymentReadiness -ComputerName 'Server1','Server2' -OutputPath $OutputPath -Credential $TestCred
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
    Context 'General Function behaviour' {
        
        Mock -ModuleName $ModuleName Invoke-Pester { }
        Mock -ModuleName $ModuleName Get-ChildItem { } -ParameterFilter {$Path -eq "$OutputPath\Index.html"}
        Mock -ModuleName $ModuleName Invoke-ReportUnit { }

        It 'Should call ReportUnit only once, even when there are multiple computers' {
            
            Test-DeploymentReadiness -ComputerName 'Server1','Server2','Server3' -OutputPath $OutputPath
            Assert-MockCalled Invoke-ReportUnit -Exactly 1 -Scope It -ModuleName $ModuleName
        }
        It 'Should call ReportUnit only once, even with multiple computers specified via pipeline input' {
            
            '1','2','3' | Test-DeploymentReadiness -OutputPath $OutputPath
            Assert-MockCalled Invoke-ReportUnit -Exactly 1 -Scope It -ModuleName $ModuleName
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
