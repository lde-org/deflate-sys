local test = require("lde-test")
local deflate = require("deflate-sys")

-- helpers
local function roundtrip(compress, decompress, data, level)
	local compressed = compress(data, level)
	local decompressed = decompress(compressed, #data * 4 + 64)
	return compressed, decompressed
end

-- zlib

test.it("zlibCompress produces smaller output for compressible data", function()
	local data = string.rep("aaaaaaaaaa", 100)
	local compressed = deflate.zlibCompress(data)
	test.truthy(#compressed < #data)
end)

test.it("zlib roundtrip returns original data", function()
	local data = "Hello, libdeflate!"
	local _, result = roundtrip(deflate.zlibCompress, deflate.zlibDecompress, data)
	test.equal(result, data)
end)

test.it("zlib roundtrip works for binary data", function()
	local data = ""
	for i = 0, 255 do data = data .. string.char(i) end
	local _, result = roundtrip(deflate.zlibCompress, deflate.zlibDecompress, data)
	test.equal(result, data)
end)

test.it("zlib roundtrip works at each compression level", function()
	local data = string.rep("the quick brown fox jumps over the lazy dog ", 20)
	for level = 1, 12 do
		local _, result = roundtrip(deflate.zlibCompress, deflate.zlibDecompress, data, level)
		test.equal(result, data)
	end
end)

-- gzip

test.it("gzip roundtrip returns original data", function()
	local data = "Hello, gzip!"
	local _, result = roundtrip(deflate.gzipCompress, deflate.gzipDecompress, data)
	test.equal(result, data)
end)

test.it("gzip output starts with gzip magic bytes", function()
	local compressed = deflate.gzipCompress("test")
	test.equal(compressed:byte(1), 0x1f)
	test.equal(compressed:byte(2), 0x8b)
end)

-- deflate (raw)

test.it("deflate roundtrip returns original data", function()
	local data = "Hello, raw deflate!"
	local _, result = roundtrip(deflate.deflateCompress, deflate.deflateDecompress, data)
	test.equal(result, data)
end)

-- empty input

test.it("zlib handles empty string", function()
	local _, result = roundtrip(deflate.zlibCompress, deflate.zlibDecompress, "")
	test.equal(result, "")
end)

test.it("gzip handles empty string", function()
	local _, result = roundtrip(deflate.gzipCompress, deflate.gzipDecompress, "")
	test.equal(result, "")
end)

-- checksums

test.it("crc32 of empty data is 0", function()
	test.equal(deflate.crc32(""), 0)
end)

test.it("crc32 produces known value for 'hello'", function()
	-- known CRC-32 of "hello" = 0x3610a686
	test.equal(deflate.crc32("hello"), 0x3610a686)
end)

test.it("crc32 is composable via init parameter", function()
	local full = deflate.crc32("helloworld")
	local partial = deflate.crc32("world", deflate.crc32("hello"))
	test.equal(partial, full)
end)

test.it("adler32 of empty data is 1", function()
	test.equal(deflate.adler32(""), 1)
end)

test.it("adler32 produces known value for 'hello'", function()
	-- known Adler-32 of "hello" = 0x062c0215
	test.equal(deflate.adler32("hello"), 0x062c0215)
end)

test.it("adler32 is composable via init parameter", function()
	local full = deflate.adler32("helloworld")
	local partial = deflate.adler32("world", deflate.adler32("hello"))
	test.equal(partial, full)
end)

-- error handling

test.it("zlibDecompress errors on bad data", function()
	local ok, err = pcall(deflate.zlibDecompress, "not valid zlib data", 1024)
	test.equal(ok, false)
	test.truthy(err:find("bad data") or err:find("libdeflate"))
end)
