function apply_dependency_rules
	set -l opts "h/help"
	set -a opts "r/rule=+"
	set -a opts "d/dep-type="
	set -a opts "m/dep-map"
	set -a opts "p/path="
	argparse $opts -- $argv
	or return

	set -l usage (usage \
		--help_text "
		  Make-like dependency processing that returns a list of files which have
		  'expired' and need to be processed further. Mapping rules are applied to
		  input files to determine dependencies, and the dependencies are then
		  compared to the input files to determine if they have expired.
		
		  Mapping Rules:
		    a:b   Files with extension a depend on files with extension b.
		     :b   Files with no extensions are mapped to b.
		     :    Files with no extensions continue to have no extensions." \
		--arg_list "--rule RULE FILE ..." \
		--arg_help "
		  RULE   A dependency rule. You may have multiple rule arguments.
		  FILE   One or more files to process." \
		--opt_help "
		  -d, --dep DEP     Type of dependency. DEP must be a type supported by 
		                    `compare`. Defauts to 'older'.
		  -p, --path PATH   Path to the directory containing the dependency files.
		  -m, --dep-map     Print the dependency map and exit.")

	set -q _flag_h; and printf "%s\n" $usage; and return
	set -l deppath (select "$_flag_p" '.')

	# Prepare the rules by encoding them into a pair of matched lists.
	# Extension ext[i] corresponds with dependency dep[i].
	set -l rules $_flag_r
	set -l ext
	set -l dep
	set -l nakedext # 
	for r in $rules
		set -l m (string split ':' $r)
		set -a ext "$m[1]"
		set -a dep "$m[2]"
	end

	# Generate the file dependency mapping according to the rules.
	set -l targets
	set -l depends
	for t in $argv
		set -l te (string split -m 1 -r '.' $t)[2]
		set -l de

		# Is the target's extention in the list of known extensions.
		if set -l i (contains -i "$te" $ext)
			test -n "$dep[$i]"; and set de '.' 
			set de "$de""$dep[$i]"
		else
			echo "error: no rule for file: $t" >&2
			return 1
		end
		
		set -a targets $t
		# set -a depends $deppath/(string split -m 1 -r '.' $t)[1]"$de"
		if test -n "$deppath"
			# If deppath is set, strip the path elements from the targets.
			set -l tpath (string split -m 1 -r '.' $t)[1]"$de"
			set -a depends $deppath/(string split '/' -r -m 1 $tpath)[-1]
		else
			set -a depends (string split -m 1 -r '.' $t)[1]"$de"
		end
	end

	# If requested, print the file dependency map and exit.
	if set -q _flag_m
		set -l files 
		for i in (seq (count $targets))
			set -a files "$targets[$i]:$depends[$i]"
		end
		printf "%s\n" $files
		return
	end

	# Create a list of expired files. An expired file is one which is no
	# longer up-to-date, i.e. the 'compare' function either returns true or
	# indicates that the filed derived from the dependency doesn't exist.
	set -l deptype (select "$_flag_d" older)
	set -l expired

	for i in (seq (count $targets))
		set -l t $targets[$i]
		set -l d $depends[$i]

		compare -q --type "$deptype" "$t" "$d"
		switch $status
		case 0 2
			set -a expired $d			
		case 1
			continue
		case 3
			echo "error: missing dependency: $d" >&2
			return 1
		case '*'
			echo "error: unknown compare result" >&2
			return 1
		end
	end

	test (count $expired) -gt 0; and printf "%s\n" $expired
	return 0
end