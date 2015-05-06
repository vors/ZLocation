[![Build status](https://ci.appveyor.com/api/projects/status/qqg75o50jj6e35mn/branch/master?svg=true)](https://ci.appveyor.com/project/vors/zlocation/branch/master)

ZLocation
=========

[![Join the chat at https://gitter.im/vors/ZLocation](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/vors/ZLocation?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

ZLocation is the successor of [Jump-Location](https://github.com/tkellogg/Jump-Location).
Like [z.sh](https://github.com/rupa/z) is a reimagined clone of [autojump](https://github.com/joelthelion/autojump), Zlocation is a reimagined clone of Jump-Location.

If you have an expirience with autojump, j.sh, z.sh or Jump-Location, you will understand concepts immidiatly.

##Usage

ZLocation keep track of your `$pwd` (current folder).
Once visited, folder become known to ZLocation.
You can `cd` with just a hint of the path!

The full command name is `Set-ZLocation`, but in examples I use alias `z`. 
It's all about navigation speed, isn't it?

```
PS C:\Users\sevoroby> z c:
PS C:\> z zlo
PS C:\dev\ZLocation> z dsc
PS C:\dev\azure-sdk-tools\src\ServiceManagement\Compute\Commands.ServiceManagement\IaaS\Extensions\DSC> z test
PS C:\dev\ZLocation\ZLocation.Tests>
```

##Goals / Key features
*  Support for mutliple PS sessions.
*  Customizable matching algorithm and weight function.

##Install
Install from [PowerShellGet Gallery](https://www.powershellgallery.com/packages/ZLocation/)
```powershell
Find-Module ZLocation | Install-Module
```

Make sure to **include ZLocation import in your `$profile`**.
It intentianally doesn't alternate `$profile` automatically on installation.

```powershell
Import-Module ZLocation
```

If you want to display some additional information about ZLocation on startup, you can put this snippet in `$profile` after import. 
```powershell
Write-Host -Foreground Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"
```
