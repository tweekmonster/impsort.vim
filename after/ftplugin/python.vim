if impsort#get_config('highlight_imported', 1)
  augroup impsort
    autocmd!
    autocmd InsertLeave,TextChanged <buffer> call impsort#highlight_imported(0)
    autocmd Syntax <buffer> call impsort#highlight_imported(1)
  augroup END
endif
