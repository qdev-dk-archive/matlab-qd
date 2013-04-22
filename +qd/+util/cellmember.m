function r = cellmember(needle, haystack)
	r = false;
	for hay = haystack
		hay = hay{1};
		if needle == hay
			r = true;
			break;
		end
	end
end