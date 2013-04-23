function append_text(filename, text)
	f = fopen(filename, 'at');
	fwrite(f, text);
	fclose(f);
end