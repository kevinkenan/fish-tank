# Return the first argument that is not empty.
function select
	for arg in $argv
		if test -n "$arg"
			echo $arg
			break
		end
	end
end
