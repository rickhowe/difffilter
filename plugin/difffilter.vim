" difffilter.vim : Selectively compare lines as you want in diff
"
" Last Change: 2024/05/01
" Version:     1.1
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2024 Rick Howe
" License:     MIT

if exists('g:loaded_difffilter') || !has('diff') ||
                      \!(has('nvim') ? type(luaeval('vim.diff')) == v:t_func :
                                    \exists('*diff') && has('patch-9.1.0099'))
  finish
endif
let g:loaded_difffilter = 1.1

let s:save_cpo = &cpoptions
set cpo&vim

if !exists('g:DiffFilterExpr')
  let g:DiffFilterExpr = {lnum -> synIDtrans(synID(lnum,
                      \match(getline(lnum), '\S') + 1, 0)) != hlID('Comment')}
endif

call execute(['augroup difffilter', 'autocmd!',
      \'autocmd OptionSet diff call difffilter#DiffFilter()', 'augroup END'])

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
