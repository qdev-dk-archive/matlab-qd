function out = map(f, in)
	out = arrayfun(f, in, 'UniformOutput', false)
end