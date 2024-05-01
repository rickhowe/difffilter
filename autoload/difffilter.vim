" difffilter.vim : Selectively compare lines as you want in diff
"
" Last Change: 2024/05/01
" Version:     1.1
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2024 Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:df = 'difffilter'
let s:id = 'difffilter_id'
let s:ln = 'difffilter_ln'

function! difffilter#DiffFilter() abort
  if v:option_old != v:option_new
    let dw = filter(getwininfo(),
                          \'gettabwinvar(v:val.tabnr, v:val.winid, "&diff")')
    if v:option_new && len(dw) == 1
      if !get(g:, 'NoDiffFilter', 0)
        if !exists('s:save_dex')
          let s:save_dex = &diffexpr
          let &diffexpr = 'difffilter#DiffExpr()'
        endif
      endif
    elseif !v:option_new && len(dw) == 0
      if exists('s:save_dex')
        let &diffexpr = s:save_dex
        unlet s:save_dex
      endif
    endif
    call filter(dw, 'v:val.tabnr == tabpagenr() &&
                                      \v:val.bufnr == winbufnr(win_getid())')
    if v:option_new && len(dw) == 1 || !v:option_new && len(dw) == 0
      call s:DiffConceal()
    endif
  endif
endfunction

function! difffilter#DiffExpr() abort
  let tx = [readfile(v:fname_in), readfile(v:fname_new)]
  if tx == [['line1'], ['line2']]
    call writefile(['@@ -1 +1 @@'], v:fname_out)
    " diff session begins, prepare an event to find _in(1st)/_new(last) wins
    let s:dw = []
    call execute('autocmd! ' . s:df . ' FilterWritePost *
        \ let s:dw += [filter(getbufinfo(str2nr(expand("<abuf>")))[0].windows,
                                        \''getwinvar(v:val, "&diff")'')[0]]')
  else
    " set zz in excluded lines
    let DE = get(t:, 'DiffFilterExpr', get(g:, 'DiffFilterExpr'))
    if empty(DE) || type(DE) != v:t_func | let DE = {-> 1} | endif
    let zz = repeat(nr2char(0x7f), 3)
    for ix in [0, -1]
      call win_execute(s:dw[ix], ['if !exists("w:' . s:ln . '")',
        \'let w:' . s:ln . ' = filter(range(1, line("$")), "!DE(v:val)")',
        \'endif', 'for ln in w:' . s:ln, 'let tx[ix][ln - 1] = zz', 'endfor'])
    endfor
    " do diff() with &diffopt
    let op = #{}
    for oi in ['icase', 'iblank', 'iwhite', 'iwhiteall', 'iwhiteeol',
                                            \'indent-heuristic', 'algorithm']
      if &diffopt =~ '\<' . oi . '\>'
        let op[oi] = (oi == 'algorithm') ?
                                  \matchstr(&diffopt, oi . ':\zs\w\+\ze') : 1
      endif
    endfor
    let dl = split(s:DiffFunc(tx[0], tx[1], op), "\n")
    " change @@ hunks to exclude zz lines
    let HK = {l1, l2 -> '@@ -' . l1[0] . ((l1[1] == 1) ? '' : ',' . l1[1]) .
                    \' +' . l2[0] . ((l2[1] == 1) ? '' : ',' . l2[1]) . ' @@'}
    " vim not always work correctly so disable to split hunks as a default
    let xt = get(t:, 'DiffFilterExtra', get(g:, 'DiffFilterExtra', 0))
    let ed = ''
    let hk = []
    for ix in range(len(dl) - 1, 0, -1)
      let dx = dl[ix]
      if dx[0] != '@'
        let ed = ((dx == '-' . zz) ? '<' : (dx == '+' . zz) ? '>' : dx[0]) . ed
      else
        if ed !~ '[<>]'
          let hk = [dx] + hk
        else
          let [d1, d2] = map(split(dx[3 : -4]), 'v:val[1:]')
          let [p1, q1] = [(d1 =~ ',') ? split(d1, ',') : [d1, 1], []]
          let [p2, q2] = [(d2 =~ ',') ? split(d2, ',') : [d2, 1], []]
          let [e1, e2] = split(substitute(ed,
                                        \'[-<]*\ze\zs[+>]*', ':', ''), ':', 1)
          for [ee, pp, qq, es, ez] in [[e1, p1, q1, '-', '<'],
                                                      \[e2, p2, q2, '+', '>']]
            if ee =~ ez
              if ee !~ es . ez . '\+' . es
                " -</<-/<</<-< or +>/>+/>>/>+> : exclude < or > zz lines
                let pp[1] = count(ee, es)
                if 0 < pp[1]
                  let pp[0] += len(split(ee, es . '\+', 1)[0])
                endif
              else
                " -<- or +>+ : split into 2 or more hunks
                if xt
                  let cc = 0
                  for sz in split(ee, '\%(' . es . '\+\|' . ez . '\+\)\zs')
                    if sz[0] == es
                      let qq += [[pp[0] + cc , len(sz)]]
                    endif
                    let cc += len(sz)
                  endfor
                endif
              endif
            endif
          endfor
          if [p1[1], p2[1]] != [0, 0]
            if !xt || empty(q1) && empty(q2)
              let hx = [HK(p1, p2)]
            else
              let hx = []
              if !empty(q1) && empty(q2)
                let hx += [HK(q1[0], p2)]
                let pp = [(p2[1] == 0) ? p2[0] : p2[0] + p2[1] - 1, 0]
                for qq in q1[1:] | let hx += [HK(qq, pp)] | endfor
              elseif empty(q1) && !empty(q2)
                let hx += [HK(p1, q2[0])]
                let pp = [(p1[1] == 0) ? p1[0] : p1[0] + p1[1] - 1, 0]
                for qq in q2[1:] | let hx += [HK(pp, qq)] | endfor
              else
                let hx = [HK(p1, p2)]
              endif
            endif
            let hk = hx + hk
          endif
        endif
        let ed = ''
      endif
    endfor
    call writefile(hk, v:fname_out)
    if len(uniq(sort(map(filter(gettabinfo(tabpagenr())[0].windows,
            \'getwinvar(v:val, "&diff")'), 'winbufnr(v:val)')))) == len(s:dw)
      " diff session ends
      call execute('autocmd! ' . s:df . ' FilterWritePost')
      unlet s:dw
    endif
  endif
endfunction

function! s:DiffConceal() abort
  let dc = !has('conceal') ? 0 :
              \get(t:, 'DiffFilterConceal', get(g:, 'DiffFilterConceal', 1))
  for wn in gettabinfo(tabpagenr())[0].windows
    let wv = getwinvar(wn, '')
    if has_key(wv, s:id)
      call map(filter(getmatches(wn), 'index(wv[s:id], v:val.id) != -1'),
                                                \'matchdelete(v:val.id, wn)')
      unlet wv[s:id]
    endif
    if has_key(wv, s:ln)
      if dc != 0
        " avoid to draw conceal over diff_hl lines
        call win_execute(wn,
                        \'call filter(wv[s:ln], "diff_hlID(v:val, 1) == 0")')
        if !empty(wv[s:ln])
          if !has('nvim') || has('nvim-0.9.0')
            call setwinvar(wn, s:id, [matchaddpos('Conceal',
                  \(0 < dc) ? wv[s:ln] : map(wv[s:ln], '[v:val, 1, abs(dc)]'),
                                                      \0, -1, #{window: wn})])
          else
            call setwinvar(wn, s:id, map(range(0, len((0 < dc) ? wv[s:ln] :
                              \map(wv[s:ln], '[v:val, 1, abs(dc)]')) - 1, 8),
                        \'matchaddpos("Conceal", wv[s:ln][v:val : v:val + 7],
                                                    \0, -1, #{window: wn})'))
          endif
        endif
      endif
      unlet wv[s:ln]
    endif
  endfor
endfunction

if has('nvim')
  function! s:DiffFunc(l1, l2, op) abort
    let op = #{}
    for [vv, nn] in [['iblank', 'ignore_blank_lines'],
                    \['iwhite', 'ignore_whitespace'],
                    \['iwhiteall', 'ignore_whitespace_change'],
                    \['iwhiteeol', 'ignore_whitespace_change_at_eol'],
                    \['context', 'ctxlen'],
                    \['indent-heuristic', 'indent_heuristic'],
                    \['algorithm', 'algorithm']]
      if has_key(a:op, vv) | let op[nn] = a:op[vv] ? v:true : v:false | endif
    endfor
    let [l1, l2] = [join(a:l1, "\n") . "\n", join(a:l2, "\n") . "\n"]
    if has_key(a:op, 'icase') && a:op['icase']
      let [l1, l2] = [tolower(l1), tolower(l2)]
    endif
    return v:lua.vim.diff(l1, l2, op)
  endfunction
else
  function! s:DiffFunc(l1, l2, op) abort
    return diff(a:l1, a:l2, a:op)
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
