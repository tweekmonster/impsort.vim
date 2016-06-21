command! -bang -range ImpSort call impsort#sort(<line1>, <line2>, <bang>0)
command! -bang ImpSortAuto call impsort#auto(<bang>0)

highlight default link pythonImportedObject Keyword

if get(g:, 'impsort_highlight_imported', 1)
  augroup impsort
    autocmd!
    autocmd BufReadPost,InsertLeave,TextChanged *.py call impsort#highlight_imported(0)
    autocmd FileType *.py call impsort#highlight_imported(1)
  augroup END
endif
