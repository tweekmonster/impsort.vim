# impsort.vim

Vim utility for sorting Python imports.

![impsort](https://cloud.githubusercontent.com/assets/111942/16103355/d349f94c-3345-11e6-8077-07c8f4ced343.gif)

## Installation

Any modern plugin manager will work.

## Usage

```vim
:ImpSort
```

The `:ImpSort` command accepts a range and can be used with visual selections.
Using `:Impsort!` (with bang) will separate `from ... import` groups with a
blank line.

You could also have it sort on save:

```vim
autocmd BufWritePre *.py ImpSort!
```

Or use a keymap:

```vim
nnoremap <leader>is :<c-u>ImpSort!<cr>
```

The sorting method is configurable.  Be sure to read [`:h impsort`](doc/impsort.txt)!

## Rationale

I wanted to be able to keep my import lines organized, but I didn't want to
spend the time to sort it by hand.  Using this plugin, you can add a new import
and let the sort do its thing.

I also wanted a more forgiving than [isort][].  This plugin will not move
imports out of their original placement in the script.  For example:

```python
import sys
import os

sys.path.insert(0, 'special/path')

import special
```

With `isort`:

```python
import os
import sys
import special

sys.path.insert(0, 'special/path')
```

With `impsort.vim`:

```python
import os
import sys

sys.path.insert(0, 'special/path')

import special
```

## License

The MIT License
Copyright (c) 2016 Tommy Allen

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[isort]: https://github.com/timothycrosley/isort/
