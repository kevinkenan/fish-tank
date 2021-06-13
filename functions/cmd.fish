function cmd
	function _cmd
		_cmd_register --no_opts; or return
	end

	# Set the cmdfile.
	set -l cmdfile cmds.cmdfile
	if string match -q '@*' -- $argv[1]
		set cmdfile (string replace '@' '' $argv[1])
		set -e argv[1]
	end
	string match -q '*.cmdfile' $cmdfile; or set cmdfile $cmdfile.cmdfile

	# Ensure the cmdfile exists.
	test -e "./$cmdfile"; or begin
		echo "error: $cmdfile not found"
		return 1
	end

	source ./$cmdfile

	exec_command_path \
		--root_cmd "cmd" \
		-- $argv
end
