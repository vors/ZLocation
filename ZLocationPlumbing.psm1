Set-StrictMode -Version Latest

#
# Return ready-to-use ZLocation.IService proxy.
# Starts service side, if nessesary
#
function Get-ZService()
{
    $baseAddress = "net.pipe://localhost"
    $pipename = "zlocation"
    $backupFilePath = Join-Path $env:HOMEDRIVE (Join-Path $env:HOMEPATH "z-location.txt")

    #
    # Add nessesary types.
    # Time consuming, don't run it too often.
    #
    function Set-Types()
    {
        Add-Type -AssemblyName System.ServiceModel
        $csCode = cat (Join-Path $PSScriptRoot "service.cs") -Raw
        Add-Type -ReferencedAssemblies System.ServiceModel -TypeDefinition $csCode
    }

    #
    # Return cached proxy, or create a new one, if -Force
    #
    function Get-ZServiceProxy([switch]$Force)
    {
        if ((-not (Test-Path variable:Script:pipeProxy)) -or $Force) 
        {
            Set-Types
            $binding = [System.ServiceModel.NetNamedPipeBinding]::new()
            $binding.OpenTimeout = [timespan]::MaxValue
            $pipeFactory = [System.ServiceModel.ChannelFactory[ZLocation.IService]]::new(
                $binding, 
                [System.ServiceModel.EndpointAddress]::new("$($baseAddress)/$($pipename)"))    
            $Script:pipeProxy = $pipeFactory.CreateChannel()
        }
        $Script:pipeProxy
    }

    #
    # 
    #
    function Start-ZService()
    {
        Set-Types
        $service = [System.ServiceModel.ServiceHost]::new([ZLocation.Service]::new($backupFilePath), [uri]($baseAddress))
        $service.AddServiceEndpoint([ZLocation.IService], [System.ServiceModel.NetNamedPipeBinding]::new(), $pipename) > $null
        $service.Open() > $null
    }

    $service = Get-ZServiceProxy
    $retryCount = 0
    while ($true) 
    {
        $retryCount++
        try {
            $service.Noop()
            break;
        } catch {
            if ($retryCount -gt 1)
            {
                Write-Error "Cannot connect to a storage service. $_"
                break;
            }
            Start-ZService
            $service = Get-ZServiceProxy -Force
        }
    }

    $service
}

function Get-ZLocation()
{
    $service = Get-ZService
    $hash = @{}
    foreach ($item in $service.Get()) 
    {
        $hash.add($item.Key, $item.Value)
    }    
    return $hash
}

function Add-ZWeight([string]$path, [double]$weight) {
    $service = Get-ZService
    $service.Add($path, $weight)
}


# init service
# Get-ZService > $null

Export-ModuleMember -Function @("Get-ZLocation", "Add-ZWeight")
