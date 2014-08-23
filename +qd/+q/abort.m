% Send a command to abort an ongoing q-job.
%
% This function will abort a job running in another instance of matlab. If
% several jobs are running, a random job will be cancelled.
function abort()
    qd.q.impl.send_cmd('abort');
end