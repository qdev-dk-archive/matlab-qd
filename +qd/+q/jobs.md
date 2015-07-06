# Jobs in the q module

An object is a *job* if it supports the following operations.

* `job.exec(ctx, future, prefix)`

  Executes the job. The arguments are as follows

  * *ctx* — is the execution context. Described below.
  * *future* — is a *qd.classes.SetFuture* or `[]`.
  * *prefix* — is a list of floats.

  Before reading any inputs, if *future* is not empty, a job should call
  `future.exec()`, or it should arange for another job to do so. When adding
  points to the output datafile using `ctx.add_point(p)`. It should prefix the
  values in *prefix*.

* `columns = job.columns()`

  This method returns a cell-array of structs, each representing one column
  that the job needs in the output file. Each struct has at least a *name*
  field with the name of the column. If *A* is a job with a subordinate job
  *B*, in the sense that *A.exec()* calls *B.exec()* one or more times, then
  the following should hold:

  * *A.columns()* calls *B.columns()* and prepends *n* structs.
  * *A.exec()* calls *B.exec()* with *n* extra *prefix* values.

  The value *n* above can of course be zero if the job does not add any
  columns to the output.

* `time_in_seconds = job.time(options)`

  Estimate how long this job will take to execute. *options* is a struct
  containing options affecting the timing calculation. See `qd.q.Plan.time`
  for expected options. *options* should be forwarded unchanged when calling
  *time* for subordinate jobs. *time* may return *NaN* or *inf*.

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

* `text = job.pprint()`

  Create a string suitable for displaying this job to the user. The string may
  contain several lines, but should not end in a newline.

## The execution context

The execution context, *ctx*, is a struct with the following methods:

* `ctx.add_point(p)` &mdash; Puts an array of floats in the ouput file (as a single row).
* `ctx.add_divider()` &mdash; Gnuplot expects a divider between each line in a
  2D-sweep. This hook exists to make that happen.
* `ctx.periodic_hook()` &mdash; Should be called once in a while. May raise an
  exception if the user requested that the job be aborted. This function also
  communicates eta updates to the user. See `qd.q.abort` and `qd.q.eta`.
