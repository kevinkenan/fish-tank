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
#
function usage
	set -l opts 
	set -a opts (fish_opt -r -s n -l name)
	set -a opts (fish_opt -r -s t -l help_text)
	set -a opts (fish_opt -r -s g -l arg_list)
	set -a opts (fish_opt -r -s r -l arg_help)
	set -a opts (fish_opt -r -s o -l opt_help)
	argparse -n "$_cmdpath" $opts -- $argv; or return

	# Prework to set the function name.
	if set -q _flag_n
		set callstack "" $_flag_n
	else
		set -l callstack 
		for l in (status -t)
			# Turn the stack into a simple list of function calls.
			set -a callstack (string match -ar 'function \'(.*?)\'' $l)[2]
		end
	end

	set -l fncname $callstack[2]
	set -l depends $_flag_depends
	set -l helptxt $_flag_t
	set -l arglist $_flag_g
	set -l arghelp $_flag_r
	set -l opthelp $_flag_o

	set -l usage 

	# Print the help info if supplied in helptxt. If help info was
	# requested, then the command does not return an error.
	set rcode 0
	if test -n "$helptxt"
		# set text (string split \n $helptxt)
		# test -z (string trim $text[1]); and set text $text[2..]
		# test -z (string trim $text[-1]); and set text $text[1..-2]
		set -a usage (printf '%s\n' 'Help:')
		set -a usage (printf "%s\n" (tabtrim -t $helptxt))
		set -a usage (printf '%s\n' '--')
	end

	# Print the main usage string
	set -a usage "Usage: [options] $arglist"

	# Print arghelp if it exists
	if test -n "$arghelp"
		set -a usage "Arguments:"
		set -a usage (printf "%s\n" (string trim -l -c \n $arghelp | string replace -r '^\t+' ''))
	end

	# Print options help if it exists.
	if test -n "opthelp"
		set -a usage "Options:"
		set -a usage (printf "%s\n" (string trim -l -c \n $opthelp | string replace -r '^\t+' ''))
	end

	printf "%s\n" $usage
end