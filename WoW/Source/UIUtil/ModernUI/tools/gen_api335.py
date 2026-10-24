# Builds api_335.json, the inventory of what the 3.3.5 interface has, which gen_modern_frames.py and
# gen_blizzard_stubs.py take: the 3.3.5 interface's global Lua names, named frames and templates (from
# github.com/wowgaming/3.3.5-interface-files), and this client's C Lua functions (from the source's
# registration tables). Reproduces 35_ModernFrameNames.lua and 97_BlizzardFunctionStubs.lua exactly.
# Usage: python3 gen_api335.py <3.3.5 interface dir> <out.json> [<repo root>]
import re, glob, json, sys, os
root = sys.argv[1]
g, frames, templates = set(), set(), set()
for f in glob.glob(root + '/**/*.lua', recursive=True):
    t = open(f, errors='ignore').read()
    g.update(re.findall(r'^function\s+([A-Za-z_]\w*)\s*\(', t, re.M))
    g.update(re.findall(r'^([A-Za-z_]\w*)\s*=', t, re.M))
for f in glob.glob(root + '/**/*.xml', recursive=True):
    t = open(f, errors='ignore').read()
    for attrs in re.findall(r'<\w+\b([^>]*)>', t):
        m = re.search(r'\bname\s*=\s*"([A-Za-z_]\w*)"', attrs)
        if m:
            (templates if re.search(r'virtual\s*=\s*"true"', attrs) else frames).add(m.group(1))
repo = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../../..')
funcs = set()
for f in glob.glob(repo + '/**/*.cpp', recursive=True) + glob.glob(repo + '/**/*.h', recursive=True):
    funcs.update(re.findall(r'\{\s*"([A-Za-z_]\w*)"\s*,\s*&?Script_\w+', open(f, errors='ignore').read()))
json.dump({'ui_globals': sorted(g), 'ui_frames': sorted(frames), 'ui_templates': sorted(templates), 'functions': sorted(funcs)}, open(sys.argv[2], 'w'))
print(len(g), len(frames), len(templates))
