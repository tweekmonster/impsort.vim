# impsort.vim

Vim utility for sorting and highlighting Python imports.

![impsort](https://cloud.githubusercontent.com/assets/111942/16569183/4889178c-4201-11e6-8a05-917a084f10bd.gif)

## Installation

Any modern plugin manager will work.  If you are installing manually, you will
have to run `git submodule update --init` since [Jedi][] is included as a
submodule.

## Usage

```vim
:ImpSort[!]
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

The sorting method is configurable.  Be sure to read [`:h impsort`][doc]!

There is another command `:ImpSortAuto` which will automatically sort imports
on `InsertLeave`.  **Definitely** read [`:h impsort`][doc] if this
interests you.

### Highlighting

By default, imported objects will be highlighted.  If your version of Vim is
capable of asynchronous calls (Neovim and Vim 8), the highlighting will
distinguish imported classes and functions.  You can read about customizing the
colors in the [documentation][doc].

## Rationale

I wanted to be able to keep my import lines organized, but didn't want to spend
the time sorting them by hand.  Using this plugin, you can add a new import and
let the sort do its thing.

I also wanted something more forgiving than [isort][].  This plugin will not
move imports out of their original placement in the script.  For example:

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

[doc]: doc/impsort.txt
[Jedi]: https://github.com/davidhalter/jedi
[isort]: https://github.com/timothycrosley/isort/
