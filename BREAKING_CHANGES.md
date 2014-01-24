# Breaking changes

## Version 0.3

Added all external dependencies to the `dependencies` folder as git
submodules. Type `git submodule update` in a Git Shell to download all of
them. Then follow the installation instructions in [the readme](README.md).

## Version 0.2

* 2014-01-24: All timings in run classes were changed to seconds.

## Version 0.1

* Removed ramping channel from Keithley2400.
* Added ramp_rate property to Keithley2400, which when set to something other
  than [] enables ramping of the 'volt' channel.
