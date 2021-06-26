function todo
	set -gx _allitems
	set -gx _goal
	set -gx _work
	set -gx _next
	set -gx _todo
	set -gx _done
	set -gx _comp
	set -gx _xxxx
	set -x specialtags '@' '^' '~' '#' '>'

	function _todo
		_cmd_register --no_opts \
			--help_text "Manage tasks embedded in a file."
		or return
	end

	function _todo:goals
		set -l opts 
		set -a opts "F/file="
		set -a opts "p/prefix="
		set -a opts "f/filter="
		set -a opts "T/table"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List the goals." \
			--opt_help "
			  -F, --file FILE    Look in FILE for tasks instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -p, --prefix PRE   The GOAL keyword is preceded by the prefix PRE.
			  -T, --table        Print tasks in a table with tags."
		or return

		set -l filename (select "$_flag_F" "WORK.txt")
		set -l prefix "[[:blank:]]*"(select "$_flag_p" "")"[[:blank:]]*"

		# Who doesn't love sed?
		set -l sedadd (string join '' '^' $prefix 'GOAL:')
		set -l sedcmd "/$sedadd/{
			=
			h
			s/$sedadd([[:alnum:]]+)[[:blank:]]+.*/\1/
			p
			x
			p
			}"

		# recs is a list containing the set of elements
		#   Line number
		#   Goal alias
		#   Line text
		# for each todo item. So for each r in recs, $r[1] is the line number
		# and $r[2] is the goal alias, and $r[3] is the full text of the line.
		set -l recs (sed -E -n -e "$sedcmd" $filename)
		if test -z "$recs"
			echo "No GOALS found in $filename"
			return 0
		end

		# Set the amount of padding for printing the line number.
		set -l lnumfmt (string length $recs[-3])s

		set -l goals
		for i in (seq 1 3 (count $recs))
			set -l lnum $recs[$i]
			set -l alias $recs[(math $i + 1)]
			set -l text $recs[(math $i + 2)]
			set -l type "GOAL"

			# Separate the alias and tags from the task description.
			string match -qr -- "^$prefix$type:(?<alias>\w+)\W+\[(?<tags>.*)\]\W+(?<task>.+)" $text
			or string match -qr -- "^$prefix$type:(?<alias>\w+)\W+(?<task>.+)" $text
			set tags (string split ' ' $tags)

			# Filter by tag.
			if set -q _flag_f
				contains -- $_flag_f $tags; or continue
			end

			# Do we include tags in the output?
			if set -q _flag_T
				set -a goals (printf "%$lnumfmt GOAL◊%s◊%s◊%s\n" $lnum $alias "$tags" "$task")
			else
				set -a goals (printf "%$lnumfmt GOAL◊%s◊%s\n" $lnum "$alias" "$task")
			end
		end

		# Print the goals.
		set -l out
		test -n "$goals"; and set -a out (printf "%s\n" $goals)
		printf "%s\n" $out | column -t -s '◊'
	end

	function _todo:history
		set -l opts 
		set -a opts "F/file="
		set -a opts "i/include=+"
		set -a opts "g/goal="
		set -a opts "p/prefix="
		set -a opts "r/reverse"
		set -a opts "T/table"
		set -a opts "t/tasks="
		set -a opts "x/exclue=+"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "Examine completed tasks." \
			--opt_help "
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -i, --include TAG  Only show tasks with the tag TAG.
			  -g, --goal GOAL    Only show histor for goal GOAL.
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -r, --reverse      Reverse sort with oldest first.
			  -T, --table        Print tasks in a table with tags.
			  -t, --tasks KEY    Include KEY tasks along with DONE tasks.
			                     Values for KEY are listed below.
			  -x, --exclude TAG  Only show tasks without the tag TAG.
			KEY can be one or more of:
			  d   DONE tasks.
			  g   GOAL tasks.
			  n   NEXT tasks.
			  t   TODO tasks.
			  w   WORK tasks."
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Only include requested items that aren't empty.
		set -l lists
		test -n "$_done"; and set -a lists _done
		test -n "$_comp"; and set -a lists _comp
		if set -q _flag_t
			set -l keys (string split '' $_flag_i)
			for k in $keys 
				switch $k
				case n 
					test -n "$_nope"; and set -a lists _nope
				end
			end
		end

		# Set the amount of padding for printing the line number.
		set -l digits 1

		# If we're focused on a specific goal, add that goal to the main item list.
		set -l itemlist
		if set -q _flag_g
			for g in $_goal $_comp
				set -l goal (string split '\r' $g)
				set -l name (string split ':' $goal[2])[2]
				if test "$name" = "$_flag_g"
					set -a itemlist $g
					break
				end
			end
		end

		# Gather all of the items that match the indicated criteria.
		set -l items
		set -l datelessitems
		for list in $lists
			for l in $$list
				set -l item (string split '\r' $l)

				# If we're focused on a specific goal, ignore tasks for other
				# goals.
				if set -q _flag_g
					_todo:_tag_filter "^$_flag_g" "$item[4]"; or continue
				end

				# Filter by tag.
				if set -q _flag_i
					_todo:_tag_filter "$_flag_i" "$item[4]"; or continue
				end

				# Filter by excluded tag.
				if set -q _flag_x
					_todo:_tag_filter -x "$_flag_x" "$item[4]"; or continue
				end

				# Set the number of digits in the largest line number.
				set -l d (string length $item[1])
				test $d -gt $digits; and set digits $d

				# Look for a done date in the tags.
				set -e founddate 
				for t in $item[4]
					if set priority (string split '~' $t)[2]
						set -l newitem $priority
						set -a newitem $item 
						set -a items (string join '\r' $newitem)
						set founddate
						break
					end
				end
				if not set -q founddate
					set -a datelessitems (string join '\r' $item)
				end
			end
		end

		# Determine the sort order
		if set -q _flag_r
			set sortcmd sort
		else
			set sortcmd sort -r
		end

		# Sort the priority items and add them to the item list.
		set -l sorteditems (printf "%s\n" $items | $sortcmd)
		for item in $sorteditems
			# Cut the priority field from the item and save it in itemlist.
			set -a itemlist (string join '\r' (string split '\r' $item)[2..])
		end

		if test -n "$datelessitems"
			set -a itemlist " "
			set -a itemlist $datelessitems
		end

		if test (count $itemlist) -eq 0
			echo "No history."
			return
		end

		_todo:_print_items $_flag_T -d $digits $itemlist
	end


	# Prints a list containing these elements:
	#   Line number
	#   Keyword (with optional alias)
	#   Task description
	#   Tags if they exist
	# for each task in the file. So for any element n, if (n-1) mod 4 = 0 it's
	# a line number or if (n-1) mod 4 = 1 it's a keyword (WORK, TODO, DONE,
	# etc.), or if (n-1) mod 4 = 2 it's a a task description, or finally if
	# (n-1) mod 4 = 3 it's a set of tags.
	function _todo:_load_items_new
		set -l opts 
		set -a opts "F/file="
		set -a opts "p/prefix="
		argparse -n "_load_tasks" $opts -- $argv
		or return

		set -l filename (select "$_flag_F" "WORK.txt")
		set -l prefix "[[:blank:]]*"(select "$_flag_p" "")"[[:blank:]]*"
		set -l keywords "GOAL"
		set -a keywords "DONE"
		set -a keywords "WORK"
		set -a keywords "TODO"
		set -a keywords "NEXT"
		set -a keywords "COMP"
		set -a keywords "XXXX"
		set -l keywords (string join "|" $keywords)

		# Who doesn't love sed?
		set -l sedcmd "/^$prefix($keywords)/{
			=
			s/^$prefix([[:alnum:]]+#{0,1}[[:alnum:]]*:{0,1}[[:alnum:]]*)[[:blank:]]+\[(.*)\][[:blank:]]+(.*)/\1"\\\n"\3"\\\n"\2/p
			t
			s/^$prefix([[:alnum:]]+#{0,1}[[:alnum:]]*:{0,1}[[:alnum:]]*)[[:blank:]]+(.*)/\1"\\\n"\2"\\\n"/p
			}"
		set rawitems (sed -E -n -e "$sedcmd" $filename); or return

		for i in (seq 1 4 (count $rawitems))
			set -l r $rawitems[$i..(math $i + 3)]
			set -l item (string join '\r' $r)
			set -a _allitems $item
		end
		# set _allitems (sed -E -n -e "$sedcmd" $filename); or return

		# Put each item in the appropriate list.
		for item in $_allitems
			# set -l item $_allitems[$i..(math $i + 3)]
			set -l itemlist (string split '\r' $item)

			# If there are no tags and an empty space.
			test -z "$itemlist[4]"; and set itemlist[4] " "

			switch (echo $itemlist[2])
			case WORK
				set -a _work $item
			case NEXT
				set -a _next $item
			case TODO 'TODO#*'
				set -a _todo $item
			case DONE 'DONE:*'
				set -a _done $item
			case GOAL 'GOAL:*' 'GOAL#*'
				set -a _goal $item
			case COMP 'COMP:*' 'COMP#*'
				set -a _comp $item
			end
		end
	end


	function _todo:list 
		set -l opts 
		set -a opts "w/no-work"
		set -a opts "t/task="
		set -a opts "F/file="
		set -a opts "p/prefix="
		set -a opts "f/filter=+"
		set -a opts "T/table"
		set -a opts "x/exclue=+"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List tasks. By default only WORK and NEXT tasks are shown." \
			--opt_help "
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -i, --include TAG  Only show tasks with the tag TAG.
			  -x, --exclude TAG  Only show tasks without the tag TAG.
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -t, --tasks KEY    Include KEY tasks along with DONE tasks. Values for KEY are listed below.
			  -T, --table        Print tasks in a table with tags.
			KEY can be one or more of:
			  c   COMP tasks.
			  d   DONE tasks.
			  g   GOAL tasks.
			  n   NEXT tasks.
			  t   TODO tasks.
			  w   WORK tasks."
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Only include requested items that aren't empty.
		set -l lists
		# test -n "$_done"; and set -a lists _done
		if set -q _flag_t
			set -l keys (string split '' $_flag_t)
			for k in $keys
				switch (echo $k)
				case c
					test -n "$_comp"; and set -a lists _comp
				case d
					test -n "$_done"; and set -a lists _done
				case g
					test -n "$_goal"; and set -a lists _goal
				case n 
					test -n "$_next"; and set -a lists _next
				case t
					test -n "$_todo"; and set -a lists _todo
				case w
					test -n "$_work"; and set -a lists _work
				case '*'
					echo "error: unrecognized KEY $k"
					return 1
				end
			end
		end

		# If nothing was specified, default to printing just the _work and
		# _next lists.
		test -z "$lists"; and set lists _work _next

		# Set the amount of padding for printing the line number.
		set -l digits 1

		# Gather all of the items that match the indicated criteria.
		set -l items
		for list in $lists
			for l in $$list
				set -l item (string split '\r' $l)

				# Filter by tag.
				if set -q _flag_f
					_todo:_tag_filter "$_flag_f" "$item[4]"; or continue
				end

				# Filter by excluded tag.
				if set -q _flag_x
					_todo:_tag_filter -x "$_flag_x" "$item[4]"; or continue
				end

				# Set the number of digits in the largest line number.
				set -l d (string length $item[1])
				test $d -gt $digits; and set digits $d

				set -a items (string join '\r' $item)
			end
		end

		if test (count $items) -eq 0
			echo "No tasks selected."
			return
		end

		_todo:_print_items $_flag_T -d $digits $items
	end


	function _todo:_print_items
		argparse -n "_print_items" "T/table" "d/digits=" -- $argv
		or return

		set -l digits (select $_flag_d 3)
		set -l items $argv

		# Format the items.
		set -l lnumfmt "$digits"s
		set -l out
		for i in $items
			set -l item (string split '\r' $i)

			test -z "$item[4]"; and set item[4] " "

			if test "$item[1]" = x
				set -a out "$item[2]"
				continue
			end

			if set -q _flag_T
				set -a out (printf "%$lnumfmt %s◊%s◊%s\n" "$item[1]" "$item[2]" "$item[4]" "$item[3]")
			else
				set -a out (printf "%$lnumfmt %s◊◊%s\n" "$item[1]" "$item[2]" "$item[3]")
			end
		end
		# Print the items.
		printf "%s\n" $out | column -t -s '◊'
	end


	function _todo:plan
		set -l opts 
		set -a opts "a/all"
		set -a opts "w/no-work"
		set -a opts "t/no-todo"
		set -a opts "d/done"
		set -a opts "n/no-next"
		set -a opts "F/file="
		set -a opts "p/prefix="
		set -a opts "f/filter="
		set -a opts "T/table"
		set -a opts "g/goal="
		set -a opts "l#limit"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "Plan tasks." \
			--opt_help "
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -d, --done         Include completed tasks.
			  -t, --no-todo      Don't include TODO tasks.
			  -w, --no-work      Don't include WORK tasks.
			  -n, --no-next      Don't include NEXT tasks.
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -T, --table        Print tasks in a table with tags.
			  -l, --limit NUM    Don't print more then NUM TODO tasks
			  -a, --all          Show all TODOs even those without a goal.
			  -g, --goal GOAL    Only print tasks tagged with goal GOAL."
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Get prioritized goals
		set -l goals
		set -l prioritygoals
		set -l regulargoals
		for g in $_goal
			set -l goal (string split '\r' $g)
			string match -qr '^GOAL#{0,1}(?<priority>\w*):{0,1}(?<alias>\w*)' $goal[2]
			if test -n "$priority"
				set -a prioritygoals (string join '\r' $priority $goal)
			else
				set -a regulargoals (string join '\r' $goal)
			end
		end

		# Sort the priority items and add them to the goal list.
		set -l sortedgoals (printf "%s\n" $prioritygoals | sort -n)
		for item in $sortedgoals
			# Cut the priority field from the item and save it in itemlist.
			set -a goals (string join '\r' (string split '\r' $item)[2..])
		end

		for item in $regulargoals
			set -a goals $item
		end

		# Gather all of the items that match the indicated criteria.
		set -l items
		for g in $goals
			set -l goal (string split '\r' $g)
			set -l alias (string split ':' $goal[2])[2]

			# If we're focused on a specific goal, ignore other goals.
			if set -q _flag_g
				test "$alias" = "$_flag_g"; or continue
			end

			# Add the goal to the items list.
			set -a items (string join '\r' $goal)

			set -l mainlists
			set -q _flag_w; or set -a mainlists _work
			set -q _flag_n; or set -a mainlists _next
			set -q _flag_t; or set -a mainlists _todo

			for list in $mainlists
				set -l priorityitems
				set -l regularitems
				set -l itemcount 1
				for t in $$list
					set -l item (string split '\r' $t)
					set -l tags (select (string split ' ' $item[4]) " ")

					# Add the item to the items list if it is associated with
					# the goal alias.
					# contains -- "^$alias" $tags; or continue
					_todo:_tag_filter "^$alias" "$item[4]"; or continue

					# Filter by tag.
					if set -q _flag_f
						_todo:_tag_filter "$_flag_f" "$item[4]"; or continue
					end

					# Filter by excluded tag.
					if set -q _flag_x
						_todo:_tag_filter -x "$_flag_x" "$item[4]"; or continue
					end

					if set priority (string split '#' $item[2])[2]
						set -l newitem $priority
						set -a newitem $item 
						set -a priorityitems (string join '\r' $newitem)
					else
						set -a regularitems (string join '\r' $item)
					end
				end

				set -l itemlist

				# Sort the priority items and add them to the item list.
				set -l sorteditems (printf "%s\n" $priorityitems | sort)
				for item in $sorteditems
					# Cut the priority field from the item and save it in itemlist.
					set -a itemlist (string join '\r' (string split '\r' $item)[2..])
				end

				# Add the regular items to the item list.
				for item in $regularitems
					set -a itemlist $item
				end

				# Add the item list to the master list of items, honoring the
				# todo limit if set.
				if set -q _flag_l; and test "$list" = "_todo"
					set -a items (string join '\r' (string split '\r' $itemlist[1..$_flag_l]))
				else
					set -a items $itemlist
				end
			end

			set -a items (string join '\r' " " " " " " " ")
		end

		# Gather tasks with no goal if asked.
		set -l extratasks
		if set -q _flag_a
			for t in $_work $_next $_todo
				set -l task (string split '\r' $t)
				string match -q "*^*" "$task[4]"; and continue
				set -a extratasks $t
			end
		end

		# Add any tasks with no goal.
		if test -n "$extratasks"
			set -a items "x\rOrphaned\r\r"
			set -a items $extratasks
		end

		# Set the amount of padding for printing the line number.
		set -l digits 1
		for i in $items 
			set -l item (string split '\r' $i)
			set -l d (string length $item[1])
			test $d -gt $digits; and set digits $d
		end

		_todo:_print_items $_flag_T -d $digits $items
	end


	function _todo:_tag_filter
		argparse -n "_tag_filter" "x/exclude" -- $argv

		set -l filter (string split ' ' $argv[1])
		set -l tags   (string split ' ' $argv[2])
		set -l out

		# Filter by tag.
		set -le tagged
		for f in $filter
			if contains -- "$f" $tags
				set tagged
				break
			end
		end

		if set -q _flag_x
			set -q tagged; and return 1
		else
			set -q tagged; or return 1
		end
		return 0
	end


	function _todo:tags
		set -l opts 
		set -a opts "F/file="
		set -a opts "m/minimal"
		set -a opts "X/exclude="
		set -a opts "x/ignore-special"
		set -a opts "o/only-special"
		argparse -n "$_cmdpath" -x x,o -x X,o $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List the task tags and their counts." \
			--opt_help "
			  -m, --minimal         List only the tags.
			  -o, --only-special    List only the special tags.
			  -X, --exclude CHARS   Remove tags that begin with any of CHARS.
			  -x, --ignore-special  Ignore known special tags ($specialtags)"
		or return

		set -l filename (select "$_flag_F" "WORK.txt")
		set -l prefix "[[:blank:]]*"(select "$_flag_p" "")"[[:blank:]]*"
		set -l keywords
		set -q _flag_d; and set -a keywords "DONE"
		set -q _flag_w; or set -a keywords "WORK"
		set -q _flag_t; or set -a keywords "TODO"
		set -q _flag_n; or set -a keywords "NEXT"
		set -l keywords (string join "|" $keywords)

		# Select the task lines from the target file.
		set -l sedcmd "/^$prefix($keywords)/p"
		set -l recs (sed -E -n -e "$sedcmd" $filename)
		if test -z "$recs"
			echo "No tasks found in $filename"
			return 0
		end

		set -q _flag_X; and set _flag_X (string split '' "$_flag_X")
		set -q _flag_x; and set -a _flag_X $specialtags

		# Add tags to the taglist.
		set -l taglist
		for text in $recs
			# Separate tags from the task description.
			string match -qr -- "^$prefix\w+\W+\[(?<tags>.*)\]\W+(?<task>.+)" $text
			if test -n "$tags"
				# Are there excluded characters?
				if set -q _flag_X
					for t in (string split ' ' $tags)
						contains -- (string sub -l 1 -- $t) $_flag_X
						or set -a taglist $t 
					end
				else if set -q _flag_o
					# Do we only print special tags?
					for t in (string split ' ' $tags)
						contains -- (string sub -l 1 -- $t) $specialtags
						and set -a taglist $t
					end
				else
					# No excluded characters; add all of the tags.
					set -a taglist (string split ' ' $tags)
				end
			end
		end

		# Print just the tags (m/minimal) or include the tag counts?
		if set -q _flag_m
			printf "%s\n" $taglist | sort | uniq
		else
			printf "%s\n" $taglist | sort | uniq -c
		end
	end


	exec_command_path \
		--root_cmd "todo" \
		-- $argv
end