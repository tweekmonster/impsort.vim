" Avoid highlighting imported objects if they're preceded by a period
syntax cluster impsortObjects contains=pythonImportedObject,pythonImportedFuncDef,pythonImportedClassDef,pythonImportedModule
syntax match impsortNonImport #\.\k\+# transparent contains=TOP,pythonAttribute,@impsortObjects

" Prevents imports from being matched in the first part of `from ... import`
" lines.  `pythonInclude` is the built-in syntax's name.  `pythonImport` is
" from the `python-syntax` plugin.
silent! syntax clear pythonInclude pythonImport pythonDecorator
syntax keyword pythonImport contained from
syntax keyword pythonImport import
syntax match pythonIncludeLine #\<from\s\+\S\+\s# transparent contains=pythonImport

syntax region pythonDecorator start=#@# end=#$# oneline contains=@impsortObjects,pythonDottedName,pythonFunction

" Highlight links should cover both syntax sources without screwing up user
" defined highlights
highlight default link pythonImport pythonInclude
highlight default link pythonInclude Include
