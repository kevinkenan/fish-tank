function testcmd
	set -l opts
	set -a opts "X/xxx"
	set -a opts "a/abc"
	argparse --stop-nonopt $opts -- $argv
	or return

	# echo $_flag_X
	if set -q _flag_a
		echo got a at root
	end

	function _testcmd
		_cmd_register --no_opts \
			--help_text "A simple demonstration of exec_command_path." \
			--arg_list "" \
			--arg_help "" \
			--opt_help ""
		or return
	end

	function _testcmd:foo:bar 
		_cmd_register --action --no_opts \
			--help_text "Test a subcommand with no defined parent command."
		or return

		echo "foo bar works, without parent command 'foo' being defined."
	end

	function _testcmd:test
		set -l opts
		set -a opts "a/abc"
		argparse --stop-nonopt $opts -- $argv
		or return

		_cmd_register  \
			--help_text "Everyone loves Nietzshce!"
		or return

		set -q _flag_a; and echo testcmd test got an a
	end

	function _testcmd:test:this
		set -a opts (fish_opt -s A -l arg1 -r --long-only)
		set -a opts (fish_opt -s B -l arg2 -r --long-only)
		set -a opts (fish_opt -s a -r)
		set -a opts (fish_opt -s n -l nothing)
		argparse -n "$_cmdpath" $opts -- $_args; or return

		set -q _flag_a; and echo $_cmdpath got an a

		_cmd_register --action \
			--help_text "
			Print an inspirational message.
			From Nietzshce.
			" \
			--arg_list "--arg1 ARG1 --arg2 ARG2" \
			--arg_help "
			  ARG1   This is the first argument that is ignored.
			  ARG2   The second argument is just as ignored as the first." \
			--opt_help "
			  -a VALUE        Does absolutely nothing of VALUE.
			  -h, --help      Print this help.
			  -n, --nothing   Does nothing.
			  -t              Does even more of nothing."
		or return

		echo That which does not kill us makes us stronger.
	end

	function _testcmd:test:that
		_cmd_register  --action --no_opts \
			--help_text "Print a despairing message."
		or return

		echo When you stare long into the abyss the abyss stares into you.
	end

	function _testcmd:what
		_cmd_register --action; or return
		echo A bare bones command.
	end

	function _testcmd:zip
		_cmd_register --action \
		  --help_text "An example of processing arguments." \
		  --arg_list "[zap]"
		or return

		set -l msg Zip
		for arg in $argv
			switch $arg
			case ''
			case "zap"
				set -a msg Zap
			case '*'
				echo "$_cmdpath": unknown argument: \'$arg\' >&2
				return 1
			end
		end

		echo $msg
	end

	exec_command_path \
		--root_cmd "testcmd" \
		-- $argv
end