" functions for scrolling coc.nvim's popup window
" per
" https://vi.stackexchange.com/questions/21924/how-can-i-hide-and-scroll-popup-window-in-coc-nvim-in-vim/21927#21927
" see also .vim/autoload/misc.vim
"
function popup_scroll#find_cursor_popup(...)
  let radius = get(a:000, 0, 2)
  let srow = screenrow()
  let scol = screencol()

  " it's necessary to test entire rect, as some popup might be quite small
  for r in range(srow - radius, srow + radius)
    for c in range(scol - radius, scol + radius)
      let winid = popup_locate(r, c)
      if winid != 0
        return winid
      endif
    endfor
  endfor

  return 0
endfunction

function popup_scroll#scroll_cursor_popup(down)
  let winid = popup_scroll#find_cursor_popup()
  if winid == 0
    return 0
  endif

  let pp = popup_getpos(winid)
  call popup_setoptions( winid,
        \ {'firstline' : pp.firstline + ( a:down ? 1 : -1 ) } )

  return 1
endfunction
