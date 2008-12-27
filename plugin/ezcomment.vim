" ezcomment.vim		Vim global plugin for manipulating comments
" Last Change:		2008.06.09
" Maintaner:		Mike Richman <mike.d.richman@gmail.com>
" License:		This file is placed in the public domain.

" TODO: {{{
" Clean up some messy code.
" Check spacing better.
" Try to use <plug> to avoid exposing g:EZCom_comment_object.
" Support GetLatestVimScripts.
" Possibly cope with nested comments in C-like code.
" }}}

" Section: Script init {{{
" Section: Compatibility {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}
" Section: Multiple sourcing check {{{
if exists ("loaded_mdr_commenter")
	finish
endif
let loaded_mdr_commenter = 1
" }}}
" Section: Global defaults {{{
" If the user has set global defaults, we do not want to stomp them.
if !exists ('g:EZCom_map_leader')
	let g:EZCom_map_leader = 'gc'
endif
if !exists ('g:EZCom_eol_pos')
	let g:EZCom_eol_pos = 80
endif
if !exists ('g:EZCom_trailing_comment_pos')
	let g:EZCom_trailing_comment_pos = 33
endif
if !exists ('g:EZCom_cpp_trailing_comment_pos')
	let g:EZCom_cpp_trailing_comment_pos = 9
endif
if !exists ('g:EZCom_space')
	let g:EZCom_space = ' '
endif
if !exists ('g:EZCom_linewise_style')
	let g:EZCom_linewise_style = 'eol'  " can be 'eol' or '$'
endif
" }}}
" Section: Set up per-buffer jobs, other initialization {{{
autocmd BufWinEnter * :call g:EZCom_refresh ()
let s:spaces = ""
while strlen (s:spaces) < 100
	let s:spaces = s:spaces . "     "
endwhile
" }}}
" }}}
" Section: Per-buffer setup {{{
" Function: s:filetype_setup {{{
" This function is responsible for setting up buffer scoped variables
" for the given filetype.
function s:filetype_setup ()
	let left = substitute (&commentstring, '\(.*\)%s.*', '\1', '')
	let right = substitute (&commentstring, '.*%s\(.*\)', '\1', 'g')
	let b:EZCom_left = left
	let b:EZCom_right = right
	if !exists ('b:EZCom_map_leader')
		let b:EZCom_map_leader = g:EZCom_map_leader
	endif
	if !exists ('b:EZCom_eol_pos')
		let b:EZCom_eol_pos = g:EZCom_eol_pos
	endif
	if !exists ('b:EZCom_trailing_comment_pos')
		let b:EZCom_trailing_comment_pos = g:EZCom_trailing_comment_pos
	endif
	if !exists ('b:EZCom_cpp_trailing_comment_pos')
		let b:EZCom_cpp_trailing_comment_pos
					\ = g:EZCom_cpp_trailing_comment_pos
	endif
	if !exists ('b:EZCom_space')
		let b:EZCom_space = g:EZCom_space
	endif
	if !exists ('b:EZCom_linewise_style')
		let b:EZCom_linewise_style = g:EZCom_linewise_style
	endif
	" If &commentstring includes the space, we don't want to add
	" additional spacing.
	let b:EZCom_left = substitute (b:EZCom_left, b:EZCom_space.'$', '', '')
	let b:EZCom_right= substitute (b:EZCom_right, b:EZCom_space.'$', '', '')
endfunction
" }}}
" }}}
" Section: Comment add/remove functions {{{
" Function: s:fstrlen (line) {{{
" This function returns the length of a string when tabs are counted
" as &sw spaces.
function s:fstrlen (line)
	let line = a:line
	let repl = strpart (s:spaces, 0, &sw)
	" replace the first tab with spaces till a tabstop
	while line =~ "\t"
		let line = substitute (line, "\t", " \t", '')
		while match (line, "\t", 0, 1) % &sw
			let line = substitute (line, "\t", " \t", '')
		endwhile
		let line = substitute (line, "\t", '', '')
	endwhile
	return strlen (line)
