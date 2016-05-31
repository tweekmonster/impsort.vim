let s:path_script = expand('<sfile>:p:h:h').'/bin/pyinfo.py'


" Call the python script to get the environment python interpreter's info.
function! s:init() abort
  if exists('s:paths')
    return
  endif
  let py = 'python'
  if exists('$VIRTUAL_ENV') && executable($VIRTUAL_ENV.'/bin/python')
    let py = $VIRTUAL_ENV.'/bin/python'
  endif

  for line in systemlist(printf('%s "%s"', py, s:path_script))
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
  let last = prevnonblank(search(pattern, 'nW') - 1) + 1
  let first_import = last
  let last_start = last
  let guard = 0

  while guard < 100
    let start = search(pattern, 'W')
    if !start
      if last != last_start
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
  return s:trim(substitute(a:s, '\c[^a-z0-9_\-. ]\+', ' ', 'g'))
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
  let l = len(a:imports) - 1
  let imps = []

  while i < l
    let n = matchend(a:imports, '\<\S\+\%(\s\+as\s\+\S\+\)\?\>', i)
    if n == -1
      break
    endif
    call add(imps, s:trim(a:imports[i:n]))
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


" Get the depth of the import path
function! s:path_depth(import) abort
  return len(substitute(a:import, '\%(\_^\.\+\|[^\.]\)\+\.\?', 'x', 'g'))
endfunction


" Sort by length, then alphabetic.
function! s:_imp_sort_func(a, b) abort
  let al = len(a:a)
  let bl = len(a:b)
  if al < bl
    return -1
  elseif al > bl
    return 1
  endif

  if a:a < a:b
    return -1
  elseif a:a > a:b
    return 1
  endif

  return 0
endfunction


" Nested sort.  Imports are sorted by the parent path component.
function! s:_nested_sort(node, prefix) abort
  let imports = []

  for key in sort(keys(a:node), function('s:_imp_sort_func'))
    let prefix = (a:prefix != '' ? a:prefix.'.' : '').key
    if len(a:node[key])
      call extend(imports, s:_imp_sort(a:node[key], prefix))
    else
      call add(imports, prefix)
    endif
  endfor
  return imports
endfunction


function! s:nested_sort(imports) abort
  let imp_tree = {}
  for imp in a:imports
    let inode = imp_tree
    if imp =~ '^\.\+'
      let nodes = [imp]
    else
      let nodes = split(imp, '\.')
    endif
    for node in nodes
      if !has_key(inode, node)
        let inode[node] = {}
      endif
      let inode = inode[node]
    endfor
  endfor
  return s:_imp_sort(imp_tree, '')
endfunction


" Construct a sort key for the import.
function! s:_imp_key(import) abort
  let dots = s:path_depth(a:import)
  if a:import =~ '^\.\+'
    let module = a:import
  else
    let module = split(a:import, '\.')[0]
  endif
  return printf('%s.%02d.%s', module, dots, a:import)
endfunction


" Key sort constructs a key to sort on.  The constructed key should be user
" configurable.
function! s:_key_sort(a, b) abort
  let akey = s:_imp_key(a:a)
  let bkey = s:_imp_key(a:b)
  if akey < bkey
    return -1
  elseif akey > bkey
    return 1
  endif

  return 0
endfunction


function! s:key_sort(imports) abort
  let s:max_depth = 0
  for imp in a:imports
    let s:max_depth = max([s:max_depth, s:path_depth(imp)])
  endfor
  return sort(a:imports, function('s:_key_sort'))
endfunction


" Wrap imports if they go beyond &textwidth
function! s:wrap_imports(imports, width) abort
  let remainder = &l:textwidth - a:width
  if len(a:imports) < remainder
    return a:imports
  endif

  let out = '('
  let remainder += 1
  let l = 1
  for import in split(a:imports, ' ')
    let l1 = len(import) + 1
    if l + l1 > remainder
      let out = out[:-2]
      let out .= "\n".repeat(' ', a:width + 1)
      let l = 0
    endif
    let l += l1
    let out .= import.' '
  endfor

  return out[:-2].')'
endfunction


" Sort the imports in a line range.  This will remove non-import lines.
function! s:sort_range(line1, line2) abort
  call s:init()

  let line_indent = indent(nextnonblank(a:line1))
  let prefix = repeat(' ', line_indent)
  let lead = 0

  let prev = prevnonblank(a:line1 - 1)
  let prevtext = getline(prev)
  if prev > 1 || prevtext =~# '^\s*\<\%(import\|from\)\>'
    if indent(prev) == line_indent && prevtext !~# '^\s*#'
      let lead = 1
    endif
  endif

  let placements = ['hoist', 'internal', 'external', 'project']
  let imports = {}

  for placement in placements
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

  let import_lines = []
  if lead
    call add(import_lines, '')
  endif

  for placement in placements
    for import in s:key_sort(imports[placement]['import'])
      call add(import_lines, prefix.'import '.import)
    endfor

    if len(imports[placement]['import'])
      call add(import_lines, '')
    endif

    for import in s:key_sort(keys(imports[placement]['from']))
      let from_line = prefix.'from '.import.' import '
      let from_imports = join(sort(imports[placement]['from'][import]), ', ')
      let from_line .= s:wrap_imports(from_imports, len(from_line))
      call extend(import_lines, split(from_line, "\n"))
    endfor

    if len(imports[placement]['from'])
      call add(import_lines, '')
    endif
  endfor

  silent execute a:line1.','.a:line2.'delete _'
  call append(a:line1 - 1, import_lines)
  return a:line2 - (a:line1 + len(import_lines) - 1)
endfunction


" Sort entry point
function! impsort#sort(line1, line2) abort
  if &l:filetype !~# 'python'
    echohl ErrorMsg
    echo 'Buffer is not Python'
    echohl None
    return
  endif

  let saved = winsaveview()
  if a:line2 > a:line1
    let r1 = prevnonblank(a:line1 - 1) + 1
    let r2 = nextnonblank(a:line2 + 1) - 1
    call s:sort_range(r1, r2)
  else
    let offset = 0
    for r in s:import_regions()
      let r1 = r[0] - offset
      let r2 = r[1] - offset
      let r1 = prevnonblank(r1 - 1) + 1
      let r2 = nextnonblank(r2 + 1) - 1
      let offset += s:sort_range(r1, r2)
    endfor
  endif
  cal winrestview(saved)
endfunction
