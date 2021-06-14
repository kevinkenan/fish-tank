function testcmd
	function _testcmd
		_cmd_register --no_opts \
			--help_text "A simple demonstration of exec_command_path." \
			--arg_list "" \
			--arg_help "" \
			--opt_help ""
		or return
	end

	function _testcmd:foo:bar 
		_cmd_register --action \
			--help_text "Test a subcommand with no defined parent command."
		or return

		echo "foo bar works, without parent command 'foo' being defined."
	end

	function _testcmd:test
		_cmd_register --no_opts \
			--help_text "Everyone loves Nietzshce!"
		or return
	end

	function _testcmd:test:this
		set -a opts (fish_opt -s A -l arg1 -r --long-only)
		set -a opts (fish_opt -s B -l arg2 -r --long-only)
		set -a opts (fish_opt -s a -r)
		set -a opts (fish_opt -s n -l nothing)
		argparse -n "$_cmdpath" $opts -- $_args; or return

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

		echo When you stare into the abyss the abyss stares back at you.
	end

	function _testcmd:what
		_cmd_register --action; or return
		echo A bare bones command.
	end

	exec_command_path \
		--root_cmd "testcmd" \
		-- $argv
end