endfunction
" }}}
" Function: s:eol_spaces (line, ...) {{{
" This function returns line with tabs and/or spaces appended at the
" end until the line is at least b:EZCom_trailing_comment_pos long.
" Optionally, specify the length rather than using
" b:EZCom_trailing_comment_pos.  If b:EZCom_trailing_comment_pos is being used,
" and the line is a preprocessor #else or #endif, adjust so that there
" are only a couple trailing spaces.
function s:eol_spaces (line, ...)
	let line = a:line
	if a:0 == 1
		if b:EZCom_linewise_style == '$'
			return line
		endif
		let len = a:1 - 1
	elseif a:line =~ '#else\|#endif'
		let len = b:EZCom_cpp_trailing_comment_pos - 1
	else
		let len = b:EZCom_trailing_comment_pos - 1
	endif
	let not_using_tabs = &softtabstop
	let out = line
	if not_using_tabs
		while strlen (out) < len
			let out = out . ' '
		endwhile
	else
		while s:fstrlen (out) < len
			let out = out . "\t"
		endwhile
		let out = substitute (out, '\_s$', '', '')
		while s:fstrlen (out) < len
			let out = out . ' '
		endwhile
	endif
	if out !~ '\_s$'
		let out = out . b:EZCom_space . b:EZCom_space
	endif
	return out
endfunction
" }}}
" Function: s:clear_comment (line) {{{
" This function goes to the first comment on the line, clears it, and
" returns the resulting line.
function s:clear_comment (line)
	let line = a:line
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = bleft . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.bright : ''
	let pat = all_left . '.*' . all_right
	let repl = all_left . all_right
	let line = substitute (line, pat, repl, '')
	return line
endfunction
" }}}
" Function: s:jump_into_comment (n) {{{
" This function jumps into the nth comment on the line
function s:jump_into_comment (n)
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	exec ":normal =="
	let this_line = getline (".")
	let pat = bleft.b:EZCom_space
	let match_at = match (this_line, pat, 0, a:n)
	let pos = match_at + strlen (left) + strlen (b:EZCom_space) + 1
	call cursor (0, pos)
	if strlen (right) || pos < strlen (this_line)
		startinsert
	else
		startinsert!
	endif
endfunction
" }}}
" Function: s:write_line (line) {{{
" This function replaces the current cursor line with 'line'.
function s:write_line (line)
	let old_paste = &paste
	set paste
	exec ":normal cc".a:line
	let &paste = old_paste
endfunction
" }}}
" Function: s:EZCom_edit_comment (eol, clear) {{{
" This function ensures that a comment exists on the current line and
" places the cursor at the beginning of the comment.  If clear is
" true, the comment is cleared before entering insert mode.
"
" TODO: clean up this mess
function s:EZCom_edit_comment (clear)
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = left . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.right : ''
	" Determine whether we are editing a new or existing comment,
	" and act get the line's replacement
	let this_line = getline (".")
	let reverse = 0
	if this_line =~ bleft
		" add space in comment area if necessary (replace 0 or
		" 1 spaces with 2)
		if strlen(all_right)
			let pat = '\(.*\)' . bleft.bright . '\(.*\)'
			let repl = '\1' . all_left . all_right . '\2'
			let this_line = substitute (this_line, pat, repl, '')
			let pat = '\(.*\)'.bleft.b:EZCom_space.bright.'\(.*\)'
			let this_line = substitute (this_line, pat, repl, '')
		endif
	else
		" add spaces at end if necessary
		let this_line = s:eol_spaces (this_line)
		let this_line = this_line . all_left . all_right
	endif
	if a:clear
		let this_line = s:clear_comment (this_line)
	endif
	" replace the line, jump into comment and edit
	call s:write_line (this_line)
	if reverse
		exec ":normal =="
		exec ":normal k0"
	endif
	call s:jump_into_comment (1)
endfunction
" }}}
" Function: s:EZCom_comment_here (where, anoti) {{{
" This function creates a new comment at the cursor location and
" positions the cursor inside for editing.  If where is -1, the
" comment is on the previous line (like O).  If where is 1, the
" comment is on the next line (like O).  If where is 0 and anoti is
" true, the comment is exactly at the current location (like a).  If
" where is 0 and anoti is false, the comment is at the current
" location (like i).
function s:EZCom_comment_here (where, anoti)
	let where = a:where
	let anoti = a:anoti
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = left . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.right : ''
	let all = all_left . all_right
	let old_paste = &paste
	set paste
	if where == -1
		exec ":normal O" . all
	elseif where == 1
		exec ":normal o" . all
	elseif where == 0
		if anoti
			exec ":normal a" . all
		else
			exec ":normal i" . all
		endif
	endif
	let &paste = old_paste
	call s:jump_into_comment (1)
