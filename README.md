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
Module has not been published yet, but you can clone dev version from this repo.
The plan is to publish it on [PsGet](http://psget.net/) gallery.

Put something similar to your `$profile` file.
```powershell
Import-Module C:\dev\ZLocation\ZLocation
Write-Host -Fore Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"
```
