classdef OxfMagnet3D < qd.classes.Instrument
    properties
        magnet
    end
    methods

        function obj = OxfMagnet3D()
            obj.magnet = daemon.Client(qd.daemons.OxfMagnet3D.bind_address);
        end
    end
end