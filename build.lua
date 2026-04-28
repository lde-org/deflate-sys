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

if isWindows then
	build:sh('cmake -S "' .. srcDir .. '" -B "' .. buildDir .. '" -DBUILD_SHARED_LIBS=ON')
	build:sh('cmake --build "' .. buildDir .. '" --config Release --parallel')
	build:copy("libdeflate/build/Release/deflate.dll", libName)
else
	build:sh('cmake -S "' .. srcDir .. '" -B "' .. buildDir .. '" -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release')
	build:sh('cmake --build "' .. buildDir .. '" --parallel')
	build:copy("libdeflate/build/" .. libName, libName)
	local stripFlags = isMac and "-x" or "--strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr"
	build:sh('strip ' .. stripFlags .. ' "' .. build.outDir .. '/' .. libName .. '"')
end
