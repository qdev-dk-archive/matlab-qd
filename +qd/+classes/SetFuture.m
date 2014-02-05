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

        % Wait for this future to complete.
        function exec(obj)
            if isempty(obj.func)
                error('exec already called once.');
            end
            obj.func();
            obj.func = [];
            obj.func_abort = [];
        end

        % Stop whatever this future is doing.
        function abort(obj)
            if isempty(obj.func)
                warning('Nothing to abort, exec or abort has already been called.');
            end
            if isempty(obj.func_abort)
                error('no abort function.');
            end
            obj.func_abort();
            obj.func = [];
            obj.func_abort = [];
        end

        % Calls abort. (mirrors GetFuture.resolve)
        function resolve(obj)
            obj.abort();
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning('A qd.classes.SetFuture was thrown away without first calling exec().');
            end
        end
    end
    methods(Static)
        function f = do_nothing_future()
            function exec()
            end
            function abort()
            end
            f = SetFuture(@exec, @abort);
        end
    end
end
