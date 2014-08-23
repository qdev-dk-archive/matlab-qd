function s = eta()
    r = qd.q.impl.send_cmd('eta');
    seconds_total = sscanf(r{1}, '%f');
    minutes_total = floor(seconds_total / 60);
    hours_total = floor(minutes_total / 60);
    days_total = floor(hours_total / 24);
    seconds = floor(mod(seconds_total, 60));
    minutes = mod(minutes_total, 60);
    hours = mod(hours_total, 24);
    fprintf('Time remaining:');
    started_printing = false;
    if days_total > 0
        fprintf(' %d days', days_total);
        started_printing = true;
    end
    if hours > 0 | started_printing
        fprintf(' %d h', hours);
        started_printing = true;
    end
    if days_total < 1 & (minutes > 0 | started_printing)
        fprintf(' %d min', minutes);
    end
    if hours_total < 1
        fprintf(' %d s', seconds);
    end
    fprintf('.\n');
    when_done = addtodate(now(), round(seconds_total), 'second');
    fprintf('ETA: %s.\n', datestr(when_done, 31));
end