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
            
            Test-DeploymentReadiness -ComputerName Localhost,Localhost,Localhost -OutputPath 'TestDrive:\OutputFolder'
            Assert-MockCalled Invoke-Pester -Exactly 3 -Scope It -ModuleName $ModuleName
        }
    }
}
