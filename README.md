[![Build status](https://ci.appveyor.com/api/projects/status/qqg75o50jj6e35mn/branch/master?svg=true)](https://ci.appveyor.com/project/vors/zlocation/branch/master)
[![Build status](https://travis-ci.org/vors/ZLocation.svg?branch=master)](https://travis-ci.org/vors/ZLocation)

ZLocation
=========

[![Join the chat at https://gitter.im/vors/ZLocation](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/vors/ZLocation?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Tracks your most used directories, based on number of previously run commands.
After  a  short  learning  phase, `z` will take you to the most popular directory that matches all of the regular expressions given on the command line.
You can use **Tab-Completion / Intellisense** to pick directories that are not the first choice.

ZLocation is the successor of [Jump-Location](https://github.com/tkellogg/Jump-Location).
Like [z.sh](https://github.com/rupa/z) is a reimagined clone of [autojump](https://github.com/joelthelion/autojump), Zlocation is a reimagined clone of Jump-Location.

Usage
-----

ZLocation keeps track of your `$pwd` (current folder).
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

Goals / Key features
--------------------

*  Support for multiple PS sessions.
*  Customizable matching algorithm and weight function.

## Install
Install from [PowerShellGet Gallery](https://www.powershellgallery.com/packages/ZLocation/)
```powershell
Install-Module ZLocation -Scope CurrentUser
```

Make sure to **include ZLocation import in your `$profile`**.
It intentionally doesn't alternate `$profile` automatically on installation.

This one-liner installs ZLocation, imports it and adds it to a profile.

```powershell
Install-Module ZLocation -Scope CurrentUser; Import-Module ZLocation; "`r`n`r`nImport-Module ZLocation`r`n" >> $profile.CurrentUserAllHosts
```

If you want to display some additional information about ZLocation on start-up, you can put this snippet in `$profile` after import. 
```powershell
Write-Host -Foreground Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"
```

Develop
-------

### Run tests

Install [Pester](https://github.com/pester/Pester).
Run `Invoke-Pester` from the root folder.
