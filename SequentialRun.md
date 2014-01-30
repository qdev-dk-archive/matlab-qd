# SequentialRun example

The sequentialRun takes sweeps, as well as functions and executes them one after another.

sweep as usual:
`function obj = sweep(obj, name_or_channel, from, to, points, varargin)`

function as follows:
`function obj = func(obj, func_handle, args)`
args is passed to the function `func_handle` when executed, func takes some optional aruments:

    p.addOptional('runs', 1);
    p.addOptional('settle', 0);
    p.addOptional('initial_settle', 0);

A simple example:

    ...
    run = qd.run.SequentialRun();
    ...

    function setvbg(val)
        disp(sprintf('Vbg to: %.2f',val));
        setup.chans.Vbg.set(val);
    end

    for Vbg = 0:10
        run.func(@setvbg,{Vbg},'settle',1);
        run.sweep('Vsd',-0.1,0.1,100,0);
    end
    run.run();

the function could be whatever you like, even a full measurement itself.
