function compare
	set -l opts
	set -a opts "a/accept"
	set -a opts "e/ext="
	set -a opts "h/help"
	set -a opts "q/quiet"
	set -a opts "t/type="
	set -a opts "v/verbose"
	argparse $opts -- $argv

	set usage '
		Returns the result (zero is true) of comparing two files. Comparison
		type is "newer" if the type is not set.
		
		Usage: check [options] [--type TYPE] BASE [TARGET]
		Arguments:
		  BASE     The main file.
		  TARGET   The file to compare with BASE. Not required if -e is used.
		  TYPE     The type of comparison. Defaults to "newer".
		Options:
		  -a, --accept    Return a status code of 0 if TARGET is missing.
		  -e, --ext EXT   Instead of TARGET, compare BASE to a file with the
		                  same name but with extension EXT.
		  -h, --help      Print this help.
		  -q, --quiet     Suppress error messeges.
		  -v, --verbose   Print details of the comparison.
		Types:
		  bigger     Is BASE bigger than TARGET?
		  equal      Do BASE and TARGET have the same number of lines?
		  different  Do BASE and TARGET have different md5 hashes?
		  exists     Does TARGET exist?
		  group      Are BASE and TARGET owned by the same group?
		  less       Does BASE have fewer lines than TARGET?
		  more       Does BASE have more lines than TARGET?
		  newer      Is BASE newer than TARGET?
		  older      Is BASE older than TARGET?
		  owner      Do BASE and TARGET have the same owner?
		  same       Do BASE and TARGET have the same md5 hash?
		  smaller    Is BASE smaller than TARGET
		Return Codes:
		   0   Comparison is true.
		   1   Comparison is false.
		   2   BASE not found.
		   3   TARGET not found.
		  10   Unknown comparison type.
		'

	set -q _flag_h; and begin
		printf "%s\n" (tabtrim -t $usage)
		return
	end

	set -l base $argv[1]
	set -l target $argv[2]

	# Refine the target filename
	if set -q _flag_e
		if test (count $argv) -gt 1
			set -q _flag_q; or echo "error: if -e/--ext is used, the TARGET file unnecessary." >&2
			return 1
		else
			set t (string join '.' (string split '.' $base)[1..-2])
			if string match -q '.*' $_flag_e
				set target (string join '' $t $_flag_e)
			else
				set target (string join '' $t '.' $_flag_e)
			end
		end
	else if test (count $argv) -ne 2
		set -q _flag_q; or echo "error: you must specify a BASE and TARGET file." >&2
		return 3
	end

	# Print usage.
	if set -q _flag_h
		printf "%s\n" (tabtrim -Tt $usage)
		return
	end

	# Set verbose
	set -l verbose false
	if set -q _flag_v
		set verbose true
	end

	# Comparison type defaults to newer.
	if not set -q _flag_t
		set _flag_t newer
	end

	# Check for missing target.
	if not test -e "$target"
		if $verbose; echo "Target file $target does not exist."; end
		if set -q _flag_a
			return 0
		end
		set -q _flag_q; or echo "file $target does not exist." >&2
		return 3
	end

	# Check for missing base.
	if not test -e $base
		$verbose; and echo "Base file $base does not exist."
		set -q _flag_q; or echo "file $base does not exist." >&2
		return 2
	end
	
	# Process based on the comparison type.
	switch $_flag_t
		case bigger
			if $verbose; echo "Is $base bigger than $target?"; end
			return (test (stat -f '%z' "$base") -gt (stat -f '%z' "$target"))
		case different
			if $verbose; echo "Do $base and $target have the same md5 hash?"; end
			set -l hashes (openssl dgst -md5 $base $target | string split "= " -f 2)
			return (test $hashes[1] != $hashes[2])
		case equal
			if $verbose; echo "Do $base and $target have the same number of lines?"; end
			set -l lines (wc -l $base $target | string trim | string split ' ' -f1)
			return (test $lines[1] -eq $lines[2])
		case exists
			if $verbose; echo "Do both $base and $target exist?"; end
			# We already tested and returned if either file is missing
			return 0
		case group
			if $verbose; echo "Are $base and $target owned by the same group?"; end
			return (test (stat -f '%Sg' "$base") = (stat -f '%Sg' "$target"))
		case less
			if $verbose; echo "Does $base have fewer lines than $target?"; end
			set -l lines (wc -l $base $target | string trim | string split ' ' -f1)
			return (test $lines[1] -lt $lines[2])
		case more
			if $verbose; echo "Does $base have more lines than $target?"; end
			set -l lines (wc -l $base $target | string trim | string split ' ' -f1)
			return (test $lines[1] -gt $lines[2])
		case newer
			if $verbose; echo "Is $base newer than $target?"; end
			return (test (stat -f '%m' "$base") -gt (stat -f '%m' "$target"))
		case older
			if $verbose; echo "Is $base older than $target?"; end
			return (test (stat -f '%m' "$base") -lt (stat -f '%m' "$target"))
		case owner
			if $verbose; echo "Do $base and $target have the same owner."; end
			return (test (stat -f '%Su' "$base") = (stat -f '%Su' "$target"))
		case same
			if $verbose; echo "Do $base and $target have the same md5 hash?"; end
			set -l hashes (openssl dgst -md5 $base $target | string split "= " -f 2)
			return (test $hashes[1] = $hashes[2])
		case smaller
			if $verbose; echo "Is $base smaller than $target?"; end
			return (test (stat -f '%z' "$base") -lt (stat -f '%z' "$target"))
		case '*'
			echo "error: unknown comparison: $_flag_t"
			return 10
	end
end