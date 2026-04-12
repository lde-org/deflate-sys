local outDir = os.getenv("LDE_OUTPUT_DIR")
local sep = string.sub(package.config, 1, 1)
local isWindows = sep == "\\"
local isMac = not isWindows and io.popen("uname"):read("*l") == "Darwin"
local isAndroid = os.getenv("ANDROID_ROOT") ~= nil
local scriptDir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
local src = scriptDir .. "vendor" .. sep .. "libdeflate"
local buildDir = src .. sep .. "build"
local libName = isWindows and "deflate.dll" or isMac and "libdeflate.dylib" or "libdeflate.so"
local outLib = outDir .. sep .. libName

-- skip if already built
if io.open(outLib, "rb") then return end

local function exec(cmd)
    local ret = os.execute(cmd)
    assert(ret == 0 or ret == true, "command failed: " .. cmd)
end

if isWindows then
    exec('cmake -S "' .. src .. '" -B "' .. buildDir .. '" -DBUILD_SHARED_LIBS=ON')
    exec('cmake --build "' .. buildDir .. '" --config Release --parallel')
    exec('copy "' .. buildDir .. '\\Release\\deflate.dll" "' .. outLib .. '"')
else
    local ndkRoot = os.getenv("ANDROID_NDK_ROOT")
    local cmakeExtra = ""

    if isAndroid and ndkRoot then
        local toolchain = ndkRoot .. "/toolchains/llvm/prebuilt/linux-aarch64"
        cmakeExtra = ' -DCMAKE_TOOLCHAIN_FILE="' .. ndkRoot .. '/build/cmake/android.toolchain.cmake"' ..
            ' -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24' ..
            ' -DCMAKE_ANDROID_NDK="' .. ndkRoot .. '"'
    end

    exec('cmake -S "' .. src .. '" -B "' .. buildDir .. '" -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release' .. cmakeExtra)
    exec('cmake --build "' .. buildDir .. '" --parallel')
    exec('cp "' .. buildDir .. '/' .. libName .. '" "' .. outLib .. '"')

    local strip = (isAndroid and ndkRoot) and (ndkRoot .. "/toolchains/llvm/prebuilt/linux-aarch64/bin/llvm-strip") or "strip"
    exec(strip .. ' "' .. outLib .. '"')
end
