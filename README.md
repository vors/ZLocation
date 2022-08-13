[![Build status](https://ci.appveyor.com/api/projects/status/qqg75o50jj6e35mn/branch/master?svg=true)](https://ci.appveyor.com/project/vors/zlocation/branch/master)

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

The full command name is `Invoke-ZLocation`, but in examples I use alias `z`.
It's all about navigation speed, isn't it?

```
PS C:\Users\sevoroby> z c:
PS C:\> z zlo
PS C:\dev\ZLocation> z dsc
PS C:\dev\azure-sdk-tools\src\ServiceManagement\Compute\Commands.ServiceManagement\IaaS\Extensions\DSC> z test
PS C:\dev\ZLocation\ZLocation.Tests>
```

### List known locations

`z` without arguments will list all the known locations and their weights (short-cut for `Get-ZLocation`)

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

### Custom database file location

ZLocation uses a database file to store the list of known directories. By default, it is located at `$HOME\z-location.db`. If you want to use a custom path, set the `PS_ZLOCATION_DATABASE_PATH` environment variable before importing the module.

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

### Note

ZLocation alternates your prompt function to track the location. Meaning if you use this module with other modules that modifies your prompt function (e.g. such as `posh-git`), then you'd need to adjust your [Powershell profile file](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7). The statement `Import-Module ZLocation` needs to be placed **after** the other module imports that modifies your prompt function.

You can open up `profile.ps1` through using any of the below commands:

```powershell
notepad $PROFILE.CurrentUserAllHosts
notepad $env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1
notepad $Home\Documents\WindowsPowerShell\profile.ps1
```

Alternatively, type up the below in your file explorer, and then edit the `profile.ps1` file with an editor of your choice:

```
%USERPROFILE%\Documents\WindowsPowerShell
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
