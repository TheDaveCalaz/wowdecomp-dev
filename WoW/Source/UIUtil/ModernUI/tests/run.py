# Loads every ModernUI file into Lua 5.1 with a mock 3.3.5 environment, then runs test.lua.
# Needs: pip install lupa.   Usage: python3 run.py test.lua
import glob, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
from lupa import lua51
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute(open(HERE + '/mock.lua').read())
missing = set()
L.globals()['_note'] = lambda k: missing.add(k)
L.execute('setmetatable(_G, {__index = function(t, k) _note(k) return nil end})')
for f in sorted(glob.glob(HERE + '/../*.lua')):
    r = L.execute('local f, e = loadstring(...) if not f then return false, e end local ok, err = pcall(f) return ok, tostring(err)', open(f).read()); ok, err = r if isinstance(r, tuple) else (r, None)
    print(('OK   ' if ok else 'FAIL ') + f.split('/')[-1] + ('' if ok else '  ' + str(err)))
print('globals read at load time but missing:', sorted(missing))
L.execute('setmetatable(_G, nil)')
if len(sys.argv) > 1:
    L.execute(open(sys.argv[1]).read())
