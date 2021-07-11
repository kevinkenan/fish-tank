
function exec_command_path
	set -gx _ecp_init
	set -lx _args
	set -lx _check_exe false
	set -lx _cmdpath
	set -lx _init_funcs
	set -lx _cmd_help_none 0 # Don't show any help text.
	set -lx _cmd_help_path 1 # Show just the path help.
	set -lx _cmd_help_full 2 # Show the full help.
	set -lx _showhelp $_cmd_help_none

	# Return codes:
	set -lx _cmdpath_listing 2 # 
	set -lx _stop 120 # (deprecated) execution stopped safely

	function :_unload
		functions -e (functions -a | grep "_$_cmdpath[1]:")
		functions -e ":_unload"
	end

	# _cmd_register return codes:
	#    0  The command should continue executing.
	#  110  Printed the help messge. Stop execution.
	#  111  Executable check returned false. Stop execution.
	#  112  Executable check returned true. Stop execution.
	#  113  Executable check indicates initialization. Stop execution.
	#  120  Printed command path listing. Stop execution.
	function _cmd_register
		# The return code defaults to indicate that the command printed the
		# command path listing and was not an executable command.
		set -l rcode 120

		set -l opts 
		set -a opts "d/depends=+"
		set -a opts (fish_opt -r -s t -l help_text)
		set -a opts (fish_opt -r -s g -l arg_list)
		set -a opts (fish_opt -r -s r -l arg_help)
		set -a opts (fish_opt -r -s o -l opt_help)
		set -a opts (fish_opt -s a -l action)
		set -a opts (fish_opt -s x -l no_opts)
		set -a opts "i/init"
		set -a opts "e/exe"
		# set -a opts "R/args="
		# set -a opts "A/allow-args"
		# set -a opts "O/allow-opts"
		argparse -n "$_cmdpath" $opts -- $argv; or return

		# a/action is deprecated, but for now it is a synonym for e/exe.
		set -q _flag_a; and set _flag_e

		# This is a special handler that mimics reflection. When a function is
		# called and _check_exe is set to true, the function's execution is
		# short circuted and the return code indicates the type of function.
		if $_check_exe
			set -q _flag_e; and return 112
			set -q _flag_i; and return 113
			return 111
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

		# If this command contains initialization code and help is not
		# requested, return and execute it.
		if set -q _flag_i; and test $_showhelp -eq $_cmd_help_none
			set -q _CMD_VERBOSE; and echo executing: $_cmdpath[1] (string split ':' $fncname)[2..]
			return 0
		end

		# # Experimental: Return an error if the command does not support
		# # arguments and yet arguments were passed to the command.
		# if set -q _flag_R; and test -z "$arglist" -a -z "$arghelp"; and not set -q _flag_A
		# 	set -l a (string match -v -- "-*" $_flag_R)
		# 	if test (count $a) -gt 0
		# 		echo "$_cmdpath": Unknown argument \'(string split ' ' -- $a)[1]\'
		# 		return 1
		# 	end
		# end

		# # Experimental: Return an error if the command does not parse nor
		# # support options and yet options were passed to the command.
		# if set -q _flag_R; and test -z "$opthelp"; and not set -q _flag_O
		# 	if test (count (string match -- "-*" $_flag_R)) -gt 0
		# 		echo "$_cmdpath": Unknown option \'(string split ' ' -- $_args)[1]\'
		# 		return 1
		# 	end
		# end

		# If this is an executable command and help is not requested, execute
		# any initialization functions and then return so that the command
		# will execute. The results of initialization are stored in the global
		# variable _ecp_init.
		if set -q _flag_e; and test $_showhelp -eq $_cmd_help_none
			for f in $_init_funcs
				set -a _ecp_init ($f $_args); or return
			end
			return 0
		end

		# Print the help info if supplied in helptxt. If help info was
		# requested, then the command does not return an error.
		if test $_showhelp -eq $_cmd_help_full
			set rcode 110
			if test -n "$helptxt"
				echo ""
				# echo -n "  "
				for l in (string split \n (tabtrim -t $helptxt))
					printf "  %s\n" $l
				end
				echo ""
			end
		end

		# We only want {command} printed if there are subcommands, i.e. this
		# isn't an executable command.
		if not set -q _flag_e
			set command {command}
		end

		# Print the main usage string
		echo "Usage:" $_cmdpath $command [options] $arglist

		# Get all the commands that could be called next.
		set -l cmdp _(string join ':' $_cmdpath)
		set nextcmds (functions -a | string match -r \^$cmdp'[:\$]{1}[^_]\w+')
		for f in  $nextcmds
			# This is kinda ugly, but it appends '*' to commands that execute
			# code as opposed to being just another part of the cmd path.
			set exe ""
			if functions -q $f
				_check_exe=true $f
				test $status -eq 112; and set exe '*'
			end
			set -l newcmd (string split : $f)[-1]"$exe"
			contains $newcmd $subcmds; or set -a subcmds $newcmd
		end

		# List the commands available from this path.
		if not set -q _flag_e
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


	# Create a tree of the available commands
	function _cmd_get_commands
		set -l parentcmd $argv[1]
		set -l cmdcounts $argv[2..]

		# Are there child commands?
		set -l childcmds (functions -a | string match -r "^$parentcmd"'[:\$]{1}[^_]\w+' | sort | uniq)
		set -a cmdcounts (count $childcmds)

		# Print the root command
		if test (count $cmdcounts) -eq 1
			echo (string trim -c '_' $parentcmd)
		end

		# Handle child commands
		for c in $childcmds
			set -l cmd_name (string split -r --max 1 ':' -f 2 $c)

			# Print the parent command structure.
			for n in $cmdcounts[..-2]
				switch $n
				case 0
					echo -n '   '
				case '*'
					echo -n '│  '
				end
			end

			# Print the current command.
			if test $cmdcounts[-1] -eq 1
				echo '└─' $cmd_name #" counts: $cmdcounts"
			else
				echo '├─' $cmd_name #" counts: $cmdcounts"
			end

			# Adjust the counts.
			if test $cmdcounts[-1] -eq 0 
				set cmdcounts $cmdcounts[..-2]
			else
				set cmdcounts $cmdcounts[..-2] (math $cmdcounts[-1] - 1)
			end

			# Process granchildren commands.
			_cmd_get_commands $c $cmdcounts
		end
	end

