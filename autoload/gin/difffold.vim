let g:gin#difffold#prefixes_ascii = luaeval('require("gin.difffold").presets.ascii')
let g:gin#difffold#prefixes_nerdfont = luaeval('require("gin.difffold").presets.nerdfont')

function! gin#difffold#foldtext() abort
  return luaeval('require("gin.difffold").text()')
endfunction
