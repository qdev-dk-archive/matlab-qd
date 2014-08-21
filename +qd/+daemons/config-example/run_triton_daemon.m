function run_triton_daemon()
    json.startup();
    qd.util.change_matlab_title('Triton Daemon');s.Triton();
    triton = qd.daemon
    triton.address = '172.20.???.???';
    triton.password = '?????';
    % triton.server.smtp_server = 'mail.fys.ku.dk';
    % triton.server.alert_email = 'email@example.com';
    triton.run_daemon();
end