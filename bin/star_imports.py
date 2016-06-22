#!/usr/bin/env python
"""Very simple AST parser to get star imports.  Nothing more.
"""
import os
import ast
import imp
import sys

from importlib import import_module

try:
    str_ = unicode  # noqa F821
except:
    str_ = str

modules_seen = set()
import_names = set()


class NodeVisitor(ast.NodeVisitor):
    using_all = False
    names = set()
    imports = []

    def iterable_values(self, node):
        if not hasattr(node, 'elts'):
            return []

        values = []
        types = (ast.Str,)
        if hasattr(ast, 'Bytes'):
            types += (ast.Bytes,)
        for item in node.elts:
            if isinstance(item, types):
                values.append(str_(item.s))
        return values

    def add_name(self, name):
        if name and not self.using_all and name[0] != '_':
            self.names.add(name)

    def visit_Import(self, node):
        for n in node.names:
            self.add_name(n.asname or n.name)
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        module = '%s%s' % ('.' * node.level, str_(node.module or ''))
        for n in node.names:
            if n.name == '*':
                if module not in self.imports:
                    self.imports.append(module)
            else:
                self.add_name(n.asname or n.name)
        self.generic_visit(node)

    def visit_Assign(self, node):
        for t in node.targets:
            if not isinstance(t.ctx, ast.Store):
                continue

            if isinstance(t, ast.Name):
                if t.id == '__all__':
                    self.names.clear()
                    self.using_all = True
                    self.names.update(self.iterable_values(node.value))
                else:
                    self.add_name(t.id)
            elif isinstance(t, ast.Tuple):
                for item in t.elts:
                    self.add_name(item.id)
        self.generic_visit(node)

    def visit_AugAssign(self, node):
        if isinstance(node.op, ast.Add) and node.target.id == '__all__':
            self.names.update(self.iterable_values(node.value))

    def visit_FunctionDef(self, node):
        # Don't visit the function body
        self.add_name(node.name)

    def visit_ClassDef(self, node):
        # Don't visit the class body
        self.add_name(node.name)

    def visit_Try(self, node):
        for item in node.body:
            self.visit(item)
        for item in node.finalbody:
            self.visit(item)
        for handler in node.handlers:
            if handler.type.id == 'ImportError':
                # Only care about collecting names that would be imported
                for item in handler.body:
                    self.visit(item)


def simple_parse(source_file, module):
    if module.split('.')[0] in sys.builtin_module_names:
        try:
            imported = import_module(module)
            if hasattr(imported, '__all__'):
                import_names.update(imported.__all__)
            else:
                import_names.update(x for x in dir(imported) if x[0] != '_')
        except ImportError:
            pass
        return

    if module in modules_seen:
        return

    modules_seen.add(module)
    visitor = NodeVisitor()

    try:
        file = None
        last_path = None
        if module[0] == '.':
            module_tmp = module.lstrip('.')
            p = source_file
            for _ in range(len(module) - len(module_tmp)):
                p = os.path.dirname(p)
            last_path = [p]
            module = module_tmp

        for module in module.split('.'):
            if file is not None:
                file.close()
            file, path, desc = imp.find_module(module, last_path)
            if path:
                last_path = [path]

        if desc[2] == imp.PKG_DIRECTORY:
            for suffix, _, _ in imp.get_suffixes():
                init_path = os.path.join(path, '__init__%s' % suffix)
                if os.path.exists(init_path):
                    file = open(init_path, 'rb')
                    path = init_path
                    break
        if not file:
            return
    except ImportError:
        return

    try:
        root = ast.parse(file.read())
        visitor.visit(root)
    except (SyntaxError, IndentationError):
        return
    finally:
        import_names.update(visitor.names)

        for module in visitor.imports:
            simple_parse(path, module)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        for arg in sys.argv[2:]:
            simple_parse(sys.argv[1], arg)

        for name in sorted(import_names):
            print(name)
