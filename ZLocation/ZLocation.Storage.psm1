Set-StrictMode -Version Latest

$script:alreadyFailed = $false

function Get-ZLocationBackupFilePath
{
    return (Join-Path $env:USERPROFILE 'z-location.txt')
}

function Get-ZLocationPipename
{
    return 'zlocation' + $env:USERNAME
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
        $Script:pipeProxy = New-ServiceProxy
    }
    $Script:pipeProxy
}

#
# Return ready-to-use ZLocation.IService proxy.
# Starts service server side, if necessary
# There is an issue https://github.com/vors/ZLocation/issues/1
# We still cannot guarantee 100% availability.
# We want to fail gracefully, and print warning.
#
function Get-ZService()
{
    function log([string] $message)
    {
        # You can replace logs for development, i.e:
        # Write-Host -ForegroundColor Yellow "[ZLocation] $message"
        Write-Verbose "[ZLocation] $message"
    }

    #
    # Add necessary types.
    #
    function Set-Types()
    {
        log "Enter Set-Types"
        if ("ZLocation.IService" -as [type])
        {
            log "[ZLocation] Types already added"
            return
        }
        $csCode = Get-Content (Join-Path $PSScriptRoot "service.cs") -Raw
        $csCode2 = Get-Content (Join-Path $PSScriptRoot "named-pipe-ipc.cs") -Raw
        $serviceTime = Measure-Command {
            Add-Type -TypeDefinition $csCode
            Add-Type -TypeDefinition $csCode2
        }
        log "Compile and add ZLocation storage service in $($serviceTime.TotalSeconds) sec"
        Import-Module (Join-Path $PSScriptRoot "service.psm1")
    }

    #
    # 
    #
    function Start-ZService()
    {
        Set-Types
        $Script:service = New-ServiceHost(New-Object ZLocation.Service((Get-ZLocationBackupFilePath)))
    }

    $service = Get-ZServiceProxy
    $retryCount = 0
    
    # This while loop is horrible, sorry future me.
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
                # This is the codepath that causes rear problems with broken pipe (https://github.com/vors/ZLocation/issues/1)
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
