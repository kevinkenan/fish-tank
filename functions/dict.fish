function dict
	set -l opts
	set -a opts "a/append"
	set -a opts "c/count"
	set -a opts "e/erase"
	set -a opts "h/help"
	set -a opts "i/init"
	set -a opts "k/keys"
	set -a opts "q/query="
	set -a opts "r/retrieve"
	set -a opts "v/value"
	argparse $opts -- $argv
	or return

	if set -q _flag_h
		printf "%s\n" (usage \
			--help_text "
			EXPERIMENTAL
			Simulate an associative array with a pair of lists. These lists
			must be named VAR__keys and VAR__vals. If no operation is specified
			the command prints the contents of the array." \
			--arg_list "VAR [operation]" \
			--arg_help "
			  VAR     The base name of the underlying lists.
			Operations:
			  --init (i)
			      Create global variables VAR__keys and VAR__vals.
			  --append (-a) KEY VALUE
			      Associate KEY to VALUE, replacing VALUE if KEY already exists.
			  --erase (-e) KEY
			      Remove KEY and its value.
			  --query (-q) KEY
			      Return 0 if KEY exists.
			  --retrieve (-r) KEY
			      Retrieve the value associated with KEY.
			  --count (-c)
			      Print the number of elements.
			  --keys (-k)
			      List the keys.
			  --values (-v)
			      List the values." \
			--opt_help "
			  -h, --help   Print this help.")
		return
	end

	set -l dictname $argv[1]
	set -l key $argv[2]
	set -l val $argv[3..]
	set -l allkeys $dictname"__keys"
	set -l allvals $dictname"__vals"

	# A convenience to create the underlying dictionary lists.
	if set -q _flag_i
		set -g $allkeys
		set -g $allvals
		return
	end

	# Check that both underlying lists exist
	set -l err
	set -q $allkeys; or set -a err $allkeys
	set -q $allvals; or set -a err $allvals
	if test -n "$err"
		echo "dict: lists" (string join ' and ' $err) do not exist >&2
		return 1
	end

	# Check that the underlying lists have the same number of elements.
	set -l ck (count $$allkeys)
	set -l cv (count $$allvals)
	if test $cv -ne $ck
		echo "dict: $allkeys and $allvals have different lengths" >&2
		return 1
	end

	# Determine which operation is requested and that the requirements for
	# that operation are satisfied.
	set -l op show
	if set -q _flag_r
		if test -z $key
			echo "dict: retrieve: key required" >&2
			return 1
		end
		set op retrieve
	else if set -q _flag_q
		if test -z $key
			echo "dict: query: key required" >&2
			return 1
		end
		set op query
	else if set -q _flag_c
		set op count
	else if set -q _flag_a
		if test -z "$key" -o -z "$val"
			echo "dict: append: key and value required" >&2
			return 1
		end
		set op append
	else if set -q _flag_e
		if test -z $key
			echo "dict: erase: key required" >&2
			return 1
		end
		set op erase
	else if set -q _flag_k
		set op keys 
	else if set -q _flag_v
		set op values
	end

	# Execute the requested operation.
	switch (echo $op)
	case count
		echo $ck
	case show
		if test (count $$allkeys) -eq 0
			return
		end
		for i in (seq (count $$allkeys))
			echo $$allkeys[1][$i]::$$allvals[1][$i]
		end
	case query
		return (contains -- $key $$allkeys)
	case retrieve
		if set -l i (contains -i -- $key $$allkeys)
		    echo $$allvals[1][$i]
		end
	case append
		if set -l i (contains -i -- $key $$allkeys)
		    set $allvals[1][2] $val
		else
			set -a $allkeys $key 
			set -a $allvals $val
			True
		end
	case erase
		if set -l i (contains -i -- $key $$allkeys)
		    set -e $allkeys[1][$i]
		    set -e $allvals[1][$i]
		    True
		end
	case keys 
		# printf "%s\n" $$allkeys
		for k in $$allkeys
			echo $k
		end
	case values
		# printf "%s\n" $$allvals
		for v in $$allvals
			echo $v
		end
	case '*'
		echo "dict: unknown operation"
		return 1
	end
end