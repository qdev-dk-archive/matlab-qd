function s = format_seconds(seconds)
    seconds = round(seconds);
    minutes = floor(seconds/60);
    seconds = mod(seconds, 60);
    hours = floor(minutes/60);
    minutes = mod(minutes, 60);
    days = floor(hours/24);
    hours = mod(hours, 24);

    parts = {};
    if days > 0
        parts{end + 1} = sprintf('%d days', days);
    end
    if hours > 0 || ~isempty(parts)
        parts{end + 1} = sprintf('%d h', hours);
    end
    if minutes > 0 || ~isempty(parts)
        parts{end + 1} = sprintf('%d min', minutes);
    end
    if days < 1 && hours < 1
        parts{end + 1} = sprintf('%d s', seconds);
    end

    s = qd.util.strjoin(parts, ' ');
end