endfunction
" }}}
" Function: s:EZCom_comment_line {{{
" This function comments the current line.
function s:EZCom_comment_line ()
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = left . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.right : ''
	let len = b:EZCom_eol_pos - strlen (all_right)
	let this_line = getline ('.')
	if !(strlen (this_line) == 0 && b:EZCom_linewise_style == '$')
		if strlen (right)
			let this_line = s:eol_spaces (all_left.this_line, len)
			let this_line = this_line . all_right
		else
			let this_line = all_left.this_line
		endif
		" TODO: better check for bad spacing
		let this_line = substitute (this_line, ' \t', '\t', '')
		let column = col('.')
		call s:write_line (this_line)
		call cursor (0, column + strlen(all_left))
	endif
endfunction
" }}}
" Function: s:EZCom_uncomment_line {{{
" This function uncomments the (first comment in) current line, if it
" is already commented.
function s:EZCom_uncomment_line ()
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = left . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.right : ''
	let ball_left = escape (all_left, '*')
	let ball_right = escape (all_right, '*')
	let pat = ball_left . '\(.\{-}\)' . ball_right
	let repl = '\1'
	let this_line = getline ('.')
	let new_line = getline ('.')
	let new_line = substitute (new_line, pat, repl, '')
	let new_line = substitute (new_line, '\_s*$', '', '')
	if new_line == this_line
		let pat = bleft . '\(.\{-}\)' . bright
		let repl = '\1'
		let new_line = substitute (new_line, pat, repl, '')
		let new_line = substitute (new_line, '\_s*$', '', '')
	endif
	let this_line = new_line
	let column = col('.')
	call s:write_line (this_line)
	call cursor (0, column - strlen(all_left))
	exec ":normal =="
endfunction
" }}}
" Function: g:EZCom_comment_object (type, ...) {{{
" This function attempts to comment out arbitrary text objects.
" TODO: handle multiline charwise, and clean up this mess!
function g:EZCom_comment_object (type, ...)
	let left = b:EZCom_left
	let right = b:EZCom_right
	let bleft = escape (left, '*')
	let bright = escape (right, '*')
	let all_left = left . b:EZCom_space
	let all_right = strlen(right) ? b:EZCom_space.right : ''
	let old_line = line ('.')
	let old_col = col ('.')
	if a:type == 'char' || a:type ==# 'v'
		if a:0
			let bound_left = col ("'<")
			let bound_right = col("'>")
			let bound_top = line ("'<")
			let bound_bot = line ("'>")
		else
			let bound_left = col ("'[")
			let bound_right = col("']")
			let bound_top = line ("'[")
			let bound_bot = line ("']")
		endif
		if bound_top != bound_bot
			echohl WarningMsg
			echo "EZCom cannot yet handle multiline "
						\ . "character-wise operations "
						\ . "-- sorry! :("
			echo "(try a linewise operation instead)"
			echohl None
			return
		endif
		let this_line = getline ('.')
		let beg = strpart (this_line, 0, bound_left - 1)
		let mid = strpart (this_line, bound_left - 1,
				         \ bound_right - bound_left + 1)
		let end = strpart (this_line, bound_right)
		let mid = all_left . mid . all_right
		let this_line = beg . mid . end
		call s:write_line (this_line)
		let old_col = old_col + strlen (all_left)
	elseif a:type == 'line' || a:type ==# 'V'
		if a:0
			let first_line = line ("'<")
			let last_line = line ("'>")
		else
			let first_line = line ("'[")
			let last_line = line ("']")
		endif
		call cursor (first_line)
		call s:EZCom_comment_line ()
		if first_line != last_line
			while line ('.') != last_line
				exec ":normal j"
				call s:EZCom_comment_line ()
			endwhile 
		endif
	endif
	call cursor (old_line, old_col)
