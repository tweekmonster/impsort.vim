#!/usr/bin/env python
"""Relevant information for impsort.vim"""
import os
import sys
import sysconfig

from glob import glob

config = sysconfig.get_config_vars()

# The suffix for extension modules
print('ext_suffix=%s' % config.get('EXT_SUFFIX', config.get('SO', '.so')))

# List of built-in modules that won't appear in the filesystem
print('builtins=%s' % ':'.join(sys.builtin_module_names))

paths = [x for x in sys.path[1:] if os.path.exists(x)]
if 'VIRTUAL_ENV' in os.environ:
    for path in glob(os.path.join(os.environ['VIRTUAL_ENV'],
                                  'lib/python*/site-packages')):
        if path not in sys.path:
            paths.append(path)

# Import paths
print('paths=%s' % ':'.join(paths))
