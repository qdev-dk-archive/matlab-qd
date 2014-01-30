classdef SetFuture < handle
    properties(Access=protected)
        func
        func_abort
    end
    methods
        function obj = SetFuture(func,varargin)
            p = inputParser();
            p.addOptional('abort',[]);
            p.parse(varargin{:});

            obj.func = func;
            obj.func_abort = p.Results.abort;
        end

        function exec(obj)
            if isempty(obj.func)
                error('exec already called once.');
            end
            obj.func();
            obj.func = [];
            obj.func_abort = [];
        end

        function abort(obj)
            if isempty(obj.func)
                warning('Nothing to abort, exec already called.');
            end
            if isempty(obj.func_abort)
                error('no abort function.');
            end
            obj.func_abort();
            obj.func = [];
            obj.func_abort = [];
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning('A qd.classes.SetFuture was thrown away without first calling exec().');
            end
        end
    end
end
