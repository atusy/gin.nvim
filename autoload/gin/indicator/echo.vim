function! gin#indicator#echo#open(id) abort
  call luaeval('require("gin.indicator.echo").open(_A)', a:id)
endfunction

function! gin#indicator#echo#write(id, chunk) abort
  call luaeval('require("gin.indicator.echo").write(unpack(_A))', [a:id, a:chunk])
endfunction

function! gin#indicator#echo#close(id) abort
  call luaeval('require("gin.indicator.echo").close(_A)', a:id)
endfunction
