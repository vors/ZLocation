@{
ModuleVersion = '1.0'
GUID = '3d256bab-55d1-459c-8673-1d9d7ca8554a'
# Assembly must be loaded first or else powershell class will fail to compile
RequiredAssemblies = @("$PSScriptRoot/LiteDB/LiteDB.dll")
RootModule = 'ZLocation.Service.psm1'
FunctionsToExport = @('Get-ZService')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
PrivateData = @{
    PSData = @{}
}
}

