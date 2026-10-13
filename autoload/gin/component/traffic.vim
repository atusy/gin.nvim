function! gin#component#traffic#ascii() abort
  return luaeval('require("gin.component.traffic").ascii()')
endfunction

function! gin#component#traffic#unicode() abort
  return luaeval('require("gin.component.traffic").unicode()')
endfunction
