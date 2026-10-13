function! gin#component#worktree#name() abort
  return luaeval('require("gin.component.worktree").name()')
endfunction

function! gin#component#worktree#full() abort
  return luaeval('require("gin.component.worktree").full()')
endfunction
