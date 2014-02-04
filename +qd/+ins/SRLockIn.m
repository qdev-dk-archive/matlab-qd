classdef SRLockIn < qd.ins.SR830LockIn
    methods
        function obj = SRLockIn(com)
            obj@qd.ins.SR830LockIn(com);
            warning('SRLockIn is deprecated, use SR830LockIn instead.');
        end
    end
end