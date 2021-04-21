[![Build status](https://ci.appveyor.com/api/projects/status/qqg75o50jj6e35mn/branch/master?svg=true)](https://ci.appveyor.com/project/vors/zlocation/branch/master)

ZLocation
=========

[![Join the chat at https://gitter.im/vors/ZLocation](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/vors/ZLocation?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Tracks your most used directories, based on the number of commands ran previously.
After a short learning phase, `z` will take you to the most popular directory that matches all of the regular expressions given on the command line.
You can use **Tab-Completion / Intellisense** to pick directories that are not the first choice.

ZLocation is the successor of [Jump-Location](https://github.com/tkellogg/Jump-Location).
Like [z.sh](https://github.com/rupa/z) is a reimagined clone of [autojump](https://github.com/joelthelion/autojump), Zlocation is a reimagined clone of Jump-Location.

Usage
-----

ZLocation keeps track of your `$pwd` (current folder).
Once visited, the folder becomes known to ZLocation.
You can `cd` with just a hint of the path!

The full command name is `Invoke-ZLocation`, but in the examples I use the alias `z`.
It's all about navigation speed, isn't it?

```
PS C:\Users\sevoroby> z c:
PS C:\> z zlo
PS C:\dev\ZLocation> z dsc
PS C:\dev\azure-sdk-tools\src\ServiceManagement\Compute\Commands.ServiceManagement\IaaS\Extensions\DSC> z test
PS C:\dev\ZLocation\ZLocation.Tests>
```

### List known locations

`z` without arguments will list all the known locations and their weights (shortcut for `Get-ZLocation`)

To see all locations matched to a query `foo` use `z -l foo`.

### Navigating to less common directories with tab completion

If `z mydir` doesn't take you to the correct directory, you can also tab through
ZLocation's suggestions.

For example, pressing tab with `z src` will take you through all of ZLocation's
completions for `src`.

### Going back

ZLocation keeps a stack of directories as you jump between them. `z -` will
"pop" the stack: it will move you to the previous directory you jumped to,
basically letting you undo your `z` navigation.

If the stack is empty (you have only jumped once), `z -` will take you to your
original directory.

For example:

```ps
C:\>z foo
C:\foo>z bar
C:\baz\bar> z -
C:\foo>z -
C:\>z -
C:\>#no-op
```

Goals / Key features
--------------------

*  Support for multiple PS sessions.
*  Good built-in ranking algorithm.
*  ~~Customizable matching algorithm and weight function.~~
*  Works on Windows, Linux and MacOS.

## Install
Install from [PowerShellGet Gallery](https://www.powershellgallery.com/packages/ZLocation/)
```powershell
Install-Module ZLocation -Scope CurrentUser
```

Make sure to **include ZLocation import in your `$PROFILE`**.
It intentionally doesn't alter `$PROFILE` automatically on installation.

This one-liner installs ZLocation, imports it and adds it to a profile.

```powershell
Install-Module ZLocation -Scope CurrentUser; Import-Module ZLocation; Add-Content -Value "`r`n`r`nImport-Module ZLocation`r`n" -Encoding utf8 -Path $PROFILE.CurrentUserAllHosts
```

If you want to display some additional information about ZLocation on start-up, you can put this snippet in `$PROFILE` after import. 
```powershell
Write-Host -Foreground Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"
```

Some features are configurable, these are the defaults:
```powershell
Import-Module ZLocation  -ArgumentList @{AddFrequentFolders = $True; RegisterPromptHook = $True}
```
- turn off `AddFrequentFolders` to not add directories from Explorer's QuickAccess to the ZLocation database automatically (this also results in faster loading times)
- turn off `RegisterPromptHook` to not automaticaly hook the prompt, see below

### Note

By default importing ZLocation alters your prompt function to track the location. Meaning if you use this module with other modules that modify your prompt function (e.g. `posh-git`), then you'd need to adjust your [Powershell profile file](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7). The statement `Import-Module ZLocation` needs to be placed **after** the other module imports that modifies your prompt function. As an alternative import the ZLocation module with `RegisterPromptHook=$False` and add a call to `Update-ZLocation $pwd` in your own prompt function.

You can open `profile.ps1` using the below commands:

```powershell
# In case this is a fresh OS install the directory itself might not yet exist so create it.
New-Item -Type Directory (Split-Path -Parent $PROFILE.CurrentUserAllHosts) -ErrorAction SilentlyContinue
# Open the file. Use CurrentUserCurrentHost to get the profile for the current host, e.g. PowerShell ISE.
notepad $PROFILE.CurrentUserAllHosts
```

Alternatively, type the below in your file explorer, and then create or edit the `profile.ps1` file with an editor of your choice:

```
%USERPROFILE%\Documents\WindowsPowerShell
```

Or when using Powershell Core:

```
%USERPROFILE%\Documents\PowerShell
```

License
-------

ZLocation is released under the [MIT](LICENSE) license.

ZLocation bundles a copy of [LiteDB](http://www.litedb.org/).

### LiteDB License

[MIT](http://opensource.org/licenses/MIT)

Copyright (c) 2017 - Maurício David.

Develop
-------

### Run tests

Install [Pester](https://github.com/pester/Pester).
Run `Invoke-Pester` from the root folder.
