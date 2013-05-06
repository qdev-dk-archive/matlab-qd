classdef OxfMagnet3D < handle
    properties(Constant)
        bind_address = 'tcp://127.0.0.1:9738/'
    end
    
    properties
        check_period = 3*60
        max_pt2_temp = 4.5
        max_cooling_water_temp = 21
    end
    properties(SetAccess=private)
        magnet_serial
        magnet
        triton
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
            val = obj.magnet.read([axis_addr(axis) prop], varargin{:});
        end

        function r = set(obj, axis, prop, value)
            obj.assert_conditions_ok();
            obj.set(axis, prop, value);
            r = [];
        end

        function ok = conditions_ok(obj)
            ok = strcmp(obj.status, 'ok') && ...
                obj.triton.getc('PT2') > obj.max_pt2_temp && ...
                obj.triton.getc('cooling_water') > obj.max_cooling_water_temp;
        end

        function perform_check(obj)
            if ~obj.conditions_ok()
                trip_protection();
            end
        end

        function trip_protection(obj)
            if strcmp(obj.status, 'tripped')
                return
            end
            for axis = 'xyz'
                % For now, hold all when overheating as requested by oxford.
                obj.set(axis, 'ACTN', 'HOLD');
            end
            obj.status = 'tripped';
            obj.server.send_alert('Magnet too warm', obj.get_report());
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
            report = sprintf('PT2: %s\nCooling water:%s\nStatus:%s\n', ...
                obj.triton.getc('PT2'), ...
                obj.triton.getc('cooling_water'), ...
                obj.status);
        end

        function set_without_checking(axis, prop, value)
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
