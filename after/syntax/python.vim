" Avoid highlighting imported objects if they're preceded by a period
syntax match impsortNonImport #\.\k\+# transparent contains=TOP,pythonAttribute,pythonImportedObject,pythonImportedFuncDef,pythonImportedClassDef,pythonImportedModule

" Prevents imports from being matched in the first part of `from ... import`
" lines.  `pythonInclude` is the built-in syntax's name.  `pythonImport` is
" from the `python-syntax` plugin.
silent! syntax clear pythonInclude pythonImport
syntax keyword pythonImport contained from
syntax keyword pythonImport import
syntax match pythonIncludeLine #\<from\s\+\S\+\># transparent contains=pythonImport

" Highlight links should cover both syntax sources without screwing up user
" defined highlights
highlight default link pythonImport pythonInclude
highlight default link pythonInclude Include
