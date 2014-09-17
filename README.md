# matlab-qd

A framework to write high-level instrument drivers, to do basic measurement,
and to quickly browse the resulting data. This is a direct competitor to
[special-measure](https://code.google.com/p/special-measure/).

This file is written in the [markdown format][mdcheat]. If you use, for
instance, the chrome extension [Markdown Preview Plus][mdpreview], and enable
local file-system access, you will have a pleasant reading experience, with
all links working.

## Important notice

The API is under development. Changes likely to cause problems for users will
be recorded in the file [BREAKING_CHANGES.md](BREAKING_CHANGES.md). Please
watch this when updating the package. In addition, you should restart daemons
and clear your matlab workspaces after updating (unless you know better).

## Installation

*matlab-qd* depends on a few other libraries. To install them, run the
following commands in a git shell:

`git submodule init`

`git submodule update --recursive`

Then add the root folder of the library to the MATLAB past, as well as all the
folders immediately inside the `dependencies` folder. Run the command
`zmq.install_jar` in MATLAB.

Some equipment needs continuously running daemons, see [Configuring
Daemons][daemons].

## Usage

See **[the tutorial](Tutorial.md)**. Note, if you plan to contribute code to
the project, then the tutorial is mandatory reading.

A sequential run example is here: [SequentialRun.md](SequentialRun.md).

## Documentation

Find help and information here:

* **[The Tutorial](Tutorial.md)**
* The `doc` command in MATLAB. E.g. type `doc qd.classes.Instrument`
* [List of breaking changes](BREAKING_CHANGES.md)
* [Configuring Daemons][daemons]
* Usage of the `qd.q` module is documented in the [the tutorial](Tutorial.md),
  in [+qd/+q/concepts.md](+qd/+q/concepts.md) and in
  [+qd/+q/jobs.md](+qd/+q/jobs.md).
* A sequential run example: [SequentialRun.md](SequentialRun.md)
* [Markdown Cheatsheet][mdcheat] for writing documentation
* The code itself (don't be afraid).

## Contact
* Anders Jellinggaard: <anders.jel@gmail.com>.

[mdcheat]: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet
[mdpreview]: https://chrome.google.com/webstore/detail/markdown-preview-plus/febilkbfcbhebfnokafefeacimjdckgl
[daemons]: +qd/+daemons/config-example/README.md