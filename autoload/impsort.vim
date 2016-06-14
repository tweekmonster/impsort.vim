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
  let last = prevnonblank(search(pattern, 'ncW') - 1) + 1
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
  let l = len(a:imports)
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


function! s:_length_cmp(a, b) abort
  let a_len = len(a:a)
  let b_len = len(a:b)
  if a_len > b_len
    return 1
  elseif a_len < b_len
    return -1
  endif
  return 0
endfunction


function! s:_module_cmp(a, b) abort
  let a_depth = s:path_depth(a:a)
  let b_depth = s:path_depth(a:b)

  if a_depth > b_depth
    return 1
  elseif a_depth < b_depth
    return -1
  endif

  let s = s:_length_cmp(a:a, a:b)
  if s != 0
    return s
  endif

  if a:a > a:b
    return 1
  elseif a:a < a:b
    return -1
  endif

  return 0
endfunction

" Sort
" 1. By first module component length
" 2. By module depth, then length, then alphabetically
function! s:sort_imports(imports) abort
  let groups = {}
  for imp in a:imports
    let groupname = matchstr(imp, '^\.\?[^\.]*\ze')
    let remainder = matchstr(imp, '^\.\?[^\.]*\zs.*')
    if !has_key(groups, groupname)
      let groups[groupname] = []
    endif
    call add(groups[groupname], remainder)
  endfor

  let out = []
  for groupname in sort(keys(groups), 's:_length_cmp')
    let import_group = map(copy(groups[groupname]), 'groupname . v:val')
    call extend(out, sort(import_group, 's:_module_cmp'))
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


" Sort the imports in a line range.  This will remove non-import lines.
function! s:sort_range(line1, line2) abort
  call s:init()

  let line_indent = indent(nextnonblank(a:line1))
  let prefix = repeat(' ', line_indent)
  let lead = 0

  let prev = prevnonblank(a:line1 - 1)
  let prevtext = getline(prev)
  if prev > 1 || prevtext =~# '^\s*\<\%(import\|from\)\>'
    if indent(prev) > line_indent || (indent(prev) == line_indent && prevtext !~# '^\s*#\|\%(''''''\|"""\)$')
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
    for import in s:sort_imports(imports[placement]['import'])
      call add(import_lines, prefix.'import '.import)
    endfor

    if len(imports[placement]['import'])
      call add(import_lines, '')
    endif

    for import in s:sort_imports(keys(imports[placement]['from']))
      if !has_key(imports[placement]['from'], import)
        continue
      endif
      let from_line = prefix.'from '.import.' import '
      let from_imports = join(sort(imports[placement]['from'][import]), ', ')
      let from_line .= s:wrap_imports(from_imports, len(from_line))
      call extend(import_lines, split(from_line, "\n"))
    endfor

    if len(imports[placement]['from'])
      call add(import_lines, '')
    endif
  endfor

  let nextline = nextnonblank(a:line2 + 1)
  if len(import_lines) && (!nextline || getline(nextline) =~# '^except ImportError')
    let import_lines = import_lines[:-2]
  endif

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
function! impsort#sort(line1, line2) abort
  if &l:filetype !~# 'python'
    echohl ErrorMsg
    echo 'Buffer is not Python'
    echohl None
    return
  endif

  let saved = winsaveview()

  if a:line2 > a:line1
    let r1 = s:prevline(a:line1)
    let r2 = s:nextline(a:line2)
    call s:sort_range(r1, r2)
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
