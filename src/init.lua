local ffi = require("ffi")

ffi.cdef [[
  struct libdeflate_compressor;
  struct libdeflate_decompressor;

  typedef enum {
    LIBDEFLATE_SUCCESS            = 0,
    LIBDEFLATE_BAD_DATA           = 1,
    LIBDEFLATE_SHORT_OUTPUT       = 2,
    LIBDEFLATE_INSUFFICIENT_SPACE = 3,
  } libdeflate_result;

  struct libdeflate_compressor *libdeflate_alloc_compressor(int compression_level);
  void libdeflate_free_compressor(struct libdeflate_compressor *compressor);

  size_t libdeflate_deflate_compress(struct libdeflate_compressor *compressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail);
  size_t libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor, size_t in_nbytes);

  size_t libdeflate_zlib_compress(struct libdeflate_compressor *compressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail);
  size_t libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor, size_t in_nbytes);

  size_t libdeflate_gzip_compress(struct libdeflate_compressor *compressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail);
  size_t libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor, size_t in_nbytes);

  struct libdeflate_decompressor *libdeflate_alloc_decompressor(void);
  void libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);

  libdeflate_result libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail, size_t *actual_out_nbytes_ret);
  libdeflate_result libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail, size_t *actual_out_nbytes_ret);
  libdeflate_result libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor, const void *in, size_t in_nbytes, void *out, size_t out_nbytes_avail, size_t *actual_out_nbytes_ret);

  uint32_t libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);
  uint32_t libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);
]]

local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or ""
local sep = string.sub(package.config, 1, 1)
local libName = sep == "\\" and "deflate.dll" or (jit.os == "OSX" and "libdeflate.dylib" or "libdeflate.so")
local lib = ffi.load(here .. libName)

local RESULT_NAMES = {
	[0] = "success",
	[1] = "bad data",
	[2] = "short output",
	[3] = "insufficient space"
}

local function resultError(code)
	error("libdeflate: " .. (RESULT_NAMES[tonumber(code)] or "unknown error (" .. tostring(code) .. ")"), 3)
end

--- @param fn fun(c: ffi.cdata*, inn: string, inN: number, out: ffi.cdata*, outN: number): number
--- @param boundFn fun(c: ffi.cdata*, inN: number): number
--- @param data string
--- @param level integer
--- @return string
local function doCompress(fn, boundFn, data, level)
	local c = lib.libdeflate_alloc_compressor(level)
	assert(c ~= nil, "libdeflate_alloc_compressor failed")
	local inLen = #data
	local bound = boundFn(c, inLen)
	local outBuf = ffi.new("uint8_t[?]", bound)
	local outLen = fn(c, data, inLen, outBuf, bound)
	lib.libdeflate_free_compressor(c)
	assert(outLen > 0, "libdeflate: compression failed (output size 0)")
	return ffi.string(outBuf, outLen)
end

--- @param fn fun(d: ffi.cdata*, inn: string, inN: number, out: ffi.cdata*, outN: number, actual: ffi.cdata*): number
--- @param data string
--- @param maxSize integer
--- @return string
local function doDecompress(fn, data, maxSize)
	local d = lib.libdeflate_alloc_decompressor()
	assert(d ~= nil, "libdeflate_alloc_decompressor failed")
	local outBuf = ffi.new("uint8_t[?]", maxSize)
	local actualOut = ffi.new("size_t[1]")
	local result = fn(d, data, #data, outBuf, maxSize, actualOut)
	lib.libdeflate_free_decompressor(d)
	if result ~= 0 then resultError(result) end
	return ffi.string(outBuf, actualOut[0])
end

--- Compress data using raw DEFLATE.
--- @param data string Input data
--- @param level? integer Compression level 1-12 (default 6)
--- @return string compressed
local function deflateCompress(data, level)
	return doCompress(lib.libdeflate_deflate_compress, lib.libdeflate_deflate_compress_bound, data, level or 6)
end

--- Decompress raw DEFLATE data.
--- @param data string Compressed input
--- @param maxSize integer Maximum decompressed size
--- @return string decompressed
local function deflateDecompress(data, maxSize)
	return doDecompress(lib.libdeflate_deflate_decompress, data, maxSize)
end

--- Compress data using zlib format (DEFLATE + zlib wrapper).
--- @param data string Input data
--- @param level? integer Compression level 1-12 (default 6)
--- @return string compressed
local function zlibCompress(data, level)
	return doCompress(lib.libdeflate_zlib_compress, lib.libdeflate_zlib_compress_bound, data, level or 6)
end

--- Decompress zlib-format data.
--- @param data string Compressed input
--- @param maxSize integer Maximum decompressed size
--- @return string decompressed
local function zlibDecompress(data, maxSize)
	return doDecompress(lib.libdeflate_zlib_decompress, data, maxSize)
end

--- Compress data using gzip format.
--- @param data string Input data
--- @param level? integer Compression level 1-12 (default 6)
--- @return string compressed
local function gzipCompress(data, level)
	return doCompress(lib.libdeflate_gzip_compress, lib.libdeflate_gzip_compress_bound, data, level or 6)
end

--- Decompress gzip-format data.
--- @param data string Compressed input
--- @param maxSize integer Maximum decompressed size
--- @return string decompressed
local function gzipDecompress(data, maxSize)
	return doDecompress(lib.libdeflate_gzip_decompress, data, maxSize)
end

--- Compute CRC-32 checksum.
--- @param data string Input data
--- @param init? integer Initial CRC value (default 0)
--- @return integer crc32
local function crc32(data, init)
	return tonumber(lib.libdeflate_crc32(init or 0, data, #data))
end

--- Compute Adler-32 checksum.
--- @param data string Input data
--- @param init? integer Initial Adler-32 value (default 1)
--- @return integer adler32
local function adler32(data, init)
	return tonumber(lib.libdeflate_adler32(init or 1, data, #data))
end

--- @class DeflateLib
--- @field deflateCompress fun(data: string, level?: integer): string
--- @field deflateDecompress fun(data: string, maxSize: integer): string
--- @field zlibCompress fun(data: string, level?: integer): string
--- @field zlibDecompress fun(data: string, maxSize: integer): string
--- @field gzipCompress fun(data: string, level?: integer): string
--- @field gzipDecompress fun(data: string, maxSize: integer): string
--- @field crc32 fun(data: string, init?: integer): integer
--- @field adler32 fun(data: string, init?: integer): integer
return {
	deflateCompress   = deflateCompress,
	deflateDecompress = deflateDecompress,
	zlibCompress      = zlibCompress,
	zlibDecompress    = zlibDecompress,
	gzipCompress      = gzipCompress,
	gzipDecompress    = gzipDecompress,
	crc32             = crc32,
	adler32           = adler32
}
