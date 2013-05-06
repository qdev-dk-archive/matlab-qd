classdef OxfMagnet3D < handle
    properties(Constant)
        bind_address = 'tcp://127.0.0.1:9738/'
    end
    
    properties
        check_period = 3*60
        limit1_pt2 = 4.0
        limit2_pt2 = 4.5
        limit1_cool_water = 20
        limit2_cool_water = 21
        ramp_to_zero_rate = 0.03; % Tesla/min.
    end
    properties(SetAccess=private)
        magnet_serial
        magnet
        triton
        pt2_chan
        cool_water_chan
        server
        status = 'ok'
    end

    methods

        function obj = OxfMagnet3D(com_port)
            obj.magnet_serial = serial(com_port);
            fopen(obj.magnet_serial);
            obj.magnet = qd.protocols.OxfordSCPI(@(req)query(obj.magnet_serial, req));
            obj.triton = qd.ins.Triton();
            obj.server = daemon.Daemon(obj.bind_address);
            obj.server.daemon_name = 'oxfmagnet3d-daemon';
            obj.server.expose(obj, 'set');
            obj.server.expose(obj, 'read');
            obj.server.expose(obj, 'get_report');
            obj.server.expose(obj, 'reset_status');
        end

        function run_daemon(obj)
            obj.pt2_chan = qd.comb.MemoizeChannel( ...
                obj.triton.channel('PT2'), obj.check_period/2);
            obj.cool_water_chan = qd.comb.MemoizeChannel( ...
                obj.triton.channel('cooling_water'), obj.check_period/2);
            while true % loop forever
                try
                    obj.server.serve_period(obj.check_period);
                    obj.perform_check()
                catch err
                    obj.server.send_alert_from_exception(...
                        'Error in magnet control server', err);
                end
            end
        end

        function val = read(obj, axis, prop, varargin)
            val = obj.magnet.read([obj.axis_addr(axis) prop], varargin{:});
        end

        function r = set(obj, axis, prop, value)
            obj.assert_conditions_ok();
            obj.set_without_checking(axis, prop, value);
            r = [];
        end

        function ok = conditions_ok(obj)
            obj.perform_check();
            ok = strcmp(obj.status, 'ok');
        end

        function perform_check(obj)
            if obj.at_zero_field()
                return
            end
            if strcmp(obj.status, 'level2')
                return
            end
            if obj.pt2_chan.get() > obj.limit2_pt2 ...
                || obj.cool_water_chan.get() > obj.limit2_cool_water
                obj.trip_level2();
            end
            if strcmp(obj.status, 'level1')
                return
            end
            if obj.pt2_chan.get() > obj.limit1_pt2 ...
                || obj.cool_water_chan.get() > obj.limit1_cool_water
                obj.trip_level1();
            end
        end

        function r = at_zero_field(obj)
            r = true;
            for axis = 'xyz'
                if obj.read(axis, 'SIG:FSET', '%fT') ~= 0
                    r = false;
                    return;
                elseif abs(obj.read(axis, 'SIG:FLD', '%T')) > 1E-3
                    r = false;
                    return;
                end
            end
        end

        function trip_level2(obj)
            if strcmp(obj.status, 'level2')
                return
            end
            for axis = 'xyz'
                % Hold all when overheating as requested by oxford.
                obj.set_without_checking(axis, 'ACTN', 'HOLD');
            end
            obj.status = 'level2';
            obj.server.send_alert('Magnet at level2 overheating', obj.get_report());
        end

        function trip_level1(obj)
            if strcmp(obj.status, 'level1') || strcmp(obj.status, 'level2')
                return
            end
            % Bring to zero along direction of field. Vect will hold the
            % direction.
            vect = [0 0 0]
            axis = 'xyz'
            for i = 1:3
                % We assume here that the magnet is not in persistent mode.
                vect(i) = obj.read(axis(i), 'SIG:FLD', '%fT');
            end
            % We set the ramp rate with positive numbers.
            vect = abs(vect);
            % Add a small value to each component to avoid degenerate cases.
            vect = vect + 0.01;
            vect = vect/norm(vect);
            for i = 1:3
                % We assume here that the magnet is not in persistent mode.
                obj.set_without_checking(axis, 'ACTN', 'HOLD');
                obj.set_without_checking(axis(i), 'SIG:RFLD', ...
                    vect(i) * obj.ramp_to_zero_rate);
                obj.set_without_checking(axis, 'ACTN', 'RTOZ');
            end
            obj.status = 'level1';
            obj.server.send_alert('Magnet at level1 overheating', obj.get_report());
        end

        function reset_status(obj)
            obj.status = 'ok';
        end

        function assert_conditions_ok(obj)
            if ~obj.conditions_ok()
                error('It is not safe to operate the magnet now:\n%s', obj.get_report());
            end
        end

        function report = get_report(obj)
            report = sprintf('PT2: %f\nCooling water: %f\nStatus:%s\n', ...
                obj.pt2_chan.get(), obj.cool_water_chan.get(), obj.status);
        end

        function set_without_checking(axis, prop, value)
            % Disapled for now
            prop
            value
            return

            val = obj.magnet.set([axis_addr(axis) prop], value);
        end

        function addr = axis_addr(obj, axis)
            qd.util.assert(length(axis));
            qd.util.assert(ismember(axis, 'xyzXYZ'));
            addr = ['DEV:GRP' upper(axis) ':PSU:'];
        end

        function delete(obj)
            if ~isempty(obj.magnet_serial)
                fclose(obj.magnet_serial);
            end
        end
        
    end
end
