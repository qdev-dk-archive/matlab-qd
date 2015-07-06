# Breaking changes

## Version 0.7

* Changed the API of the Triton instrument:
    * Removed a few channels making them methods instead. These methods now
      take and return booleans instead of 'ON' and 'OFF'. Unless you can
      envision setting or getting something repeatedly in a meassurement loop,
      it is not a channel.
    * Removed duplicated functionality.
    * Removed the last remnants of the MC_cernox hack. You can
      configure extra channels when launching the triton daemon (see the config
      example), also MC_cernox is assigned to 'COOL' on my Oxford pc.

## Version 0.6

* The DecaDAC2 drivers no longer touches the mode by default. You need to call
  set_all_to_4channel_mode if this is what you want.

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
