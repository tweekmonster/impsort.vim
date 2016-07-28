command! -bang -range ImpSort call impsort#sort(<line1>, <line2>, <bang>0)
command! -bang ImpSortAuto call impsort#auto(<bang>0)

highlight default link pythonImportedObject Keyword
highlight default link pythonImportedFuncDef Function
highlight default link pythonImportedClassDef Type
highlight default link pythonImportedModule pythonImportedObject


augroup impsort
  autocmd!
  autocmd WinEnter * if &filetype =~# '\<python\>' && exists('b:impsort_pending_hl') |
        \   call call(b:impsort_pending_hl[0], b:impsort_pending_hl[1:]) |
        \ endif
augroup END