endfunction
" }}}
" Function: g:EZCom_uncomment_object (type, ...) {{{
" This function attempts to comment out arbitrary text objects.
function g:EZCom_uncomment_object (type, ...)
	let left = b:EZCom_left
	let all_left = left . b:EZCom_space
	let old_line = line ('.')
	let old_col = col ('.')
	let last_line = line ("']")
	if a:0
		let first_line = line ("'<")
		let last_line = line ("'>")
	else
		let first_line = line ("'[")
		let last_line = line ("']")
	endif
	call cursor (first_line)
	call s:EZCom_uncomment_line ()
	while line ('.') != last_line
		exec ":normal j"
		call s:EZCom_uncomment_line ()
	endwhile 
	call cursor (old_line, old_col + strlen (all_left))
endfunction
" }}}
" Section: Maps {{{
" Function: s:make_map (mode, map, name, call) {{{
" This function creates a map in the given mode ('op', 'n', or 'v')
" that executes 'call'.
function s:make_map (mode, map, name, call)
	if a:mode == 'op'
		exec ":nmap <silent> <buffer> ".b:EZCom_map_leader.a:map
					\ . " :call g:EZCom_refresh()<cr>"
					\ . ":set opfunc=".a:call."<cr>g@"
		exec ":vmap <silent> <buffer> ".b:EZCom_map_leader.a:map
					\ . " :\<c-u>call g:EZCom_refresh()<cr>"
					\ . ":\<c-u>call ".a:call
					\ . "(visualmode(),1)<cr>"
	elseif a:mode == 'n'
		let the_call = substitute (a:call, '^s:', '<sid>', '')
		exec "nnoremap <script> <buffer> <plug>EZCom".a:name
					\ . " <sid>".a:name
		exec "nnoremap <buffer> <sid>".a:name
					\ . " :call g:EZCom_refresh()<cr>"
					\ . ":call ".the_call."<cr>"
		exec "nmap <silent> <buffer> "
					\ . b:EZCom_map_leader.a:map
					\ . " <plug>EZCom".a:name
	elseif a:mode == 'v'
		let the_call = substitute (a:call, '^s:', '<sid>', '')
		exec "nnoremap <script> <buffer> <plug>EZCom".a:name
					\ . " <sid>".a:name
		exec "nnoremap <buffer> <sid>".a:name." :call ".the_call."<cr>"
		exec "nmap <silent> <buffer> "
					\ . b:EZCom_map_leader.a:map
					\ . " <plug>EZCom".a:name
	endif
endfunction
" }}}
" Function: s:map_setup {{{
" This function creates the plugin's mappings on a per buffer basis.
function s:map_setup ()
	" Commenting and uncommenting of code
	call s:make_map ('op', 'c', '_ComObject', 'g:EZCom_comment_object')
	call s:make_map ('op', 'uc', '_UnComObject','g:EZCom_uncomment_object')
	call s:make_map ('n', 'cal', '_ComALine', 's:EZCom_comment_line ()')
	call s:make_map ('n', 'ucal', '_UnComALine','s:EZCom_uncomment_line ()')

	" Insertion and editing of comments
	call s:make_map ('n', 'o', '_open', 's:EZCom_comment_here (1, 0)')
	call s:make_map ('n', 'O', '_Open', 's:EZCom_comment_here (-1, 0)')
	call s:make_map ('n', 'i', '_insert', 's:EZCom_comment_here (0, 0)')
	call s:make_map ('n', 'a', '_append', 's:EZCom_comment_here (0, 1)')
	call s:make_map ('n', 'A', '_Append', 's:EZCom_edit_comment (0)')
	call s:make_map ('n', 'C', '_Change', 's:EZCom_edit_comment (1)')
endfunction
" }}}
" }}}
" Section: Finish up {{{
" Function: g:EZCom_refresh {{{
" This function updates all buffer-scope variables and maps used by
" EZCom, using any settings provided by the user.
function g:EZCom_refresh ()
	call s:filetype_setup ()
	call s:map_setup ()
endfunction
" }}}
" Section: Compatibility again {{{
let &cpo = s:save_cpo
" }}}
" }}}


" vim: set fdm=marker:
