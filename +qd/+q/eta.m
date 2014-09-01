% Ask an ongoing q-job when it will be finished.
%
% This function will communicate with a job running in another instance of
% matlab. If several jobs are running, a random job will be selected.
function s = eta()
    r = qd.q.impl.send_cmd('eta');
    seconds = sscanf(r{1}, '%f');
    fprintf('Time remaining: %s.\n', qd.util.format_seconds(seconds));
    when_done = addtodate(now(), round(seconds), 'second');
    fprintf('ETA: %s.\n', datestr(when_done, 31));
end