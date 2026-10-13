function! gin#difffold#foldtext() abort
  return luaeval('require("gin.difffold").text()')
endfunction
