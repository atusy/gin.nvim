function! gin#util#expand(expr) abort
  return luaeval('require("gin.util").expand(_A)', a:expr)
endfunction

function! gin#util#worktree(...) abort
  return luaeval('require("gin.util").worktree(unpack(_A))', a:000)
endfunction

function! gin#util#reload(...) abort
  call luaeval('require("gin.util").reload(_A)', a:0 ? a:1 : bufnr())
endfunction