###############################################################################

	set -a opts "r-root_cmd="
	argparse -n="exec_command_path" $opts -- $argv; or return

	set _cmdpath $_flag_root_cmd
	set _showhelp $_cmd_help_path

	# If argv only consists of +, then print the command tree and exit.
	if test (count $argv) -eq 1 -a "$argv[1]" = "+"
		_cmd_get_commands _$_flag_root_cmd
		:_unload
		return
	end

	# Separate the command path from arguments and options and note any
	# initialization functions.
	if test (count $argv) -gt 0
		set -l ctr 2
		for c in $argv

			# If c is an option, stop processing the command path.
			if string match -q -- "-*" $c
				set _args $c $argv[$ctr..]
				break
			end

			# Build the command path.
			set -a _cmdpath $c

			# Stop processing the command path when we reach the executable
			# command.
			set -l partialcmd _(string join ':' $_cmdpath)
			if functions -q $partialcmd
				# Is partialcmd executable?
				_check_exe=true $partialcmd
				switch $status
				case 112
					# The command is executable so populate the args.
					set _args $argv[$ctr..]
					# Executable functions show the full help if requested.
					set _showhelp $_cmd_help_none
					break
				case 113
					# It is a command path function with initiatization code.
					set -a _init_funcs $partialcmd
				case 111
					# The command is not executable.
				case '*'
					return
				end
			end

			# ...and is not exectuable; keep processing the command path.
			set ctr (math $ctr + 1)
		end
	end

	# Check if the command is known or if it is an implicit part of command path.
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

	# Set _showhelp if -h/--help was set.
	if test -n "$t1" -o -n "$t2"
		set _showhelp $_cmd_help_full
	end

	# Execute the command.
	$cmd $_args; set s $status
	:_unload

	# Exit with the status returned by $cmd.
	switch $s
	case 110 120
		return 0
	case '*'
		return $s
	end
end
