# *matlab-qd* tutorial

## Using instrument drivers.

While *matlab-qd* is a complete framework, you do not have to opt-in to
everything if you just want to use a single instrument driver from the
project. Let us try using a *Keithley 2600*. Make sure its turned on and
outputting a voltage.

```matlab
>> keithley = qd.ins.Keithley2600(gpib('ni', 0, 1));
```

The above code creates an instance of the Keithley2600 class. The `gpib` class
is from the MATLAB standard library.

Instruments have channels, you can query which by typing

```matlab
>> keithley.channels()
TODO, put output here.
```

You can get and set channels using the commands `getc` and `setc`.

```matlab
>> keithley.setc('v', 1.0); % The unit is volts.
TODO, put output here.
>> keithley.getc('i')
TODO, put output here.
```

Not all channels support both setting and geting, for instance

```matlab
>> keithley.setc('r', 1000);
TODO, put output here.
```

Furthermore, you should not expect `getc` to return the exact same value as is
set by `setc`. For instance, if a keithley is in current compliance, it will
limit the voltage, making the value returned by `keithley.getc('v')` lower
than what was set.

For further reference type `doc qd.classes.Instrument` in MATLAB.

### Configuring instruments

To configure an instrument, use methods on its instance. For instance

```matlab
>> keithley.turn_off_output();
>> keithley.set_compliance('i', 10E-9);
```

Only common configuration options are usually exposed. If you need something
that is not there, you can either add it to the drivers (see below), or bypass
it be talking to the instrument directly.

```matlab
>> keithley.query('print(smua.measure.analogfilter)');
```

For further reference see `doc qd.classes.ComInstrument`.

### Using channel objects

In addition to `setc` and `getc`, you can set and get a channel by first
instantiating a channel object

```matlab
>> voltage = keithley.channel('v');
>> current = keithley.channel('i');
>> voltage.set(3.0);
>> current.get()
TODO, put output here.
```

This lets you write code that works on individual channels, without worrying
about where these channels came from. A technique that is used extensively in
*matlab-qd*. All channels inherit from `qd.classes.Channel`.

### Ramping a channel (working with futures)

Many instruments support (or enforce) slowly ramping their outputs. Let us try
this out. For the keithley 2600, here is how you set the ramp rate.

```matlab
>> keithley.setc('v', 0);
>> keithley.turn_on_output();
>> keithley.ramp_rate.v = 0.5; % Set the ramp rate to 0.5 volts per second
>> tic; keithley.setc('v', 3); toc;
TODO, put output here.
```

Notice that `setc` *blocks* until the ramp is complete. If this is not
desirable, you can use `setc_async` (or `set_async` on a channel object).

```matlab
>> keithley.setc_async('v', 0); % This function returns imediately.
```

Notice, that if you call `setc` or `setc_async` again before the ramp is
complete, the ramp is aborted, a warning is printed, and a new ramp is
started. You can also call `keithley.current_future.abort()` to abort any
running ramp.

If you left out the semicolon, you may have noticed that `setc_async` returns
a `qd.classes.SetFuture` object. This can be used to wait until the ramp is
complete or to abort an ongoing ramp.

```matlab
>> future = keithley.setc_async('v', 3);
>> future.exec(); % wait until the ramp is complete.
>> future = keithley.setc_async('v', 0); % start a new ramp.
>> pause(2.0);
>> future.abort(); % abort it prematurely.
```

The real strength of futures comes when you need to ramp several channels. For
instance, if you have six gates driven by DecaDACs that need to be ramped 1
volt at 0.1 volt/second, ramping one at a time with `setc` would take 1 min.
However, this piece of code

```matlab
% First we initate all the ramping.
futures = {};
for i = 1:length(gates)
    futures{i} = gates{i}.set_async(1.0);
end
% Then we wait for the ramps to finish
for i = 1:length(gates)
    futures{i}.exec();
end
```

would only take 10 seconds. This method is used throughout *matlab-qd*. Note,
that is also a `get_async` for instrument with long integration times.

## Running measurements

Beyond being a collection of drivers with a uniform interface, *matlab-qd*
also offers classes that will let you run basic measurements with ease. First
we will look at two simple classes that we will use later.

The class `qd.data.Store` exist to create empty directorties in some base
folder into which data can be stored.

```matlab
>> store = qd.data.Store('D:\Data\Me\');
>> store.cd('DeviceNr1959');
>> blank_dir = store.new_dir()
```

The class `qd.Setup` is a class that knows every instrument in your setup.

```matlab
>> keithley.name = 'keithley';
>> decadac = qd.ins.DecaDAC2('COM1');
>> decadac.name = 'dac';
>> setup = qd.Setup();
>> setup.add_instrument(keithley);
>> setup.add_instrument(decadac);
```

There is also an `add_channel`.

The setup lets you lookup channels by name (preceded by the instrument name
and a `/`). For instance

```matlab
>> voltage = setup.find_channel('keithley/v');
>> voltage.set(0);
>> % or you can do
>> setup.setc('keithley/v', 0);
>> setup.setc('dac/CH0', 0);
```

and you can access instruements and named channels through the `ins` and
`chans` properties

```matlab
>> setup.ins.keithley.turn_output_on();
```

It is standard practice, to make a function that sets up a setup object for
your setup.

### The *StadardRun* class

Lets try to run an experiment. Here is a simple IV curve.

```matlab
>> run = qd.run.StandardRun();
>> run.store = store;
>> run.setup = setup;
>> run.sweep('keithley/v', 0, 10, 100); % 0 to 10 in 100 steps.
>> run.input('keithley/i');
>> run.name = 'IV curve';
>> run.run();
```

The *sweep* and *input* methods look up a channels using the *setup*
configured for the run, but you could also pass a channel directly
(`run.sweep(voltage, 0, 10, 100);` and `run.input(current);`).

If you supply multiple sweeps, they are nested:

```matlab
>> gate = setup.find_channel('dac/CH0');
>> run.clear_sweeps();
>> run.sweep(gate, 0, 10, 11);
>> run.sweep('keithley/v', 0, 10, 100);
>> run.name = 'Gate dependence';
>> run.run(); % One IV curve for each gate value.
```

Note, many of the methods of a *run* return the *run* itself so that calls can
be chained. E.g.

```matlab
>> run.clear_sweeps().sweep('keithley/v', 0, 10, 100).set_name('IV curve 2').run();
```

There is more to runs, use the `doc` command. For reference, here is the
signature of *sweep*

```matlab
run.sweep(channel, start, end, points, [settle]);
```

where the optional value *settle*, specifies how long to wait after setting
this value (in seconds).

## Plotting measurements

## Advanced topics

### Describing objects

TODO

### Using channel combinators

TODO

### Writing instrument drivers

TODO

### Subclassing or forgoing the run classes

TODO

### Daemons

TODO