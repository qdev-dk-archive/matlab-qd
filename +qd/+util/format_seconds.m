function string = format_seconds(seconds_total)
    seconds_total = round(seconds_total);
    minutes_total = floor(seconds_total / 60);
    hours_total = floor(minutes_total / 60);
    days_total = floor(hours_total / 24);
    seconds = floor(mod(seconds_total, 60));
    minutes = mod(minutes_total, 60);
    hours = mod(hours_total, 24);
    started_printing = false;
    string = '';
    if days_total > 0
        string = sprintf('%s %d days', string, days_total);
        started_printing = true;
    end
    if hours > 0 || started_printing
        string = sprintf('%s %d h', string, hours);
        started_printing = true;
    end
    if minutes > 0 || started_printing
        string = sprintf('%s %d min', string, minutes);
    end
    if hours_total < 1
        string = sprintf('%s %d s', string, seconds);
    end
end