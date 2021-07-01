# Utility function to easily format a usage message.
# Example:
# 	set -l usage (usage \
# 		--help_text "Hello, world." \
# 		--arg_list "--arg1 ARG1 --arg2 ARG2" \
# 		--arg_help "
# 		  ARG1   This is the first argument that is ignored.
# 		  ARG2   The second argument is just as ignored as the first." \
# 		--opt_help "
# 		  -a VALUE        Does absolutely nothing of VALUE.
# 		  -h, --help      Print this help.
# 		  -n, --nothing   Does nothing.
# 		  -t              Does even more of nothing.")
function usage
	set -l opts 
	set -a opts (fish_opt -r -s n -l name)
	set -a opts (fish_opt -r -s t -l help_text)
	set -a opts (fish_opt -r -s g -l arg_list)
	set -a opts (fish_opt -r -s r -l arg_help)
	set -a opts (fish_opt -r -s o -l opt_help)
	argparse -n "usage" $opts -- $argv; or return

	# Prework to set the function name.
	set -l callstack 
	if set -q _flag_n
		set callstack "" $_flag_n
	else
		for l in (status -t)
			# Turn the stack into a simple list of function calls.
			set -a callstack (string match -ar '^in function \'(.*?)\'' $l)[2]
		end
	end

	set -l fncname $callstack[2]
	set -l helptxt $_flag_t
	set -l arglist $_flag_g
	set -l arghelp $_flag_r
	set -l opthelp $_flag_o

	# All of the help and usage text is stored in $usage.
	set -l usage 

	# Add the help info to usage if supplied in helptxt.
	if test -n "$helptxt"
		set -a usage (printf "%s\n" (tabtrim -t $helptxt))
		set -a usage (printf '%s\n' '')
	end

	# Add the main usage string.
	set -a usage "Usage: $fncname [options] $arglist"

	# Add arghelp if it exists
	if test -n "$arghelp"
		set -a usage "Arguments:"
		set -a usage (printf "%s\n" (tabtrim -t $arghelp))
	end

	# Add options help if it exists.
	if test -n "opthelp"
		set -a usage "Options:"
		set -a usage (printf "%s\n" (tabtrim -t $opthelp))
	end

	printf "%s\n" $usage
end