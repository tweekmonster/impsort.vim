# impsort.vim

Vim utility for sorting Python imports.

## Usage

```vim
:ImpSort
```

The `ImpSort` command accepts a range and can be used with visual selections.

## Rationale

This plugin is more forgiving than [isort][] and it will not move imports out
of their defined "regions".  For example:

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

[isort]: https://github.com/timothycrosley/isort/
