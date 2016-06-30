" Avoid highlighting imported objects if they're preceded by a period
syntax match impsortNonImport #\.\k\+# transparent contains=TOP,pythonAttribute,pythonImportedObject,pythonImportedFuncDef,pythonImportedClassDef,pythonImportedModule
