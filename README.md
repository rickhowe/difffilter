# difffilter

## Selectively compare lines as you want in diff

The standard "diff" command supports "--ignore-matching-lines=regexp (-I
regexp)" option to ignore hunks if all the inserted and deleted lines match
regexp. This plugin provides similar functionality but tries a line-level
filtering based on regexp and other matching criteria.

For example, vim will show such differences for these 3 files:

![sample1](sample1.png)

This plugin gets vim to exclude comment lines so that you can focus on
seeing the differences on the "return" statement.

![sample2](sample2.png)

Internally, this plugin sets a function to the `diffexpr` option to:
* evaluate if each line should be compared or not
* mark the to-be-excluded lines in the files
* call a builtin diff function to compare them
* modify diff hunks to get vim to ignore the excluded lines

You need to specify a boolean expression in `t:DiffFilterExpr` tabpage local
or `g:DiffFilterExpr` global variable. In above example, the following lambda
expression is specified to exclude comment lines.
```
let g:DiffFilterExpr = {lnum -> synIDtrans(synID(lnum,
      \match(getline(lnum), '\S') + 1, 0)) != hlID('Comment')}
```
It checks a comment syntax highlighting on each line. That is a default
expression of `g:DiffFilterExpr` variable, which can be commonly used for a
comment line in a lot of filetypes. Alternatively, to make it faster, specify
a pattern of comment line specific to a filetype like vim script:
```
let g:DiffFilterExpr = {lnum -> getline(lnum) !~ '^\s*["#]'}
```
In addition, to check a comment block as well for a filetype like C and C++:
```
function MyDiffFilterExpr(lnum)
  let [c_line, c_start, c_end] = ['//', '/*', '*/']
  let [c_line, c_start, c_end] = map([c_line, c_start, c_end],
                        \{_, v -> '^\s*' . escape(v, '/*')})
  for c in [c_line, c_start, c_end]
    if getline(a:lnum) =~ c | return 1 | endif
  endfor
  let pos = [line('.'), col('.')]
  call cursor([a:lnum, 1])
  let sline = searchpair(c_start, '', c_end, 'nW')
  call cursor(pos)
  return (0 < sline) ? 1 : 0
endfunction
let g:DiffFilterExpr = function('MyDiffFilterExpr')
```
To use the last selected Visual area:
```
let g:DiffFilterExpr = {lnum -> line("'<") <= lnum && lnum <= line("'>")}
```
To compare lines not including a multibyte character:
```
let g:DiffFilterExpr = {lnum -> getline(lnum) !~ '[^\x00-\x7F]'}
```
To select indented lines:
```
let g:DiffFilterExpr = {lnum -> 0 < indent(lnum)}
```
To filter lines based on a text field criteria:
```
function MyDiffFilterExpr(lnum)
  let text = getline(a:lnum)
  let field = len(split(text, '|'))
  return text =~ '^|\+|$' && field[0] =~ '^\d\+$' && len(field) == 5
endfunction
let g:DiffFilterExpr = function('MyDiffFilterExpr')
```
As a default, this plugin sets `hl-Conceal` to visualize which line is not
diff compared and conceal them. To hide those lines, use `conceallevel` and
`concealcursor` options. Disable `t:DiffFilterConceal` or
`g:DiffFilterConceal` variable if not necessary,

Use `:diffupdate` command to reevaluate and redraw diff lines when text or
option is changed.

### Options

* `t:DiffFilterExpr`, `g:DiffFilterExpr`
  * A boolean expression to evaluate if a line should be compared or not
    (default: `{lnum -> synIDtrans(synID(lnum,
                    \match(getline(lnum), '\S') + 1, 0)) != hlID('Comment')}`)

* `t:DiffFilterConceal`, `g:DiffFilterConceal`
  * Enable (1) or disable (0) to highlight other than diff compared lines in
    `hl-Conceal` (default: `1`).

* `g:NoDiffFilter`
  * Disable (1) this plugin (default: `0`).

### Requirements

This plugin requires a builtin diff function:
* `diff()` and patch-9.1.0099 in vim 9.1
* Lua `vim.diff()` in nvim 0.6.0

### See also

There are other diff related plugins available:
* [diffchar.vim](https://github.com/rickhowe/diffchar.vim): Highlight the exact differences, based on characters and words
* [spotdiff.vim](https://github.com/rickhowe/spotdiff.vim): A range and area selectable `:diffthis` to compare partially
* [wrapfiller](https://github.com/rickhowe/wrapfiller): Align each wrapped line virtually between windows
