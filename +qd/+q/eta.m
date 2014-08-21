function s = eta()
    r = qd.q.impl.send_cmd('eta');
    s = r{1};
end