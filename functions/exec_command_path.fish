
function exec_command_path
	set -x _args
	set -x _check_exe false
	set -x _cmdpath
	set -x _showhelp false
	# Return codes:
	set -x _cmdpath_listing 2 # 
	set -x _stop 120 # (deprecated) execution stopped safely

	function :_unload
		functions -e (functions -a | grep "_$_cmdpath[1]:")
		functions -e ":_unload"
	end

	# _cmd_register return codes:
	#    0  The command should continue executing.
	#  110  Printed the help messge. Stop execution.
	#  111  Executable check returned true. Stop execution.
	#  112  Executable check returned false. Stop execution.
	#  120  Printed command path listing. Stop execution.
	function _cmd_register
		# The return code defaults to indicate that the command printed the
		# command path listing and was not an executable command.
		set rcode 120

		set -l opts 
		set -a opts "d/depends=+"
		set -a opts (fish_opt -r -s t -l help_text)
		set -a opts (fish_opt -r -s g -l arg_list)
		set -a opts (fish_opt -r -s r -l arg_help)
		set -a opts (fish_opt -r -s o -l opt_help)
		set -a opts (fish_opt -s a -l action)
		set -a opts (fish_opt -s x -l no_opts)
		argparse -n "$_cmdpath" $opts -- $argv; or return

		# This is a special handler that mimics reflection. When a function is
		# called and _check_exe is set to true, the function's execution is
		# short circuted and returns 0 if the function is an "action" function
		# or a 1 if it is an element of a command path.
		if $_check_exe
			set -q _flag_a; and return 111
			return 112
		end

		# Get a callstack list.
		set -l callstack 
		for l in (status -t)
			# Turn the stack into a simple list of function calls.
			set -a callstack (string match -ar 'function \'(.*?)\'' $l)[2]
		end

		set -l fncname $callstack[2]
		set -l depends $_flag_depends
		set -l helptxt $_flag_t
		set -l arglist $_flag_g
		set -l arghelp $_flag_r
		set -l opthelp $_flag_o

		# Check for 'extra' options when there should be none.
		if set -q _flag_x; and test (count $_args) -gt 0
			echo "$_cmdpath": Unknown option (string split ' ' -- $_args)[1]
			return 1
		end

		# If this is an "action" command and help is not requested, return and
		# execute the action.
		if set -q _flag_a; and not $_showhelp
			set -q _CMD_VERBOSE; and echo executing: $_cmdpath[1] (string split ':' $fncname)[2..]
			return 0
		end

		# Print the help info if supplied in helptxt. If help info was
		# requested, then the command does not return an error.
		if $_showhelp
			set rcode 110
			if test -n "$helptxt"
				tabtrim -t $helptxt
				printf '%s\n' '--'
			end
		end

		# We only want {command} printed if there are subcommands, i.e. this
		# isn't an action command.
		if not set -q _flag_a
			set command {command}
		end

		# Print the main usage string
		echo "Usage:" $_cmdpath $command [options] $arglist
		
		# Create the list of subcmds by inspecting function names that begin
		# with the calling function's name and don't begin with '_'.
		# set fn (functions -a | grep "$fncname:[^_][^:]*\$")

		# Get all the commands that could be called next.
		set -l cmdp _(string join ':' $_cmdpath)
		set nextcmds (functions -a | string match -r \^$cmdp'[:\$]{1}[^_]\w+')
		for f in  $nextcmds
			# This is kinda ugly, but it appends '*' to commands that execute
			# code as opposed to being just another part of the cmd path.
			set exe ""
			if functions -q $f
				_check_exe=true $f
				test $status -eq 111; and set exe '*'
			end
			set -l newcmd (string split : $f)[-1]"$exe"
			contains $newcmd $subcmds; or set -a subcmds $newcmd
		end

		# List the commands available from this path.
		if not set -q _flag_a
			echo "Commands:"
			for c in $subcmds
				echo "  $c"
			end
		end

		# Print arghelp if it exists
		if test -n "$arghelp"
			echo "Arguments:"
			tabtrim -t $arghelp
		end

		# Print options help which always is present because the h/help option
		# is builtin.
		echo "Options:"
		if test -z "$opthelp"
			echo "  -h, --help   Print help"
		else
			tabtrim -t $opthelp
		end

		return $rcode
	end

###############################################################################

	set -a opts (fish_opt -r -s r -l root_cmd --long-only)
	argparse -n="exec_command_path" $opts -- $argv; or return

	set _cmdpath $_flag_root_cmd

	# Separate the command path from arguments and options. Note that
	# arguments are indicated by a '@' prefix.
	if test (count $argv) -gt 0
		for i in (seq 1 (count $argv))
			if string match -q -- "--" $argv[$i]; and test (count $argv) -gt $i
				set _args $argv[(math $i + 1)..]
				break
			else if string match -q -- "-*" $argv[$i]; or string match -q "@*" $argv[$i]
				set _args $argv[$i..]
				break
			else
				set -a _cmdpath $argv[$i]
			end
		end
	end

	# Build cmd (the function name) from the command path and error if an
	# unknown command is encountered.
	set cmd _(string join ":" $_cmdpath)
	set allfunc (functions -a)
	if not contains "$cmd" $allfunc
		# The cmd is not known. Check to see if it is part of a path...
		if string match -qr "$cmd:" $allfunc
			# The unknown cmd is part of a path command list so as a
			# convenience create the function on the fly.
			function $cmd 
				_cmd_register --no_opts 
			end
		else
			echo "error: unknown command:" $_cmdpath
			return 1
		end
	end

	# Check to see if -h/--help was set and if so remove it from the _args
	# list.
	set -l t1 (contains -i -- '-h' $_args)
	if test $status -eq 0; set -e _args[$t1]; end
	set -l t2 (contains -i -- '--help' $_args)
	if test $status -eq 0; set -e _args[$t2]; end

	# Set the exported _showhelp to true if -h/--help was set.
	if test -n "$t1" -o -n "$t2"
		set _showhelp true
	end

	# Execute the command. Note that the arguments are stored in the exported
	# variable $_args so no need to pass them explicitly.
	$cmd; set s $status
	:_unload

	# Exit with the status returned by $cmd.
	switch $s
	case 110 120
		return 0
	case '*'
		return $s
	end
end