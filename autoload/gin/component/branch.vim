function! gin#component#branch#ascii() abort
  return luaeval('require("gin.component.branch").ascii()')
endfunction

function! gin#component#branch#unicode() abort
  return luaeval('require("gin.component.branch").unicode()')
endfunction
