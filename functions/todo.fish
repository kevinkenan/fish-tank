function todo
	set -gx _allitems
	set -gx _goal
	set -gx _work
	set -gx _next
	set -gx _todo
	set -gx _done
	set -gx _comp
	set -gx _xxxx
	set -x specialtags '@' '^' '~' '>'


	function _todo
		_cmd_register --no_opts \
			--help_text "Manage tasks embedded in a file."
		or return
	end


	function _todo:history:basic
		set -l opts 
		set -a opts "c/canceled"
		set -a opts "D/date-table"
		set -a opts "F/file="
		set -a opts "f/filter="
		set -a opts "l#limit"
		set -a opts "p/prefix="
		set -a opts "r/reverse"
		set -a opts "T/table"
		argparse -n "$_cmdpath" -x D,T $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "Show a basic list of all DONE tasks sorted by completion date." \
			--opt_help "
			  -c, --canceled     Include XXXX tasks.
			  -D, --date-table   Print tasks in a table with the completion data.
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -l, --limit NUM    Don't print more then NUM tasks
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -r, --reverse      Reverse sort with oldest first.
			  -T, --table        Print tasks in a table with tags.
			  "
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Place the task in $items or $datelessitems based on the
		# existence of a completion date.
		set -l dateditems
		set -l datelessitems
		for item_ in $_done $_comp (set -q _flag_c; and printf "%s\n" $_xxxx)
			set -l item (string split '\r' $item_)
			set -e founddate 
			for tag in $item[4]
				# Look through all of the tags for one that begins with '~'.
				if set date (string split '~' $tag)
					set -l newitem $date[2]
					set -a newitem $item 
					set -a dateditems (string join '\r' $newitem)
					set founddate
					break
				end
			end
			if not set -q founddate
				set -a datelessitems (string join '\r' $item)
			end
		end

		set -l itemlist

		# Determine the sort order
		if set -q _flag_r
			set sortcmd sort -s -k1n 
		else
			set sortcmd sort -s -k1,1rn
		end

		# Sort the dated items and add them to the item list.
		set -l sorteditems (printf "%s\n" $dateditems | $sortcmd); or return

		# Cut the date field from the item and save the item in itemlist.
		for item in $sorteditems
			set -a itemlist (string join '\r' (string split '\r' $item)[2..])
		end

		# Add the dateless items
		set -a itemlist $datelessitems

		# Set the amount of padding for printing the line number.
		set -l digits 1
		for i in $itemlist
			set -l item (string split '\r' $i)
			set -l d (string length $item[1])
			test $d -gt $digits; and set digits $d
		end

		if set -q _flag_l
			_todo:_print_items $_flag_D $_flag_T -d $digits $itemlist[1..$_flag_l]
		else
			_todo:_print_items $_flag_D $_flag_T -d $digits $itemlist
		end
	end


	function _todo:history:goals
		set -l opts 
		set -a opts "a/all"
		set -a opts "c/canceled"
		set -a opts "D/date-table"
		set -a opts "F/file="
		set -a opts "f/filter="
		set -a opts "g/goal=+"
		set -a opts "l#limit"
		set -a opts "p/prefix="
		set -a opts "r/reverse"
		set -a opts "T/table"
		argparse -n "$_cmdpath" -x D,T $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "Show completed tasks grouped by goal." \
			--opt_help "
			  -a, --all          Show all completed tasks, even those without a goal.
			  -c, --canceled     Include XXXX tasks.
			  -D, --date-table   Print tasks in a table with the completion data.
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -g, --goal GOAL    Only print tasks tagged with goal GOAL.
			  -l, --limit NUM    Don't print more then NUM tasks
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -r, --reverse      Reverse sort with oldest first.
			  -T, --table        Print tasks in a table with tags.
			  "
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
		for g in $_goal $_comp
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

		# For each goal, gather all of its DONE items and sort them by
		# completion date.
		set -l items
		for g in $goals
			set -l goal (string split '\r' $g)
			set -l alias (string split ':' $goal[2])[2]

			# If we're focused on specific goals, ignore other goals.
			if set -q _flag_g
				contains "$alias" $_flag_g; or continue
			end

			# Gather all of the completed tasks for the current goal. Tasks
			# with completion dates are placed into the $dateditems list.
			# Tasks without completion dates are placed into the
			# $datelessitems list.
			set -l dateditems
			set -l datelessitems
			for item_ in $_done (set -q _flag_c; and printf "%s\n" $_xxxx)
				set -l item (string split '\r' $item_)
				set -l tags (select (string split ' ' $item[4]) " ")

				# Add the item to the items list if it is associated with
				# the goal alias.
				_todo:_tag_filter "^$alias" "$item[4]"; or continue

				# Filter by tag.
				if set -q _flag_f
					_todo:_tag_filter "$_flag_f" "$item[4]"; or continue
				end

				# Filter by excluded tag.
				if set -q _flag_x
					_todo:_tag_filter -x "$_flag_x" "$item[4]"; or continue
				end

				# Place the task in $items or $datelessitems based on the
				# existence of a completion date.
				set -e founddate 
				for t in $item[4]
					# Look through all of the tags for one that begins with 
					# '~'.
					if set date (string split '~' $t)[2]
						set -l newitem $date
						set -a newitem $item 
						set -a dateditems (string join '\r' $newitem)
						set founddate
						break
					end
				end
				if not set -q founddate
					set -a datelessitems (string join '\r' $item)
				end
			end

			set -l itemlist

			# Determine the sort order
			if set -q _flag_r
				set sortcmd sort -s
			else
				set sortcmd sort -s -k1,1r
			end

			# Sort the dated items and add them to the item list.
			set -l sorteditems (printf "%s\n" $dateditems | $sortcmd)
			for item in $sorteditems
				# Cut the date field from the item and save the time in itemlist.
				set -a itemlist (string join '\r' (string split '\r' $item)[2..])
			end

			# Add the dateless items to the item list.
			for item in $regularitems
				set -a itemlist $item
			end

			set -l itemlist (_todo:_tag_sorter --date '~' )

			# Skip in progress goals that don't have DONE tasks. However,
			# we do want to keep completed goals (COMP) that have no
			# completed child tasks.
			set -l key (string split ':' $goal[2])[1]
			test -z "$itemlist" -a "$key" != "COMP"; and continue

			# Add the goal to the items list.
			set -a items (string join '\r' $goal)

			# Add the item list to the master list of items, honoring the
			# item limit if set.
			if set -q _flag_l; 
				set -a items (string join '\r' (string split '\r' $itemlist[1..$_flag_l]))
			else
				# test -z "$itemlist"; and continue
				set -a items $itemlist
			end

			set -a items $datelessitems
			set -a items (string join '\r' " " " " " " " ")
		end

		# Set the amount of padding for printing the line number.
		set -l digits 1
		for i in $items 
			set -l item (string split '\r' $i)
			set -l d (string length $item[1])
			test $d -gt $digits; and set digits $d
		end

		_todo:_print_items $_flag_D $_flag_T -d $digits $items

		# Gather tasks with no goal if asked.
		set -l extratasks
		if set -q _flag_a
			for t in $_done
				set -l task (string split '\r' $t)
				string match -q "*^*" "$task[4]"; and continue
				set -a extratasks $t
			end
		end

		# Print tasks with no goal
		if test -n "$extratasks"
			echo "Done items with no assigned goal."

			set items (_todo:_tag_sorter --date '~' $extratasks); or return

			# Set the amount of padding for printing the line number.
			set -l digits 1
			for i in $items 
				set -l item (string split '\r' $i)
				set -l d (string length $item[1])
				test $d -gt $digits; and set digits $d
			end

			_todo:_print_items $_flag_D $_flag_T -d $digits $items
		end
	end


	function _todo:list 
		set -l opts 
		set -a opts "a/all"
		set -a opts "F/file="
		set -a opts "f/filter=+"
		set -a opts "l#limit"
		set -a opts "p/prefix="
		set -a opts "T/table"
		set -a opts "t/task="
		set -a opts "w/no-work"
		set -a opts "x/exclue=+"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List tasks. By default only WORK and NEXT tasks are shown." \
			--opt_help "
			  -a, --all          List all tasks.
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -i, --include TAG  Only show tasks with the tag TAG.
			  -l, --limit NUM    Don't print more then NUM tasks
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -T, --table        Print tasks in a table with tags.
			  -t, --tasks KEY    Include KEY tasks along with DONE tasks. Values for KEY are listed below.
			  -x, --exclude TAG  Only show tasks without the tag TAG.
			KEY can be one or more of:
			  c   COMP tasks.
			  d   DONE tasks.
			  g   GOAL tasks.
			  n   NEXT tasks.
			  t   TODO tasks.
			  w   WORK tasks.
			  x   XXXX tasks."
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		if set -q _flag_a
			set _flag_t "wntgdcx"
		end

		# Only include requested items that aren't empty.
		set -l lists
		if set -q _flag_t
			set -l keys (string split '' $_flag_t)
			for k in $keys
				switch (echo $k)
				case w
					test -n "$_work"; and set -a lists _work
				case n 
					test -n "$_next"; and set -a lists _next
				case t
					test -n "$_todo"; and set -a lists _todo
				case g
					test -n "$_goal"; and set -a lists _goal
				case d
					test -n "$_done"; and set -a lists _done
				case c
					test -n "$_comp"; and set -a lists _comp
				case x
					test -n "$_xxxx"; and set -a lists _xxxx
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

		set -l last (select "$_flag_l" -1)
		_todo:_print_items $_flag_T -d $digits $items[1..$last]
	end

	function _todo:orphans
		set -l opts 
		set -a opts "F/file="
		set -a opts "p/prefix="
		set -a opts "f/filter="
		set -a opts "T/table"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List tasks that reference non-existing goals." \
			--opt_help "
			  -F, --file FILE    Look in FILE for tasks instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -p, --prefix PRE   The GOAL keyword is preceded by the prefix PRE.
			  -T, --table        Print tasks in a table with tags."
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Add goal references to the goallist.
		set -l goallist
		for item_ in $_allitems
			set -l item (string split '\r' $item_)
			set -l tags $item[4]

			for tag in (string split ' ' $tags)
				# Ignore blank tags
				test -z "$tag"; and continue

				# Add goals.
				if string match -q "^*" $tag
					set -a goallist (string join '\r' (string sub -s 2 $tag) $item[1])
				end
			end
		end

		set -l knowngoals
		for g in $_goal $_comp $_xxxx
			set -l item (string split '\r' $g)
			set -l goal (string split ':' $item[2])[2]
			test -z "$goal"; and continue
			set -a knowngoals $goal
		end

		set -l orphans
		for g_ in $goallist
			set -l g (string split '\r' $g_)
			if not contains $g[1] $knowngoals
				set -a orphans (string join '\r' $g[2] $g[1])
			end
		end

		# Set the amount of padding for printing the line number.
		set -l digits 1
		for i in $orphans 
			set -l item (string split '\r' $i)
			set -l d (string length $item[1])
			test $d -gt $digits; and set digits $d
		end

		_todo:_print_items $_flag_D $_flag_T -d $digits $orphans
	end


	function _todo:plan
		set -l opts 
		set -a opts "a/all"
		set -a opts "d/done"
		set -a opts "F/file="
		set -a opts "f/filter="
		set -a opts "g/goal="
		set -a opts "l#limit"
		set -a opts "n/no-next"
		set -a opts "p/prefix="
		set -a opts "t/no-todo"
		set -a opts "T/table"
		set -a opts "w/no-work"
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "Plan tasks." \
			--opt_help "
			  -a, --attached     Only print tasks attached to a goal.
			  -d, --done         Include completed tasks.
			  -F, --file FILE    Look in FILE for todos instead of WORK.txt.
			  -f, --filter TAG   Only show tasks with the tag TAG.
			  -g, --goal GOAL    Only print tasks tagged with goal GOAL.
			  -l, --limit NUM    Don't print more then NUM TODO tasks
			  -n, --no-next      Don't include NEXT tasks.
			  -p, --prefix PRE   Keywords will have PRE prepended.
			  -t, --no-todo      Don't include TODO tasks.
			  -T, --table        Print tasks in a table with tags.
			  -w, --no-work      Don't include WORK tasks.
			  "
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Get prioritized goals
		set -l goals
		set -l dateditems
		set -l datelessitems

		# Place the task in $items or $datelessitems based on the
		# existence of a completion date.
		for g in $_goal
			set -l goal (string split '\r' $g)
			set -e founddate 
			for t in $goal[4]
				# Look through all of the tags for one that begins with 
				# '~'.
				if set date (string split '@' $t)[2]
					set -l newitem $date
					set -a newitem $goal 
					set -a dateditems (string join '\r' $newitem)
					set founddate
					break
				end
			end
			if not set -q founddate
				set -a datelessitems (string join '\r' $goal)
			end
		end

		# Sort the dated items and add them to the item list.
		set -l sorteditems (printf "%s\n" $dateditems | sort -s -k1,1n)
		for item in $sorteditems
			# Cut the priority field from the item and save it in itemlist.
			set -a goals (string join '\r' (string split '\r' $item)[2..])
		end

		# Add the dateless items to the item list.
		for item in $datelessitems
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
				set -l dateditems
				set -l datelessitems

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

					# Place the task in $items or $datelessitems based on the
					# existence of a completion date.
					set -e founddate 
					for t in $item[4]
						# Look through all of the tags for one that begins with 
						# '~'.
						if set date (string split '@' $t)[2]
							set -l newitem $date
							set -a newitem $item 
							set -a dateditems (string join '\r' $newitem)
							set founddate
							break
						end
					end
					if not set -q founddate
						set -a datelessitems (string join '\r' $item)
					end

				end

				set -l itemlist

				# Sort the dated items and add them to the item list.
				set -l sorteditems (printf "%s\n" $dateditems | sort -s -k1,1n)
				for item in $sorteditems
					# Cut the priority field from the item and save it in itemlist.
					set -a itemlist (string join '\r' (string split '\r' $item)[2..])
				end

				# Add the dateless items to the item list.
				for item in $datelessitems
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

		# Set the amount of padding for printing the line number.
		set -l digits 1
		for i in $items 
			set -l item (string split '\r' $i)
			set -l d (string length $item[1])
			test $d -gt $digits; and set digits $d
		end

		_todo:_print_items $_flag_T -d $digits $items

		# Print tasks with no goal unless asked to supress.
		if not set -q _flag_a
			set -l items
			set -l extratasks

			for t in $_work $_next $_todo
				set -l task (string split '\r' $t)
				string match -q "*^*" "$task[4]"; and continue
				set -a extratasks $t
			end

			set -l dateditems
			set -l datelessitems
			for task in $extratasks
				set -l item (string split '\r' $task)
				# Place the task in $items or $datelessitems based on the
				# existence of a completion date.
				set -e founddate 
				for t in $item[4]
					# Look through all of the tags for one that begins with 
					# '~'.
					if set date (string split '@' $t)[2]
						set -l newitem $date
						set -a newitem $item 
						set -a dateditems (string join '\r' $newitem)
						set founddate
						break
					end
				end
				if not set -q founddate
					set -a datelessitems (string join '\r' $item)
				end
			end

			set -l itemlist

			# Sort the dated items and add them to the item list.
			set -l sorteditems (printf "%s\n" $dateditems | sort -s -k1,1n)
			for item in $sorteditems
				# Cut the priority field from the item and save it in itemlist.
				set -a itemlist (string join '\r' (string split '\r' $item)[2..])
			end

			# Add the dateless items to the item list.
			for item in $datelessitems
				set -a itemlist $item
			end

			# Add the item list to the master list of items, honoring the
			# todo limit if set.
			if set -q _flag_l; and test "$list" = "_todo"
				set -a items (string join '\r' (string split '\r' $itemlist[1..$_flag_l]))
			else
				set -a items $itemlist
			end

			if test -n "$items"
				printf "%s\n" "### Tasks unattached to any goal:"
				_todo:_print_items $_flag_T -d $digits $items
			end
		end
	end


	function _todo:tags
		set -l opts 
		set -a opts "F/file="
		set -a opts "m/minimal"
		set -a opts "s/include-special"
		set -a opts "S/only-special"
		set -a opts "x/exclude="
		argparse -n "$_cmdpath" $opts -- $_args
		or return

		_cmd_register --action \
			--help_text "List the task tags and their counts." \
			--opt_help "
			  -m, --minimal          List only the tags.
			  -s, --include-special  Include known special tags ($specialtags)
			  -S, --only-special     List only the special tags.
			  -x, --exclude TAG      Remove tag TAG.
			  "
		or return

		# Set the module variable _allitems.
		_todo:_load_items_new --file "$_flag_F" --prefix "$_flag_p"

		if test -z "$_allitems"
			echo "No tasks found in $filename"
			return 0
		end

		# Set the tag exclusion list.
		set -q _flag_x; and set -l exclude (string split ',' "$_flag_x")

		# Add tags to the taglist.
		set -l taglist
		for item_ in $_allitems
			set -l item (string split '\r' $item_)
			set -l tags $item[4]

			# Separate tags from the task description.
			# string match -qr -- "^$prefix\w+\W+\[(?<tags>.*)\]\W+(?<task>.+)" $text

			for tag in (string split ' ' $tags)
				# Ignore blank tags
				test -z "$tag"; and continue

				if set -q _flag_S
					# Only include special tags.
					not contains -- (string sub -l 1 -- $tag) $specialtags
					and continue
				else
					# Ignore special tags unless asked to include them.
					contains -- (string sub -l 1 -- $tag) $specialtags; and not set -q _flag_s
					and continue
				end

				# Ignore excluded tags
				contains -- "$tag" $exclude
				and continue

				# Add the tag to the taglist.
				set -a taglist $tag
			end
		end

		test -z "$taglist"; and return

		# Print just the tags (m/minimal) or include the tag counts?
		if set -q _flag_m
			printf "%s\n" $taglist | sort -n | uniq 
		else
			printf "%s\n" $taglist | sort -n | uniq -c 
		end
	end

