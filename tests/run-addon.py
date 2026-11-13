#!/usr/bin/env python3
"""Run the headless Lua addon checks with the installed system Lua library."""
import ctypes
import ctypes.util
from pathlib import Path

root = Path(__file__).resolve().parent.parent
library = next((path for name in ("lua5.4", "lua5.3") if (path := ctypes.util.find_library(name))), None)
if not library:
    raise SystemExit("Install Lua 5.3 or 5.4 to run the addon checks.")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
try:
    for file in (root / "AuctioNitro").rglob("*.lua"):
        if lua.luaL_loadfilex(state, str(file).encode(), None):
            raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
        lua.lua_settop(state, 0)
    import os
    os.chdir(root)
    if lua.luaL_loadfilex(state, b"tests/addon.lua", None) or lua.lua_pcallk(state, 0, 0, 0, 0, None):
        raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
