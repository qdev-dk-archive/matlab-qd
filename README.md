# matlab-qd

A framework to write high-level instrument drivers, to do basic measurement,
and to quickly browse the resulting data. This is a direct competitor to
[special-measure](https://code.google.com/p/special-measure/).

## Important notice

The API is under development. Changes likely to cause problems for users will
be recorded in the file `BREAKING_CHANGES.txt`. Please watch this when
updating the package.

## Installation

## Examples

### Using instruments

### Performing standard measurements

## Output format

### Metadata

## GUI

## Contributing

### Writing instrument drivers

For now, have a look at qd.ins.SRLockIn for inspiration.

### Working with futures

Instrument drivers can optionally implement asynchronous get and set
operations using [futures](http://en.wikipedia.org/wiki/Futures_and_promises).
The qd framework uses two specific types of futures: a _GetFuture_, which
represents a running _get_async_ operation, and a _SetFuture_, which
represents a running _set_async_ operation.

A _GetFuture_ has the following methods:
* `future = GetFuture(func)` &mdash; Constructs a _GetFuture_. The function
  handle _func_ is kept by the future.
* `future.force()` &mdash; Causes _func_ to be called, caches the return
  value. Does nothing the second time it is called.
* `future.exec()` &mdash; Calls `future.force()`. Returns the cached value.

The _AgilentDMM_ is a good example of an instrument which benefits from an
asynchronous get operation. Calling _get_async_ on the _in_ channel initiates
a reading on the instrument and returns a future immediately; calling _force_
on that future blocks until the reading is complete. Compare the following two sequences:

    tic
    v1 = dmm1.getc('in'); % takes 1 second (assuming an integration time of 1s)
    v2 = dmm2.getc('in'); % takes 1 second
    toc % total time is 2 seconds

    tic
    f1 = dmm1.getc_async('in'); % takes a few ms.
    f2 = dmm2.getc_async('in'); % takes a few ms.
    v1 = f1.exec(); % takes 1 second.
    v2 = f2.exec(); % takes a few ms.
    toc % total time 1 second

When implementing an instrument, you only have to implement either a
synchronous or an asynchronous get method, the other will be defaulted
sensibly. You should ensure that calling _getc_async_ multiple times without
forcing the returned futures does not cause problems, for example by
automatically forcing old futures when a new is requested, as in the
_AgilentDMM_ drivers.

Note: the class _StandardRun_ uses asynchronous read operations for all
input channels.

The API of the _SetFuture_ is still unstable, but the plan is to handle
ramping in a similar fashion.

## Contact
* Anders Jellinggaard: <anders.jel@gmail.com>.

## Notes
* This readme is written in the [markdown
  format](http://daringfireball.net/projects/markdown/syntax).