function profile_inputs(inputs)
    disp('Reading synchronously');
    t1 = tic;
    for inp = inputs
        inp = inp{1};
        t2 = tic;
        inp.get();
        d = toc(t2);
        fprintf('%20s: %.2f ms\n', inp.name, d*1000);
    end
    toc(t1);
    tic
    futures = {};
    for inp = inputs
        futures{end + 1} = inp{1}.get_async();
    end
    for f = futures
        f{1}.exec();
    end
    disp('');
    disp('Reading asynchronously')
    toc
end