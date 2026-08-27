local build = require("lde-build")

local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"
local libName = isWindows and "deflate.dll" or (isMac and "libdeflate.dylib" or "libdeflate.so")

local url = "https://github.com/ebiggers/libdeflate/releases/download/v1.25/libdeflate-1.25.tar.gz"
local tarball = "libdeflate-1.25.tar.gz"

local content = build:fetch(url)
build:write(tarball, content)
build:extract(tarball, ".")
build:move("libdeflate-1.25", "libdeflate")

local srcDir = build.outDir .. "/libdeflate"
local buildDir = srcDir .. "/build"

build:sh('cmake -S "' .. srcDir .. '" -B "' .. buildDir .. '" -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON')
build:sh('cmake --build "' .. buildDir .. '" --parallel')

if isWindows then
	-- libdeflate's cmake target names the shared library libdeflate.dll.
	-- Multi-config generators (Ninja Multi-Config, Visual Studio) emit it under
	-- build/Release/; single-config ones (MinGW Makefiles) under build/.
	local dll = build:exists("libdeflate/build/Release/libdeflate.dll")
		and "libdeflate/build/Release/libdeflate.dll"
		or "libdeflate/build/libdeflate.dll"
	build:copy(dll, libName)
else
	build:copy("libdeflate/build/" .. libName, libName)
	local stripFlags = isMac and "-x" or "--strip-unneeded"
	build:sh('strip ' .. stripFlags .. ' "' .. build.outDir .. '/' .. libName .. '"')
end
