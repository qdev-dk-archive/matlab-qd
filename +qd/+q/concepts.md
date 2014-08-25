# *q* module concepts

This document covers everything you need to know to use and develop the
functions and classes in the *q* module in no particular order. For a general
introduction, see [the tutorial](../../Tutorial.md).

## Overview

Here is a quick overview. Everything is covered in details below.

When using the library, the user constructs a ***Q* object** to hold some
configuration including

* A list of default inputs for all jobs.
* A *qd.Setup* object representing all equipment connected to the system.
* A *qd.data.Store* to use for output files.
* A cellphone number for sms notifications.

The *q* object is used to create a ***Plan* object**. This object has  an
associated *recipe* which starts out blank. Methods such as *sw(...)* and
*do(...)* modify the recipe by composition. The *go(...)* method does the
following:

1. It constructs a job which reads a single data point.
2. It applies its recipe to the job and executes the resulting job.

The following recipes exists at the moment.

* `qd.q.sw(channel, start, stop, n, settle)`

  Sweeps *channel* from *start* to *stop* in *n* points. At each point, the
  subordinate job is executed after waiting at least *settle* seconds for the
  system settle. *channel* can be a string or a channel object. The *settle*
  argument is optional, it defaults to zero.

* `qd.q.repeat(n)` &mdash; repeats the subordinate job *n* times.

Note, that recipes can be composed using the `|`-operator to form more
advanced recipes.

## Details

This section covers the concepts used in the *q* module. For documentation on
specific classes such as *Q* and *Plan* type `doc qd.q.Q` and `doc qd.q.Plan`
in Matlab or look at the comments in the source code for these classes. You
only really need to read this section if you are writing new recipes or are
curious.

### Recipes

A recipe has a single method called apply with the following signature

```
new_job = recipe.apply(ctx, old_job)
```

Where *ctx* is the *recipe application context* defined below. The resulting
*new_job* may execute *old_job* one or more times when it is executing (see
below for a prices definition of *job.exec()*). Additionally, recipes support
composition using the `|`-operator defined such that

```
(a | b).apply(ctx, job) = a.apply(ctx, b.apply(ctx, job))
```

The recipe application context, *ctx*, has a single method with the signature

```
chan = ctx.resolve_channel(chan_name)
```

where *chan_name* is a string and *chan* is a channel object. This lets the
recipe look up channels by name at the time of application. *resolve_channel*
is overloaded, such that if a channel object is supplied instead of a string,
it is returned unchanged.

### Jobs

An object is a *job* if it supports the following operations.

* `job.exec(ctx, future, settle, prefix)`
  
  Executes the job. The arguments are as follows

  * *ctx* — is the execution context. Described below.
  * *future* — is a *qd.classes.SetFuture*.
  * *settle* — is a float.
  * *prefix* — is a list of floats.

  Before reading any inputs, a job should call `future.exec()` and then
  `pause(settle)`, or it should arange for another job to do so. When adding
  points to the output datafile using `ctx.add_point(p)`. It should prefix the
  values in *prefix*.

* `columns = job.columns()`
  
  This method returns a cell-array of structs, each representing one column
  that the job needs in the output file. Each struct has at least a *name*
  field with the name of the column. If *A* is a job with a subordinate job
  *B*, in the sense that *A.exec()* calls *B.exec()* one or more times, then
  the following is true:

  * *A.columns()* calls *B.columns()* and prepends *n* structs.
  * *A.exec()* calls *B.exec()* with *n* extra *prefix* values.

  The value *n* above can of course be zero, if the job does not add any
  columns to the output.

* `time_in_seconds = job.time(options, settle)`
  
  Estimate how long this job will take to execute. *settle* is the same value
  as in the call to *exec*. *options* is a struct containing options affecting
  the timing calculation. See `qd.q.Plan.time` for expected options. *options*
  should be forwarded unchanged when calling *time* for subordinate jobs. *time* may return *NaN* or *inf*.

* `n = job.total_points()`
  
  How many data points will this job output. *total_points* may return *NaN* or
  *inf*.

* `reversed_job = job.reversed()`
  
  Create a new job that does what this job does in reverse. Subordinate jobs
  should be reversed by this function also. If it does not make sense to
  reverse this job, return job itself unchanged.

* `meta = job.describe(register)`
  
  Create a description for this job for the `meta.json` file. `register` is a
  *qd.classes.Register* object.