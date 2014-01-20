function run_triton_daemon()
    json.startup();
    triton = qd.daemons.Triton();
    triton.address = '172.20.???.???';
    triton.password = '?????';
    % triton.server.smtp_server = 'mail.fys.ku.dk';
    % triton.server.alert_email = 'email@example.com';
    triton.run_daemon();
end