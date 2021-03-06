function testcmd

	# This is the root command.
	function _testcmd
		_cmd_register --no_opts \
			--help_text "A simple demonstration of exec_command_path." \
			--arg_list "" \
			--arg_help "" \
			--opt_help ""
		or return
	end


	# Demonstrates that you do not need to explicitly define parent commands.
	# In this case there is no 'foo' command defined.
	function _testcmd:foo:bar 
		_cmd_register --exe \
			--help_text "Test a subcommand without an explicit definition."
		or return

		echo "'testcmd foo bar' works without the subcommand 'foo' being defined."
	end


	# This is a non-executable command that is the parent for other commands.
	# It has it's own help message.
	function _testcmd:test
		_cmd_register \
			--help_text "Everyone loves Nietzshce!"
		or return
	end


	# This shows how options and _cmd_register are used.
	function _testcmd:test:this
		set -l opts
		set -a opts "A-arg1="
		set -a opts "B-arg2="
		set -a opts "a/abc"
		set -a opts "n/nothing"
		argparse -n "$_cmdpath" $opts -- $argv; or return

		_cmd_register --exe \
			--help_text "
			Print an inspirational message.
			From Nietzshce.
			" \
			--arg_list "--arg1 ARG1 --arg2 ARG2" \
			--arg_help "
			  ARG1   This is the first argument that is ignored.
			  ARG2   The second argument is just as ignored as the first." \
			--opt_help "
			  -a, --abc VALUE   Does absolutely nothing of VALUE.
			  -h, --help        Print this help.
			  -n, --nothing     Does nothing."
		or return

		echo That which does not kill us makes us stronger.
	end


	# Just a simple command that shows how a parent command, 'test' in this case,
	# can have muliple child commands: 'this' and 'that'.
	function _testcmd:test:that
		_cmd_register --exe --help_text "Print a despairing message." 
		or return

		echo When you stare long into the abyss the abyss stares into you.
	end


	# The simplest executable command. Quick and easy to implement, but it
	# provides the user with no help.
	function _testcmd:what
		_cmd_register --exe; or return
		echo A bare bones command.
	end


	# A simple example of using options and arguments.
	function _testcmd:tick
		argparse -n "$_cmdpath" --max-args 1 "b/boom" -- $argv
		or return

		_cmd_register --exe \
		  --help_text "An example of processing options and arguments." \
		  --arg_list "[tock]" \
		  --opt_help "
		    -b, --boom   Boom!"
		or return

		set -l msg Tick
		for arg in $argv
			switch $arg
			case "tock"
				set -a msg Tock
			case '*'
				echo "$_cmdpath": unknown argument: \'$arg\' >&2
				return 1
			end
		end

		set -q _flag_b; and set -a msg "Boom!"

		echo $msg
	end


	# The next several functions define the 'go' commands, which demonstrate
	# how non-executable parent commands can contain initialization code.
	# This functionality is still somewhat experimental.

	set -x go_opts
	set -a go_opts "R/ready"
	set -x go_opts_help \
		"Go Options:
		  -R, --ready   Ready to go."

	function _testcmd:go
		argparse -n "$_cmdpath" --ignore-unknown $go_opts -- $argv
		or return

		_cmd_register --init --help_text "Going somewhere."
		or return

		set -l readiness "no"
		set -q _flag_R; and set readiness "yes"

		echo "go:$readiness"
	end


	set -x move_opts
	set -a move_opts "u/up"
	set -a move_opts "d/down"
	set -a move_opts "l/left"
	set -a move_opts "r/right"
	set -a move_opts "o/other="
	set -x move_opts_help \
		"Move Options:
		  -u, --up          Move up
		  -d, --down        Move down.
		  -l, --left        Move left.
		  -r, --right       Move right.
		  -o, --other DIR   Move in the direction DIR."

	function _testcmd:go:move
		set -l opts $move_opts
		argparse -n "$_cmdpath" --ignore-unknown $opts -- $argv
		or return

		_cmd_register --init --help_text "Move commands." 
		or return

		set -l dir
		set -q _flag_u; and set dir up
		set -q _flag_d; and set dir down
		set -q _flag_l; and set dir left
		set -q _flag_r; and set dir right
		set -q _flag_o; and set dir "$_flag_o"

		echo "move:$dir"

		echo "ERROR" >&2
		return 1
	end


	function _testcmd:go:move:fast
		set -l opts
		set -a opts "f/faster"
		set -a opts $go_opts
		set -a opts $move_opts
		argparse -n "$_cmdpath" $opts -- $argv
		or return

		_cmd_register --exe \
			--help_text "Fast mover." \
			--arg_list "[go options] [move options]" \
			--opt_help "
			  -f, --faster   Move even faster.
			$move_opts_help
			$go_opts_help"
		or return

		set -l dir
		set -l ready
		for c in $_ecp_init
			set -l kv (string split ':' -m 1 $c)
			switch $kv[1]
			case move
				set dir $kv[2]
			case go
				set ready $kv[2]
			end
		end

		if test "$ready" != "yes"
			echo "Not ready"
			return 1
		end

		set -l speed (set -q _flag_f; and echo faster; or echo fast)

		echo Moving (select "$dir" "nowhere") $speed.
	end


	function _testcmd:go:move:slow
		set -l opts
		set -a opts "s/slower"
		set -a opts $go_opts
		set -a opts $move_opts
		argparse -n "$_cmdpath" --max-args 0 $opts -- $argv
		or return

		_cmd_register --exe \
			--help_text "Slow mover." \
			--arg_list "[go options] [move options]" \
			--opt_help "
			  -s, --slower   Move even slower.
			$move_opts_help
			$go_opts_help"
		or return

		set -l dir
		set -l ready
		for c in $_ecp_init
			set -l kv (string split ':' -m 1 $c)
			switch $kv[1]
			case move
				set dir $kv[2]
			case go
				set ready $kv[2]
			end
		end

		if test "$ready" != "yes"
			echo "Not ready"
			return 1
		end

		set -l speed (set -q _flag_s; and echo slower; or echo slow)

		echo Moving (select "$dir" "nowhere") $speed.
	end


##########################################################################

	exec_command_path -- $argv
end