Set-StrictMode -Version Latest

$script:alreadyFailed = $false

function Get-ZLocationBackupFilePath
{
    return (Join-Path $env:HOMEDRIVE (Join-Path $env:HOMEPATH 'z-location.txt'))
}

function Get-ZLocationPipename
{
    return 'zlocation'
}

#
# Return cached proxy, or create a new one, if -Force
#
function Get-ZServiceProxy
{
    param(
        [switch]$Force
    )

    if ((-not (Test-Path variable:Script:pipeProxy)) -or $Force) 
    {
        Set-Types
        $pipeFactory = New-Object -TypeName 'System.ServiceModel.ChannelFactory`1[[ZLocation.IService]]' -ArgumentList @(
            (Get-Binding),        
            ( New-Object -TypeName 'System.ServiceModel.EndpointAddress' -ArgumentList ( $baseAddress + '/' + (Get-ZLocationPipename) ) )
        )    
        $Script:pipeProxy = $pipeFactory.CreateChannel()
    }
    $Script:pipeProxy
}

#
# Return ready-to-use ZLocation.IService proxy.
# Starts service server side, if nessesary
# There is an issue https://github.com/vors/ZLocation/issues/1
# We still cannot garante 100% availability.
# We want to fail gracefully, and print warning.
#
function Get-ZService()
{
    $baseAddress = "net.pipe://localhost"

    function log([string] $message)
    {
        # You can replace logs for development, i.e:
        # Write-Host -ForegroundColor Yellow "[ZLocation] $message"
        Write-Verbose "[ZLocation] $message"
    }

    #
    # Add nessesary types.
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
            $Script:binding = New-Object -TypeName 'System.ServiceModel.NetNamedPipeBinding'
            $Script:binding.OpenTimeout = [timespan]::MaxValue
            $Script:binding.CloseTimeout = [timespan]::MaxValue
            $Script:binding.ReceiveTimeout = [timespan]::MaxValue
            $Script:binding.SendTimeout = [timespan]::MaxValue
        }
        return $Script:binding
    }

    #
    # 
    #
    function Start-ZService()
    {
        Set-Types
        $service = New-Object 'System.ServiceModel.ServiceHost' -ArgumentList (
            (New-Object 'ZLocation.Service' -ArgumentList @( (Get-ZLocationBackupFilePath) ) ), 
            [uri]($baseAddress)
        )

        # It will be usefull to add debugBehaviour, like this
        # $debugBehaviour = $service.Description.Behaviors.Find[System.ServiceModel.Description.ServiceDebugBehavior]();
        # $debugBehaviour = [System.ServiceModel.Description.ServiceDebugBehavior]::new()
        # $debugBehaviour.IncludeExceptionDetailInFaults = $true
        # $service.Description.Behaviors.Add($debugBehaviour);

        $service.AddServiceEndpoint([ZLocation.IService], (Get-Binding), (Get-ZLocationPipename) ) > $null
        $service.Open() > $null
    }

    $service = Get-ZServiceProxy
    $retryCount = 0
    
    # This while loop is horible, sorry future me.
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
                return $null;
            }
            try
            {
                Start-ZService
                $service = Get-ZServiceProxy -Force
            } catch {
                # This is the codepath that cause rear problems with broken pipe (https://github.com/vors/ZLocation/issues/1)
                return $null
            }
            
        }
    }

    return $service
}

function Fail-Gracefully
{
    if (-not $script:alreadyFailed) {
        Write-Warning @'
ZLocation Pipe become broken :( ZLocation is now self-disabled. 
You need to restart all PowerShell instances to re-enable ZLocation.
Please continue your work and do it, when convinient.
You can report the problem on https://github.com/vors/ZLocation/issues
'@
        $script:alreadyFailed = $true
    }
}

function Get-ZLocation()
{
    $service = Get-ZService
    $hash = @{}
    if ($service) 
    {
        foreach ($item in $service.Get()) 
        {
            $hash.add($item.Key, $item.Value)
        }    
    } else {
        Fail-Gracefully
    }
    return $hash
}

function Add-ZWeight([string]$path, [double]$weight) {
    $service = Get-ZService
    if ($service)
    {
        $service.Add($path, $weight)
    } else {
        Fail-Gracefully    
    }
}

function Remove-ZLocation([string]$path) {
    $service = Get-ZService
    if ($service) 
    {
        $service.Remove($path)
    } else {
        Fail-Gracefully
    }
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Warning "[ZLocation] module was removed, but service was not closed."
}

Export-ModuleMember -Function @("Get-ZLocation", "Add-ZWeight", "Remove-ZLocation")
