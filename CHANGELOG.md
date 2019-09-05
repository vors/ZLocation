CHANGELOG
-------------
## 1.3.0
* Prefer exact match over the weight when picking the location (#90)

## 1.2.0

* Move to unvisited directories if one is provided (#80)
* Fix - using ZLocation on Windows PowerShell creates errors in $Error (#75)

## 1.1.0

* Fix problems with non-unified casing #62 (thanks @cspotcode)
* Better representation for db entries (thanks @rkeithhill)
* Graceful install/remove for the prompt hook (thanks @rkeithhill)
* Add retry and backoff logic to better support multiply db connections on Mac.

## 1.0.0

* Make ZLocation work with `cmder`
* Replace persistent storage by LiteDB (thanks @cspotcode)
* Make ZLocation work on Linux and MacOS (thanks @cspotcode)
* Prioritize the beginning of a foldername in ranking
* Use `Register-ArgumentCompleter` for tab-completions (thanks @cspotcode)
* New shortcuts `z` and `z -l` for quick quering

## 0.3.0
