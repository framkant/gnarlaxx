#!/usr/bin/env python3
"""Build the Zig game without downloading dependencies or changing system tools."""
import argparse
import os
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--debug', action='store_true')
p.add_argument('--test', action='store_true')
p.add_argument('--zig', help='compiler executable; default: PATH, then the project-local Zig 0.17.0')
args = p.parse_args()
zig = args.zig or shutil.which('zig') or str(root/'build/zig/toolchain/zig-aarch64-macos-0.17.0/zig')
if not Path(zig).is_file():
    p.error('Zig is missing; install Zig 0.17.0 or pass --zig PATH (see implementations/zig/README.md)')
zig = str(Path(zig).resolve())
version = subprocess.check_output([zig, 'version'], text=True).strip()
if version != '0.17.0':
    p.error('This port is pinned to Zig 0.17.0; found ' + version)
profile = 'debug' if args.debug else 'release'
command = [zig, 'build', 'install'] + (['test'] if args.test else [])
if args.test:
    command += ['--summary', 'all']
command += ['-Doptimize=' + ('debug' if args.debug else 'safe'),
            '--prefix', str(root/'build/zig'/profile)]
environment = os.environ.copy()
environment['ZIG_GLOBAL_CACHE_DIR'] = str(root/'build/zig/global-cache')
environment['ZIG_LOCAL_CACHE_DIR'] = str(root/'build/zig/cache')
subprocess.run(command, cwd=root, env=environment, check=True)
print('Built {}'.format(root/'build/zig'/profile/'bin/gnarlaxx'))
