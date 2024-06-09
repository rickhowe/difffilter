" difffilter.vim : Selectively compare lines as you want in diff mode
"
" Last Change: 2024/06/09
" Version:     1.3
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2024 Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:df = 'difffilter'
let s:id = 'difffilter_id'
let s:ln = 'difffilter_ln'
let s:de = {lnum -> (&commentstring[-2:] == '%s') ?
          \getline(lnum) !~ '^\s*' . escape(&commentstring[:-3], '^$.*[]~\') :
          \synIDtrans(synID(lnum, match(getline(lnum), '\S') + 1, 0)) !=
                                                            \hlID('Comment')}

function! difffilter#DiffFilter() abort
  if v:option_old != v:option_new
    let ac = 0
    let dw = filter(getwininfo(),
                          \'gettabwinvar(v:val.tabnr, v:val.winid, "&diff")')
    if v:option_new && len(dw) == 1
      if get(g:, 'DiffFilter', 1)
        if !exists('s:save_dex')
          let s:save_dex = &diffexpr
          let &diffexpr = 'difffilter#DiffExpr()'
        endif
        let ac = 1
      endif
    elseif !v:option_new && len(dw) == 0
      if exists('s:save_dex')
        let &diffexpr = s:save_dex
        unlet s:save_dex
      endif
      let ac = -1
    endif
    if ac != 0
      for [ev, fn] in [['WinClosed', 's:DiffClose()'],
                                          \['DiffUpdated', 's:DiffConceal()']]
        call execute('autocmd! ' . s:df . ' ' . ev .
                                          \((ac == 1) ? ' * call ' . fn : ''))
      endfor
    endif
  endif
endfunction

function! difffilter#DiffExpr() abort
  let tx = [readfile(v:fname_in), readfile(v:fname_new)]
  if tx == [['line1'], ['line2']]
    call writefile(['@@ -1 +1 @@'], v:fname_out)
    " diffexpr session begins, set an event to find _in(1st)/_new(last) wins
    let s:dw = []
    call execute('autocmd! ' . s:df . ' FilterWritePost *
                          \ let s:dw += [bufwinid(str2nr(expand("<abuf>")))]')
  else
    " check to-be-excluded lines and set zz to them
    let DE = get(t:, 'DiffFilterExpr', get(g:, 'DiffFilterExpr', s:de))
    if empty(DE) || type(DE) != v:t_func | let DE = {-> 1} | endif
    let zz = repeat(nr2char(0x7f), 3)
    for ix in [0, -1]
      let wv = getwinvar(s:dw[ix], '')
      if !has_key(wv, s:ln)
        call win_execute(s:dw[ix],
                  \'let wv[s:ln] = filter(range(1, line("$")), "!DE(v:val)")')
      endif
      for ln in wv[s:ln] | let tx[ix][ln - 1] = zz | endfor
    endfor
    " do diff() with &diffopt
    let op = #{}
    for do in ['icase', 'iblank', 'iwhite', 'iwhiteall', 'iwhiteeol',
                                            \'indent-heuristic', 'algorithm']
      if &diffopt =~ '\<' . do . '\>'
        let op[do] = (do == 'algorithm') ?
                                  \matchstr(&diffopt, do . ':\zs\w\+\ze') : 1
      endif
    endfor
    let dl = split(s:DiffFunc(tx[0], tx[1], op), "\n")
    if empty(filter(copy(s:dw), '!empty(getwinvar(v:val, s:ln))'))
      " found no zz lines in all diff wins
      let hk = dl
    else
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
          let ed = ((dx == '-' . zz) ? '<' : (dx == '+' . zz) ? '>' : dx[0]) .
                                                                          \ed
        else
          if ed !~ '[<>]'
            let hk = [dx] + hk
          else
            let [d1, d2] = map(split(dx[3 : -4]), 'v:val[1:]')
            let [p1, q1] = [map((d1 =~ ',') ? split(d1, ',') : [d1, 1],
                                                        \'str2nr(v:val)'), []]
            let [p2, q2] = [map((d2 =~ ',') ? split(d2, ',') : [d2, 1],
                                                        \'str2nr(v:val)'), []]
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
            if empty(q1) && empty(q2)
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
          let ed = ''
        endif
      endfor
    endif
    " trick: change an empty hunk to [0,0] to always trigger DiffUpdated
    if empty(hk) | let hk = ['@@ -0,0 +0,0 @@'] | endif
    call writefile(hk, v:fname_out)
    if len(uniq(sort(map(filter(gettabinfo(tabpagenr())[0].windows,
            \'getwinvar(v:val, "&diff")'), 'winbufnr(v:val)')))) == len(s:dw)
      " diffexpr session ends, remove the event
      call execute('autocmd! ' . s:df . ' FilterWritePost')
      unlet s:dw
    endif
  endif
endfunction

function! s:DiffClose() abort
  let wn = str2nr(expand('<amatch>'))
  if getwinvar(wn, '&diff')
    " a diff buffer, which was hidden when closed, will come in diffexpr
    " session and may cause an accident, so do diffoff before closed
    let de = &diffexpr
    let &diffexpr = ''
    call win_execute(wn, 'diffoff')
    let &diffexpr = de
  endif
  if len(filter(gettabinfo(tabpagenr())[0].windows,
                                            \'getwinvar(v:val, "&diff")')) < 2
    call s:DiffConceal()
  endif
endfunction

function! s:DiffConceal() abort
  let dc = has('conceal') ?
            \get(t:, 'DiffFilterConceal', get(g:, 'DiffFilterConceal', 1)) : 0
  let cf = {}
  for wn in gettabinfo(tabpagenr())[0].windows
    let wv = getwinvar(wn, '')
    if has_key(wv, s:id)
      call map(filter(getmatches(wn), 'index(wv[s:id], v:val.id) != -1'),
                                                \'matchdelete(v:val.id, wn)')
      unlet wv[s:id]
    endif
    call s:DelConcealFiller(wn)
    let hf = []
    if dc == 2 && &diffopt =~ 'filler' && getwinvar(wn, '&diff')
      call win_execute(wn, 'let hf = map(range(1, line("$")),
                        \{_, v -> repeat(v . "-", diff_filler(v + 1) + 1)})')
    endif
    if has_key(wv, s:ln)
      if 0 < dc
        " avoid to draw conceal over diff_hl lines
        call win_execute(wn,
                        \'call filter(wv[s:ln], "diff_hlID(v:val, 1) == 0")')
        if !empty(wv[s:ln])
          if !has('nvim') || has('nvim-0.9.0')
            call setwinvar(wn, s:id, [matchaddpos('Conceal', wv[s:ln], 0, -1,
                                                            \#{window: wn})])
          else
            call setwinvar(wn, s:id, map(range(0, len(wv[s:ln]) - 1, 8),
                        \'matchaddpos("Conceal", wv[s:ln][v:val : v:val + 7],
                                                    \0, -1, #{window: wn})'))
          endif
          if !empty(hf)
            for ln in wv[s:ln]
              let hf[ln - 1] = substitute(hf[ln - 1], '-', '#', '')
            endfor
          endif
        endif
      endif
      unlet wv[s:ln]
    endif
    if !empty(hf)
      let cf[wn] = split(join(hf, ''),
                                  \'\%(\(\(\d\+-\)\+\)\|\(\(\d\+#\)\+\)\)\zs')
    endif
  endfor
  " draw conceal fillers
  if 1 < len(cf)
    let ix = 0
    while 1
      let cm = {}
      for wn in keys(cf)
        if ix < len(cf[wn])
          let cm[wn] = len(substitute(cf[wn][ix], '\d\+', '', 'g')) *
                                              \((cf[wn][ix] =~ '-') ? 1 : -1)
        endif
      endfor
      if empty(cm) | break | endif
      let [mn, mx] = [min(values(cm)), max(values(cm))]
      if mn != mx
        for wn in keys(cm)
          if mn < cm[wn]
            let cx = split(cf[wn][ix], '\%(\d\+.\)\zs')
            if 0 < mn         " all - : extend ['+', '-']
              call extend(cf[wn], [cx[mn - 1][: -2] . '+',
                                                \join(cx[mn :], '')], ix + 1)
            elseif mx < 0     " all #/+ : add '+'
              let cf[wn][ix] .= repeat(cx[-1][: -2] . '+' , cm[wn] - mn)
            endif
          endif
        endfor
      endif
      if 0 < mn | for wn in keys(cm) | let cf[wn][ix] = '' | endfor | endif
      let ix += 1
    endwhile
    let cc = (&fillchars =~ 'eob') ? matchstr(&fillchars, 'eob:\zs.') : '~'
    for wn in keys(cf)
      for lm in filter(split(join(cf[wn], ''), '\%(\d\+.\)\zs'),
                                                              \'v:val =~ "+"')
        call s:AddConcealFiller(wn, str2nr(lm[: -2]), cc)
      endfor
    endfor
  endif
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace(s:df)

  function! s:AddConcealFiller(wn, ln, cc) abort
    let bn = winbufnr(a:wn)
    let [ln, ab] = (a:ln == 0) ? [1, v:true] : [a:ln, v:false]
    call nvim_buf_set_extmark(bn, s:ns, ln - 1, 0,
              \#{virt_lines: [[[a:cc, 'EndOfBuffer']]], virt_lines_above: ab})
  endfunction

  function! s:DelConcealFiller(wn) abort
    let bn = winbufnr(a:wn)
    for id in nvim_buf_get_extmarks(bn, s:ns, 0, -1, {})
      call nvim_buf_del_extmark(bn, s:ns, id[0])
    endfor
  endfunction

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
  if empty(prop_type_get(s:df))
    call prop_type_add(s:df, #{highlight: 'EndOfBuffer'})
  endif

  function! s:AddConcealFiller(wn, ln, cc) abort
    let bn = winbufnr(a:wn)
    let [ln, ab] = (a:ln == 0) ? [1, 'above'] : [a:ln, 'below']
    call prop_add(ln, 0, #{type: s:df, bufnr: bn, text: a:cc, text_align: ab})
  endfunction

  function! s:DelConcealFiller(wn) abort
    let bn = winbufnr(a:wn)
    if !empty(prop_find(#{type: s:df, bufnr: bn, lnum: 1, col: 1}))
      call prop_remove(#{type: s:df, bufnr: bn, all: 1})
    endif
  endfunction

  function! s:DiffFunc(l1, l2, op) abort
    return diff(a:l1, a:l2, a:op)
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
