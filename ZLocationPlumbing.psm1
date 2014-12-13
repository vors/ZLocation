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

    function log([string] $message)
    {
         Write-Host -ForegroundColor Yellow "[ZLocation] $message"
    }

    #
    # Add nessesary types.
    # Time consuming, don't run it too often.
    #
    function Set-Types()
    {
        log "Enter Set-Types"
        if ("ZLocation.IService" -as [type])
        {
            log "[ZLocation] Types already added"
            return
        }
        $smaTime = Measure-Command { Add-Type -AssemblyName System.ServiceModel }
        log "Add System.ServiceModel assembly in $($smaTime.TotalSeconds) sec"
        $csCode = cat (Join-Path $PSScriptRoot "service.cs") -Raw
        $serviceTime = Measure-Command { Add-Type -ReferencedAssemblies System.ServiceModel -TypeDefinition $csCode }
        log "Compile and add ZLocation storage service in $($serviceTime.TotalSeconds) sec"
    }

    #
    # Called only if Types are already populated
    #
    function Get-Binding()
    {
        if (-not (Test-Path variable:Script:binding)) {
            log "Create new .NET pipe service binding"
            $Script:binding = [System.ServiceModel.NetNamedPipeBinding]::new()
            $Script:binding.OpenTimeout = [timespan]::MaxValue
            $Script:binding.CloseTimeout = [timespan]::MaxValue
            $Script:binding.ReceiveTimeout = [timespan]::MaxValue
            $Script:binding.SendTimeout = [timespan]::MaxValue
        }
        return $Script:binding
    }

    #
    # Return cached proxy, or create a new one, if -Force
    #
    function Get-ZServiceProxy([switch]$Force)
    {
        if ((-not (Test-Path variable:Script:pipeProxy)) -or $Force) 
        {
            Set-Types
            $pipeFactory = [System.ServiceModel.ChannelFactory[ZLocation.IService]]::new(
                (Get-Binding), 
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

        # It will be usefull to add debugBehaviour, like this
        # $debugBehaviour = $service.Description.Behaviors.Find[System.ServiceModel.Description.ServiceDebugBehavior]();
        # $debugBehaviour = [System.ServiceModel.Description.ServiceDebugBehavior]::new()
        # $debugBehaviour.IncludeExceptionDetailInFaults = $true
        # $service.Description.Behaviors.Add($debugBehaviour);

        $service.AddServiceEndpoint([ZLocation.IService], (Get-Binding), $pipename) > $null
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

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    #TODO add cleanup
    Write-Warning "[ZLocation] currently cleanup logic is not implemented."
}

Export-ModuleMember -Function @("Get-ZLocation", "Add-ZWeight")
