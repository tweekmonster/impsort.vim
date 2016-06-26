if impsort#get_config('highlight_imported', 1)
  augroup impsort
    autocmd! * <buffer>
    autocmd BufEnter <buffer> if !exists('b:python_imports') | call impsort#highlight_imported(1) | endif
    autocmd InsertLeave,TextChanged <buffer> call impsort#highlight_imported(0)
    autocmd Syntax <buffer> call impsort#highlight_imported(1)
  augroup END
endif

if impsort#get_config('override_formatexpr', 0) && !exists('b:_orig_formatexpr')
  let b:_orig_formatexpr = &l:formatexpr
  setlocal formatexpr=impsort#formatexpr()
endif
