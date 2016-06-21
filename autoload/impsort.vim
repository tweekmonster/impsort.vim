let s:path_script = expand('<sfile>:p:h:h').'/bin/pyinfo.py'
let s:placements = ['hoist', 'internal', 'external', 'project']
let s:impsort_method_group = ['length', 'alpha']
let s:impsort_method_module = ['depth', 'length', 'alpha']
let s:impsort_method_import = ['length', 'alpha']


" Call the python script to get the environment python interpreter's info.
function! s:init() abort
  if exists('s:paths')
    return
  endif
  let py = 'python'
  if exists('$VIRTUAL_ENV') && executable($VIRTUAL_ENV.'/bin/python')
    let py = $VIRTUAL_ENV.'/bin/python'
  endif

  for line in split(system(printf('%s "%s"', py, s:path_script)), "\n")
    let i = stridx(line, '=')
    let name = line[:i-1]
    if name == 'ext_suffix'
      let s:[name] = line[i+1:]
    else
      let s:[name] = split(line[i+1:], ':')
    endif
  endfor
endfunction


" Determine the script regions that are import lines, grouped together.
function! s:import_regions() abort
  let saved = winsaveview()
  keepjumps normal! gg
  let pattern = '\_^\(\s*\)\<\%(import\|from\)\> .\+\_$\%(\1\_s\+\_^\s\+.\+\)*'
  let blocks = []
  let last = prevnonblank(search(pattern, 'ncW') - 1) + 1
  let first_import = last
  let last_start = last
  let guard = 0

  while guard < 100
    let start = search(pattern, 'W')
    if !start
      if last != last_start || (last == first_import && getline(first_import) =~# pattern)
        call add(blocks, [last_start, last])
      endif
      break
    endif
    let end = search(pattern, 'eW')
    let prev = prevnonblank(max([first_import, start - 1]))

    if prev != last && join(getline(last_start, last), '') !~# '^\s*$'
      call add(blocks, [last_start, last])
      let last_start = start
    endif

    let last = end
    let guard += 1
  endwhile

  call winrestview(saved)
  return blocks
endfunction


function! s:trim(s) abort
  return substitute(a:s, '^\s*\|\s*$', '', 'g')
endfunction


" Clean string of characters that are not relevant to impsort.vim
function! s:clean(s) abort
  return s:trim(substitute(a:s, '\c[^a-z0-9_\-.\* ]\+', ' ', 'g'))
endfunction


function! s:uniqadd(obj, item) abort
  if index(a:obj, a:item) == -1
    call add(a:obj, a:item)
  endif
endfunction


" Normalize the import lines by cleaning text and joining over-indented lines
" to the previous import line.
function! s:normalize_imports(line1, line2) abort
  let lines = []
  let ind = -1
  for l in getline(a:line1, a:line2)
    if l =~ '^\s*$'
      continue
    endif

    let l_ind = matchend(l, '^\s*\S')
    if l !~# '^\s*\%(import\|from\)' && ind != -1 && l_ind > ind
      let lines[-1] .= l
      continue
    endif

    let ind = l_ind
    call add(lines, l)
  endfor
  return map(lines, 's:clean(v:val)')
endfunction


" Parse import lines into module strings.
function! s:parse_imports(imports) abort
  let i = 0
  let l = len(a:imports)
  let imps = []

  while i < l
    let n = matchend(a:imports, '\*\|\<\S\+\%(\s\+as\s\+\S\+\)\?\>', i)
    if n == -1
      break
    endif
    call add(imps, s:trim(a:imports[i :n]))
    let i = n + 1
  endwhile

  return imps
endfunction


" Determine the import placement.
function! s:placement(import) abort
  if a:import =~ '^\.\+'
    " from . import module
    " import ..module
    let module = substitute(a:import, '^\(\.\+\)', '\1/', '')
  else
    let module = split(a:import, '\.')[0]
  endif

  if module == '__future__'
    return 'hoist'
  endif

  if index(s:builtins, module) != -1
    return 'internal'
  endif

  for path in s:paths
    let mpath = path.'/'.module
    if filereadable(mpath.'.py')
          \ || filereadable(mpath.s:ext_suffix)
          \ || (isdirectory(mpath) && filereadable(mpath.'/__init__.py'))
      if path =~# '/site-packages$'
        return 'external'
      else
        return 'internal'
      endif
    endif
  endfor

  return 'project'
endfunction


" Convenience function for keeping a match at the top
function! impsort#sort_top(pattern, a, b) abort
  if a:a =~# a:pattern && a:b =~# a:pattern
    return 0
  endif

  if a:a =~# a:pattern
    return -1
  elseif a:b =~# a:pattern
    return 1
  endif

  return 0
endfunction


" Get the depth of the import path
function! s:path_depth(import) abort
  return len(substitute(a:import, '\%(\_^\.\+\|[^\.]\)\+\.\?', 'x', 'g'))
endfunction


function! s:__alpha_cmp(a, b) abort
  if a:a > a:b
    return 1
  elseif a:a < a:b
    return -1
  endif

  return 0
endfunction


function! s:__depth_cmp(a, b) abort
  let a_depth = s:path_depth(a:a)
  let b_depth = s:path_depth(a:b)

  if a_depth > b_depth
    return 1
  elseif a_depth < b_depth
    return -1
  endif

  return 0
endfunction


function! s:__length_cmp(a, b) abort
  let a_len = len(a:a)
  let b_len = len(a:b)
  if a_len > b_len
    return 1
  elseif a_len < b_len
    return -1
  endif

  return 0
endfunction


function! s:_group_cmp(a, b) abort
  " relative imports always goes to the bottom
  let order = impsort#sort_top('^\.', a:a, a:b)
        \ * (get(g:, 'impsort_relative_last', 0) ? -1 : 1)
  if order
    return order
  endif
  return impsort#sort_top('^__$', a:a, a:b)
endfunction


function! s:_sort(a, b) abort
  let args = [a:a, a:b]
  for s:_sfunc in s:_sort_methods
    let order = call(s:_sfunc, args)
    if order != 0
      return order
    endif
  endfor
  return 0
endfunction


function! s:sort(obj, methods) abort
  let s:_sort_methods = a:methods
  return sort(copy(a:obj), 's:_sort')
endfunction


function! s:get_method(name) abort
  let method = get(b:, 'impsort_method_'.a:name,
        \ get(g:, 'impsort_method_'.a:name,
        \ get(s:, 'impsort_method_'.a:name, ['length', 'alpha'])))
  let funcs = []
  for i in range(len(method))
    " Not using for...in to avoid type mismatch error
    if type(method[i]) == 2
      call add(funcs, method[i])
    else
      call add(funcs, function('s:__'.method[i].'_cmp'))
    endif
  endfor
  return funcs
endfunction


function! s:sort_imports(imports, group_space) abort
  let groups = {}
  for imp in a:imports
    let groupname = matchstr(imp, '^\%(\.\|[^\.]*\)\ze')
    let remainder = matchstr(imp, '^\%(\.\|[^\.]*\)\zs.*')
    if !has_key(groups, groupname)
      let groups[groupname] = []
    endif
    call add(groups[groupname], remainder)
  endfor

  let out = []
  let group_sort = s:get_method('group')

  " Group the single line imports together
  let singles = []
  for groupname in s:sort(keys(groups), group_sort)
    if len(groups[groupname]) == 1
      call extend(singles, map(copy(groups[groupname]), 'groupname . v:val'))
      call remove(groups, groupname)
    endif
  endfor

  if !empty(singles)
    let groups['__'] = singles
  endif

  " s:_group_cmp is always first to arrange the relative imports
  for groupname in s:sort(keys(groups), [function('s:_group_cmp')] + group_sort)
    let groupimports = copy(groups[groupname])
    if groupname == '__'
      let groupname = ''
    endif
    let import_group = map(groupimports, 'groupname . v:val')
    call extend(out, s:sort(import_group, s:get_method('module')))
    if a:group_space
      call add(out, '')
    endif
  endfor

  return out
endfunction


" Wrap imports if they go beyond &textwidth
function! s:wrap_imports(imports, width) abort
  let remainder = &l:textwidth - a:width
  if len(a:imports) < remainder
    return a:imports
  endif

  let imports = split(a:imports, ',\zs ')
  if len(imports) < 2
    return a:imports
  endif

  let out = '('
  let remainder += 1
  let l = 1
  for import in imports
    let l1 = len(import) + 1
    if l > 1 && l + l1 > remainder
      let out = out[:-2]
      let out .= "\n".repeat(' ', a:width + 1)
      let l = 0
    endif
    let l += l1
    let out .= import.' '
  endfor

  return out[:-2].')'
endfunction


function! impsort#get_imports(line1, line2) abort
  let imports = {}

  for placement in s:placements
    let imports[placement] = {'import': [], 'from': {}}
  endfor

  for imp in s:normalize_imports(a:line1, a:line2)
    if imp =~# '^import '
      for import in s:parse_imports(s:trim(imp[6:]))
        let placement = s:placement(import)
        call add(imports[placement]['import'], import)
      endfor
    elseif imp =~# '^from '
      let parts = split(imp[4:], '\<import\>')
      if len(parts) != 2
        continue
      endif
      let module = s:trim(parts[0])
      let placement = s:placement(module)
      for import in s:parse_imports(s:trim(parts[1]))
        if !has_key(imports[placement]['from'], module)
          let imports[placement]['from'][module] = []
        endif
        if index(imports[placement]['from'][module], import) == -1
          call add(imports[placement]['from'][module], import)
        endif
      endfor
    endif
  endfor

  return imports
endfunction


" Returns all of the found imports
function! impsort#get_all_imports() abort
  let imports = []
  for r in s:import_regions()
    let r1 = s:prevline(r[0])
    let r2 = s:nextline(r[1])
    call add(imports, {'lines': [r1, r2], 'imports': impsort#get_imports(r1, r2)})
  endfor
  return imports
endfunction


" Return a list of all imported objects
function! impsort#get_all_imported() abort
  let imported = []
  for r in impsort#get_all_imports()
    for [section, imports] in items(r.imports)
      for item in imports.import
        call s:uniqadd(imported, item)
      endfor

      for [module, from_imports] in items(imports.from)
        for item in from_imports
          if item =~# '\<as\>'
            let item = matchstr(item, '\<\k\+$')
          endif
          call s:uniqadd(imported, item)
        endfor
      endfor
    endfor
  endfor
  return imported
endfunction


" Sort the imports in a line range.  This will remove non-import lines.
function! s:_sort_range(line1, line2) abort
  call s:init()

  let line_indent = indent(nextnonblank(a:line1))
  let prefix = repeat(' ', line_indent)
  let lead = 0

  let prev = prevnonblank(a:line1 - 1)
  let prevtext = getline(prev)
  if prev > 1 || prevtext =~# '^\s*\<\%(import\|from\)\>'
    if indent(prev) > line_indent || (indent(prev) == line_indent
          \ && prevtext !~# '^\s*#\|\%(''''''\|"""\)$')
      let lead = 1
    endif
  endif

  let imports = impsort#get_imports(a:line1, a:line2)

  let import_lines = []
  if lead
    call add(import_lines, '')
  endif

  for placement in s:placements
    for import in s:sort_imports(imports[placement]['import'], 0)
      if import == ''
        call add(import_lines, '')
        continue
      endif
      call add(import_lines, prefix.'import '.import)
    endfor

    if len(imports[placement]['import']) && import_lines[-1] != ''
      call add(import_lines, '')
    endif

    for import in s:sort_imports(keys(imports[placement]['from']),
          \ s:separate_groups)
      if !has_key(imports[placement]['from'], import)
        if import == ''
          call add(import_lines, '')
        endif
        continue
      endif
      let from_line = prefix.'from '.import.' import '
      let from_imports = join(s:sort(imports[placement]['from'][import],
            \ s:get_method('imports')), ', ')
      let from_line .= s:wrap_imports(from_imports, len(from_line))
      call extend(import_lines, split(from_line, "\n"))
    endfor

    if len(imports[placement]['from']) && import_lines[-1] != ''
      call add(import_lines, '')
    endif
  endfor

  let nextline = nextnonblank(a:line2 + 1)
  if len(import_lines)
    let text = getline(nextline)
    if !nextline || text =~# '^except ImportError'
      let import_lines = import_lines[:-2]
    elseif !line_indent && text =~# '^\s*\%(def\|class\)\>'
      call add(import_lines, '')
    endif
  endif

  return import_lines
endfunction


function! s:sort_range(line1, line2) abort
  let import_lines = s:_sort_range(a:line1, a:line2)
  let existing = getline(a:line1, a:line2)
  if string(existing) != string(import_lines)
    " Only update if it changes something
    silent execute a:line1.','.a:line2.'delete _'
    call append(a:line1 - 1, import_lines)
  endif

  return a:line2 - (a:line1 + len(import_lines) - 1)
endfunction


function! s:prevline(lnum) abort
  return prevnonblank(a:lnum - 1) + 1
endfunction


function! s:nextline(lnum) abort
  let lnum = nextnonblank(a:lnum + 1)
  if !lnum
    return line('$')
  endif
  return lnum - 1
endfunction


" Sort entry point
function! impsort#sort(line1, line2, separate_groups) abort
  if &l:filetype !~# 'python'
    echohl ErrorMsg
    echo 'Buffer is not Python'
    echohl None
    return
  endif

  let s:separate_groups = a:separate_groups
  let saved = winsaveview()

  if a:line2 > a:line1
    let r1 = s:prevline(a:line1)
    let r2 = s:nextline(a:line2)
    let change = s:sort_range(r1, r2)
    if saved.lnum > r2
      let saved.lnum -= change
    endif
  else
    let offset = 0
    for r in s:import_regions()
      let r1 = s:prevline(r[0] - offset)
      let r2 = s:nextline(r[1] - offset)
      let change = s:sort_range(r1, r2)
      let offset += change
      if saved.lnum > r2
        let saved.lnum -= change
      endif
    endfor
  endif

  call winrestview(saved)
endfunction


function! impsort#is_sorted() abort
  let s:separate_groups = 0

  for r in s:import_regions()
    let r1 = s:prevline(r[0])
    let r2 = s:nextline(r[1])
    let cur_lines = filter(getline(r1, r2), '!empty(v:val)')
    let import_lines = filter(s:_sort_range(r1, r2), '!empty(v:val)')

    if string(cur_lines) != string(import_lines)
      return 0
    endif
  endfor

  return 1
endfunction


function! s:auto_sort(separate_groups)
  if !exists('b:_impsort_auto') || !b:_impsort_auto
    return
  endif

  unlet! b:_impsort_auto

  " Variables for cursor positioning sorcery
  let start_line = 0
  let l = line('.')
  let c = col('.')
  let impline = search('^\s*\%(import\|from\)\>', 'ncbW')
  let cword = expand('<cword>')
  let module = matchstr(getline(impline), '^\s*\zs\%(import\|from\)\s\+\S\+')

  if !empty(module)
    let module = substitute(module, '\s\+', ' ', 'g')
  endif

  for r in s:import_regions()
    let r1 = s:prevline(r[0])
    let r2 = s:nextline(r[1])
    if r1 <= l && r2 >= l
      let start_line = r1
      call impsort#sort(r[0], r[1], a:separate_groups)
      break
    endif
  endfor

  " Try to restore the cursor to a place the user might expect it to be
  if start_line && !empty(module)
    let word_pos = [0, 0]
    let view = winsaveview()
    call cursor(start_line, 1)
    let [restore_line, restore_col] = searchpos('^\s*'.module, 'ceW')
    if restore_line
      let stop_line = restore_line

      call cursor(restore_line, col('$'))
      let next_import = search('^\s*\%(import\|from\)\>', 'nW', restore_line + 5)
      if next_import
        let stop_line = next_import - 1
      endif

      " This will be good enough for `import` and if there's no cword
      let word_pos = [restore_line, restore_col]
      call cursor(restore_line, restore_col)

      if !empty(cword)
        let pos = searchpos('\<'.cword.'\>', 'eW', stop_line)
        if pos[0]
          let word_pos = pos
        endif
      endif
    endif
    call winrestview(view)

    if word_pos[0]
      call cursor(word_pos[0], word_pos[1] - 1)
    endif
  endif
endfunction


function! impsort#auto(separate_groups) abort
  if exists('#impsort#InsertLeave#<buffer>')
    autocmd! impsort * <buffer>
    echohl WarningMsg
    echomsg 'Auto ImpSort disabled'
    echohl None
  else
    augroup impsort
      autocmd! impsort * <buffer>
      autocmd TextChangedI <buffer> let b:_impsort_auto = 1
      execute 'autocmd InsertLeave <buffer> call s:auto_sort('.a:separate_groups.')'
    augroup END
  endif
endfunction


function! impsort#highlight_imported(force) abort
  call s:init()
  let imports = impsort#get_all_imported()
  call sort(imports)

  if a:force || !exists('b:python_imports') || imports != b:python_imports
    silent! syntax clear pythonImported
    let b:python_imports = imports
    silent! execute 'syntax keyword pythonImportedObject '.join(imports, ' ')
  endif
endfunction
