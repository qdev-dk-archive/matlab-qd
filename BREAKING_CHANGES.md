# Breaking changes

## Version 0.5

* New class hierarchy for runs. I.e. RunWithInputs is now an ancestor of StandardRun.
* Changed the interface of qd.run.Probe. It is now a StandardRun, which when
  executing the run() method, will do first a normal run, then an identical run
  with all sweeps reversed.

## Version 0.4

* Removed *StandardRun.zero_all_sweept_channels*. Someone added *move_to_zero*
  as a synonym, which is a nicer name (and it does not have a typo).

## Version 0.3

* Added all external dependencies to the `dependencies` folder as git
  submodules. Type `git submodule update` in a Git Shell to download all of
  them. Then follow the installation instructions in [the readme](README.md).

## Version 0.2

* 2014-01-24: All timings in run classes were changed to seconds.

## Version 0.1

* Removed ramping channel from Keithley2400.
* Added ramp_rate property to Keithley2400, which when set to something other
  than [] enables ramping of the 'volt' channel.
