function run_triton_daemon()
    json.startup();
    qd.util.change_matlab_title('Triton Daemon');
    triton = qd.daemon.Triton();
    triton.address = '172.20.???.???';
    triton.password = '?????';
    % triton.server.smtp_server = 'mail.fys.ku.dk';
    % triton.server.alert_email = 'email@example.com';

    % You can configure extra temperature channels here
    % triton.channels('MC_cernox') = 'T5'
    triton.run_daemon();
end
