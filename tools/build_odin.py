#!/usr/bin/env python3
"""Build the Odin game and its shared native dependencies, without downloads."""
import argparse
import os
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--debug', action='store_true', help='enable debug info and Sokol validation')
parser.add_argument('--test', action='store_true', help='also run the Odin tests')
parser.add_argument('--odin', default='odin', help='compiler executable (default: odin from PATH)')
parser.add_argument('--library-path', help='macOS compiler library search path, if the installed LLVM links are mismatched')
args = parser.parse_args()
profile = 'debug' if args.debug else 'release'
out = root / 'build/odin' / profile
native = out / 'native'
out.mkdir(parents=True, exist_ok=True)

def run(command):
    environment = os.environ.copy()
    if command[0] == args.odin and args.library_path:
        environment['DYLD_LIBRARY_PATH'] = args.library_path
    subprocess.run([str(part) for part in command], cwd=root, env=environment, check=True)

run(['cmake', '-S', root, '-B', native, '-DCMAKE_BUILD_TYPE=' + ('Debug' if args.debug else 'Release'), '-DBUILD_TESTING=OFF'])
run(['cmake', '--build', native, '--target', 'sokol_odin', 'gnarlaxx_audio', 'decoders', '-j', '4'])
config = {
    'GNARLAXX_SOKOL_LIB': Path('../../..') / native.relative_to(root) / 'libsokol_odin.a',
    'GNARLAXX_AUDIO_LIB': Path('../../..') / native.relative_to(root) / 'libs/audio/libgnarlaxx_audio.a',
    'GNARLAXX_IMAGE_LIB': Path('../../..') / native.relative_to(root) / 'libdecoders.a',
    'GNARLAXX_ASSET_ROOT': root / 'assets',
    'GNARLAXX_TRACK_MEMORY': 'true' if args.debug else 'false',
}
def defines(values):
    return ['-define:{}={}'.format(key, value) for key, value in values.items()]

optimization = ['-debug'] if args.debug else ['-o:speed']
flags = defines(config) + optimization
# Bounds checks remain enabled in both builds.
run([args.odin, 'build', 'implementations/odin', '-out:' + str(out / 'gnarlaxx')] + flags)
if args.test:
    for package in ('game', 'scores', 'audio', 'app'):
        test_config = {}
        if package == 'scores':
            test_config['GNARLAXX_TEST_DIR'] = out
        if package == 'audio':
            test_config = {key: config[key] for key in ('GNARLAXX_AUDIO_LIB', 'GNARLAXX_ASSET_ROOT')}
        if package == 'app':
            test_config = config
        source = 'implementations/odin' + ('/' + package if package != 'app' else '')
        run([args.odin, 'test', source,
             '-out:' + str(out / (package + '-tests')),
             '-define:ODIN_TEST_THREADS=1', '-define:ODIN_TEST_FANCY=false'] + defines(test_config) + optimization)
print('Built {}'.format(out / 'gnarlaxx'))
