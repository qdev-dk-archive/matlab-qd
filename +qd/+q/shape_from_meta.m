function shape = shape_from_meta(meta)
    if ~isfield(meta, 'job')
        shape = [];
        return
    end
    job = meta.job;
    shape = qd.q.shape_from_meta(job);
    if isfield(job, 'repeats')
        shape = [shape job.repeats];
    else
end