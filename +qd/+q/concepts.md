# *q* module concepts

Before reading this document, you should have a look at [the
tutorial](../../Tutorial.md). See also, the [q-examples](q-examples.md)
document (TODO).

### *Q* objects

Usage of the *q* module starts with an object of the *qd.q.Q* class. A *Q*
object holds configuration that changes little between different jobs. This
includes

* A list of inputs used by default in every job.
* A *qd.Setup* object which knows about equipment connected to the system.
* A *qd.data.Store* to use for output files.
* A cellphone number for sms notifications.

The *Setup* object is used to resolve channel names and to add description of
the experimental setup to the `meta.json` output file.

The only interesting method a *Q* object has is the *make_plan()* method,
although it rarely called directly. Methods like *sw(...)*, *do(...)*,
*with(...)* etc. all call *make_plan()* first and then forward their arguments
directly to the similarly named method on the newly created plan, they merely
serve as shortcuts.

For more information, type `doc qd.q.Q` in Matlab.

### *Plan* objects

*Plan* objects are spawned from a *Q* object using the *make_plan()* method,
or more commonly, using one of the shortcuts explained above. It holds two
important pieces of information

* A list of inputs, which is initially copied from the default inputs defined
  by the *Q* object.
* A recipe.

A *recipe* is an object which is applied to a *job* to create a more advanced
job. An example of a recipe is `qd.q.repeat(10)` which when applied to a job,
*J*, creates a new job that simply repeat *J* ten times. The recipe that a
*Plan* object starts out with is trivial, when applied to a job it simply
returns the job unchanged.

To modify the list of inputs, a plan has the methods *with(...)* and
*without(...)*.

To modify the recipe, a plan has the method *do(...)*. Recipes can be composed
with the |-operator, and the *do* method is defined such that *do(X)* creates
a plan with the recipe *R|X* from a plan with the recipe *R*. Note, *.sw(...)*
is a shortcut for *.do(qd.q.sw(...))*.

Once a plan has been shaped using the methods described above, it is executed
using the *go* method. It does the following

1. It creates a trivial job which simply reads the inputs once and writes the
   resulting point to a data file.
2. It applies the recipe to the trivial job to create the job the user wants
   to execute.
3. It sets up an output location using the *Store* of the *Q* object it was
   created from.
4. It writes a meta file.
5. It executes the job.

The full details of what constitutes a *job* can be read in [a separate
file](jobs.md).

For more information, type `doc qd.q.Plan` in Matlab.

### Recipes

A recipe is an object with single method, called `apply`, with the following
signature

```
new_job = recipe.apply(ctx, old_job)
```

where *ctx* is the *recipe application context* defined below. The resulting
*new_job* may execute *old_job* any number of times. Recipes support
composition using the |-operator defined such that

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

The following recipes exists at the moment.

* `qd.q.sw(channel, start, stop, n, settle)`

  Sweeps *channel* from *start* to *stop* in *n* points. At each point, the
  subordinate job is executed after waiting at least *settle* seconds for the
  system settle. *channel* can be a string or a channel object. The *settle*
  argument is optional, it defaults to zero.

* `qd.q.repeat(n)` &mdash; repeats the subordinate job *n* times.
