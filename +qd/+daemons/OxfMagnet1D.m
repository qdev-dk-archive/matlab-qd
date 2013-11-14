classdef OxfMagnet1D < handle
    properties(Constant)
        % The address the magnet control server will listen on.
        bind_address = 'tcp://127.0.0.1:9740/'
    end
    properties
        % How often to check the temperature of the cryostat.
        % In seconds.
        check_period = 3*60
        max_pt2_temp = 4.5
        max_cooling_water_temp = 21
        magnet_com = 'COM3'
        smtp_server = 'mail.fys.ku.dk'
        alert_email = 'chrede@me.com'
        magnet
        server
        pt2_chan
        cool_water_chan
        debug = false
    end
    
    properties(Access=private)
        triton
        status = 'ok'
    end
    
    methods
        function obj = OxfMagnet1D()
            % Open connection to the Triton remote interface
            obj.triton = qd.ins.Triton();

            obj.pt2_chan = qd.comb.MemoizeChannel( ...
                obj.triton.channel('PT2'), obj.check_period/2);
            obj.cool_water_chan = qd.comb.MemoizeChannel( ...
                obj.triton.channel('cooling_water'), obj.check_period/2);

            % and the magnet
            obj.initiate_magnet();
        end
        
        function run(obj)
            obj.server = obj.make_server();
            obj.server.smtp_server = obj.smtp_server;
            obj.server.alert_email = obj.alert_email;
            obj.server.daemon_name = 'magnet';
            while true % loop forever
                try
                    obj.server.serve_period(obj.check_period);
                    obj.check_temperature()
                catch err
                    obj.server.send_alert_from_exception(...
                        'Error in magnet control server', err);
                end
            end
        end
        
        function delete(obj)
            fclose(obj.magnet);
        end

        function server = make_server(obj)
            server = daemon.Daemon(obj.bind_address);
            server.expose(obj, 'get_current');
            server.expose(obj, 'get_current_set_point');
            server.expose(obj, 'get_current_sweep_rate');
            server.expose(obj, 'get_field');
            server.expose(obj, 'get_field_set_point');
            server.expose(obj, 'get_field_sweep_rate');
            server.expose(obj, 'get_status');
            server.expose(obj, 'reset_status');
            server.expose(obj, 'set_current');
            server.expose(obj, 'set_current_sweep_rate');
            server.expose(obj, 'set_field');
            server.expose(obj, 'set_field_sweep_rate');
            server.expose(obj, 'stop_sweep');
            server.expose(obj, 'get_status_report');
            server.expose(obj, 'switch_heater');
            server.expose(obj, 'get_switch_heater_current');
        end

        function send(obj, cmd, varargin)
            req = sprintf(cmd, varargin{:});
            if obj.debug
                disp(['sen '  req])
            end
            fprintf(obj.magnet, req);
            % Throw away reply.
            fscanf(obj.magnet);
        end

        function val = query(obj, cmd, frm)
            if obj.debug
                disp(['req ' cmd])
            end
            fprintf(obj.magnet, cmd);
            rep = fscanf(obj.magnet);
            if obj.debug
                disp(['rep ' rep])
            end
            if rep(1) == '?'
                error('Bad response from magnet (%s)', rep);
            end
            val = sscanf(rep, [frm 13]); % 13 is \r.
        end
        
        function ok = temperature_ok(obj)
            if ~strcmp(obj.status, 'ok')
                ok = false;
                return;
            end
            pt2 = obj.pt2_chan.get();
            cw = obj.cool_water_chan.get();
            ok = pt2 <= obj.max_pt2_temp ...
                && cw <= obj.max_cooling_water_temp;
        end
        
        function check_temperature(obj)
            if ~strcmp(obj.status, 'tripped')
                % If the protection has already been tripped. Do nothing.
                current_field = obj.get_field();
                if current_field ~= 0
                    if ~obj.temperature_ok()
                        obj.trip_protection();
                    end
                end
            end
        end
        
        function initiate_magnet(obj)
            % Open connection to the magnet.
            obj.magnet = serial(obj.magnet_com);
            obj.magnet.Terminator = 13;
            obj.magnet.BaudRate = 9600;
            obj.magnet.StopBit = 2.0;
            fopen(obj.magnet);
            % Remote and unlocked
            obj.send('C3');
            % Display to tesla
            obj.send('M9');
            % Use more digits (no return for this command.)
            fprintf(obj.magnet, 'Q4');
            % Set to Hold
            obj.send('A0');
        end

        function trip_protection(obj)
            obj.send('T%f', 0.2); % field sweep rate
            obj.send('J%f', 0.0); % field set point
            obj.send('A1');       % go to set point
            obj.status = 'tripped';
            body = sprintf('Temp. PT2: %f\nTemp. cooling water: %f.\n', ...
                obj.triton.get_temp(1), obj.get_cooling_water_temp());
            obj.server.send_alert('Magnet too warm', body);
        end

        function assert_temperature_ok(obj)
            if ~obj.temperature_ok()
                error(['Temperature is not ok. ' ...
                    '(PT2: %.2fK, Cooling water: %.2fK, Status: %s).'], ...
                    obj.triton.get_temp(1), ...
                    obj.triton.get_cooling_water_temp(), ... 
                    obj.status );
            end
        end

        function status = get_status(obj)
            status = obj.status;
        end

        function r = reset_status(obj)
            obj.status = 'ok';
            r = [];
        end
        
        function field = get_field(obj)
            field = obj.query('R7', 'R%f');
        end
        
        function r = set_field(obj, field)
            obj.assert_temperature_ok();
            if abs(field) > 12; %12 T
                error('Set point too high!');
            end
            % set set point.
            obj.send('J%f', field);
            % go to set point
            obj.send('A1');
            r = [];
        end
        
        function current = get_current(obj)
            current = obj.query('R0', 'R%f');
        end
        
        function r = set_current(obj, current)
            obj.assert_temperature_ok();
            if abs(current) > 115.72; %115.72 A
                error('Set point too high!')
            end
            % set set point
            obj.send('I%f', current);
            % go to set piont
            obj.send('A1');
            r = [];
        end
        
        function field_set_point = get_field_set_point(obj)
            field_set_point = obj.query('R8', 'R%f');
        end
        
        function current_set_point = get_current_set_point(obj)
            current_set_point = obj.query('R5', 'R%f');
        end
        
        function field_sweep_rate = get_field_sweep_rate(obj)
            field_sweep_rate = obj.query('R9', 'R%f');
        end
        
        function current_sweep_rate = get_current_sweep_rate(obj)
            current_sweep_rate = obj.query('R6', 'R%f');
        end

        function switch_heater_current = get_switch_heater_current(obj)
            switch_heater_current = obj.query('R20', 'R%f');
        end
        
        function r = set_field_sweep_rate(obj, sweep_rate)
            obj.assert_temperature_ok();
            if abs(sweep_rate) > .3; %0.3  T/MIN
                    error('Magnet ramp rate too high!')
            end
            obj.send('T%f', sweep_rate);
            r = [];
        end
        
        function r = set_current_sweep_rate(obj, sweep_rate)
            obj.assert_temperature_ok();
            if abs(sweep_rate) > 2.893; %2.893  A/MIN
                    error('Magnet ramp rate too high!')
            end
            obj.send('S%f', sweep_rate);
            r = [];
        end
        
        function r = stop_sweep(obj)
            obj.assert_temperature_ok();
            obj.send('A0');
            r = [];
        end
        
        function status_report = get_status_report(obj)
            status_report = obj.query('X', '%s');
        end
        
        function r = switch_heater(obj, onoff)
            obj.assert_temperature_ok();
            if onoff > 1;
                error('Send 0 for close and 1 for open')
            end
            obj.send('H%d', onoff);
            r = [];
            % Wait 20s to make sure the switch has changed state
            pause(20);
        end
    end
end
