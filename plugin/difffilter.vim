" difffilter.vim : Selectively compare lines as you want in diff mode
"
" Last Change: 2024/06/09
" Version:     1.3
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2024 Rick Howe
" License:     MIT

if exists('g:loaded_difffilter') || !has('diff') ||
                      \!(has('nvim') ? type(luaeval('vim.diff')) == v:t_func :
                                    \exists('*diff') && has('patch-9.1.0099'))
  finish
endif
let g:loaded_difffilter = 1.3

let s:save_cpo = &cpoptions
set cpo&vim

call execute(['augroup difffilter', 'autocmd!',
      \'autocmd OptionSet diff call difffilter#DiffFilter()', 'augroup END'])

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
