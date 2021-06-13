# Trim
function tabtrim
	argparse "h/help" "t/truncate" "n#number" -- $argv; or return

	if set -q _flag_h; usage \
		--help_text "Remove leading tabs from each line of input." \
		--arg_list "TEXT" \
		--arg_help "  TEXT  Trim leading tabs from TEXT" \
		--opt_help "
		  -h, --help       Print this help.
		  -n, --number N   Trim no more than N leading tabs.
		  -t, --truncate   Remove initial and trailing lines containing only
		                   whitespace."
		return
	end

	set text (string split \n $argv)

	# Truncate if requested.
	if set -q _flag_t
		set lines 0
		while test (count $text) -ne $lines
			set lines (count $text)
			test -z (string trim $text[1]); and set text $text[2..]
			test -z (string trim $text[-1]); and set text $text[1..-2]
		end
	end

	# Trim all leading tabs...
	set -l tabs "^\t+"

	# ...or just N leading tabs.
	set -q _flag_n; and set tabs "^\t{1,$_flag_n}"

	# Remove the tabs and return the string.
	printf "%s\n" (string replace -r -a $tabs '' -- $text)
end