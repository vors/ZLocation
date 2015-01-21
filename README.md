[![Build status](https://ci.appveyor.com/api/projects/status/qqg75o50jj6e35mn?svg=true)](https://ci.appveyor.com/project/vors/zlocation)

ZLocation
=========

ZLocation is the new [Jump-Location](https://github.com/tkellogg/Jump-Location).

Install
=========
Module has not been published yet, but you can clone dev version from this repo.

You can put something similar to your `$profile` file.
```powershell
Import-Module C:\dev\ZLocation\ZLocation
Write-Host -Fore Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"
```
