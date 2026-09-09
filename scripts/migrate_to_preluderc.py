#!/usr/bin/env python3
"""One-time migration; Python 3.11+. Does not execute scripts or overwrite input."""
import sys, tomllib, shlex
from pathlib import Path

def convert(text):
    document = tomllib.loads(text)
    leader = document.get('leader', {'key':'space', 'modifiers':['control']})
    lines = ['# Prelude · @ 分组，@@ 子分组，# 独占一行写注释。']
    if leader != {'key':'space', 'modifiers':['control']}:
        lines.append('!leader ' + '+'.join(leader['modifiers'] + [leader['key']]))
    def visit(nodes, ancestors):
        context = list(ancestors)
        for node in nodes:
            key, name = node['key'], node['name']
            if key in '@#' or any(c in name for c in '\r\n:'):
                raise ValueError('Reserved key or name delimiter; migrate manually: ' + name)
            if 'action' in node:
                if context != ancestors:
                    if ancestors:
                        lines.extend(['', '@' * len(ancestors) + ' ' + ancestors[-1]])
                    else: lines.extend(['', '@'])
                    context = list(ancestors)
                script = node['action']
                if script == 'open -t "$HOME/.config/prelude/config.toml"':
                    script = 'open -t "$HOME/.config/prelude/preluderc"'
                if '\n' in script or '\r' in script:
                    # Encode newlines with zsh ANSI-C quoting, keeping the DSL single-line.
                    escaped = script.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('\r', '\\r')
                    script = "/bin/zsh -f -c $'" + escaped + "'"
                lines.append(f'{key} - {name} : {script}')
            else:
                lines.extend(['', '@' * (len(ancestors) + 1) + f' {key} - {name}', ''])
                visit(node['children'], ancestors + [key])
                context = ancestors + [key]
    visit(document['keys'], [])
    return '\n'.join(lines).rstrip() + '\n'

if __name__ == '__main__':
    source, destination = map(Path, sys.argv[1:])
    result = convert(source.read_text())
    with destination.open('x') as output: output.write(result)