### UTILITY FUNCTIONS ---------------------------------------------------------

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
			case XXXX 'XXXX:*' 'XXXX#*'
				set -a _xxxx $item
			end
		end
	end


	function _todo:_print_items
		set -l opts 
		set -a opts "T/table" 
		set -a opts "d/digits="
		set -a opts "D/date"
		argparse -n "_print_items" -x D,T $opts -- $argv
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
			else if set -q _flag_D
				string match -qr '(?<date>~\d{6})' "$item[4]"; or set date " "
				set -a out (printf "%$lnumfmt %s◊%s◊%s\n" "$item[1]" "$item[2]" "$date" "$item[3]")
			else
				set -a out (printf "%$lnumfmt %s◊◊%s\n" "$item[1]" "$item[2]" "$item[3]")
			end
		end
		# Print the items.
		printf "%s\n" $out | column -t -s '◊'
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


	# Sort one of the item lists by a completions date tag. Items with no
	# completion date are listed at the end.
	function _todo:_tag_sorter
		set -l opts 
		set -a opts "D/date="
		set -a opts "r/reverse"
		argparse -n "_tag_sorter" $opts -- $argv
		or return

		set -l datechar (select "$_flag_D" "~")
		set -l unsorted $argv

		# Place the task in $items or $datelessitems based on the
		# existence of a completion date.
		set -l dateditems
		set -l datelessitems
		for item_ in $unsorted
			set -l item (string split '\r' $item_)
			set -e founddate 
			for tag in $item[4]
				# Look through all of the tags for one that begins with the sortkey.
				if set sortkey (string split $datechar $tag)[2]
					set -l newitem $sortkey
					set -a newitem $item 
					set -a dateditems (string join '\r' $newitem)
					set founddate
					break
				end
			end
			if not set -q founddate
				set -a datelessitems (string join '\r' $item)
			end
		end

		set -l itemlist

		# Determine the sort order
		if set -q _flag_r
			set sortcmd sort -k1n -k2n
		else
			set sortcmd sort -k1rn -k2rn
		end

		# Sort the dated items and add them to the item list.
		set -l sorteditems (printf "%s\n" $dateditems | $sortcmd); or return
		for item in $sorteditems
			# Cut the date field from the item and save the item in itemlist.
			set -a itemlist (string join '\r' (string split '\r' $item)[2..])
		end

		set -a itemlist $datelessitems

		printf "%s\n" $itemlist
	end


	exec_command_path \
		--root_cmd "todo" \
		-- $argv
end