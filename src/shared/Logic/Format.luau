--!strict
-- Display formatting shared by server boards and client UI. Pure, so it's unit-tested.

local Format = {}

-- 999 -> "999", 1234 -> "1.2K", 12345 -> "12.3K", 1250000 -> "1.3M". Never shows ".0".
function Format.compact(n: number): string
	if math.abs(n) < 1000 then
		return tostring(math.floor(n))
	end
	-- Smallest unit first; if rounding reaches 1000 of it (999950 -> 1000.0K), step up.
	local units: { { size: number, suffix: string } } =
		{ { size = 1e3, suffix = "K" }, { size = 1e6, suffix = "M" }, { size = 1e9, suffix = "B" } }
	for i, unit in units do
		local value = math.floor(n / unit.size * 10 + 0.5) / 10
		if math.abs(value) < 1000 or i == #units then
			local text = if value == math.floor(value)
				then tostring(math.floor(value))
				else string.format("%.1f", value)
			return text .. unit.suffix
		end
	end
	return tostring(n)
end

-- 4500 -> "4,500", 1234567 -> "1,234,567", -250 -> "-250".
function Format.thousands(n: number): string
	local digits = tostring(math.floor(math.abs(n)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if n < 0 then "-" .. out else out
end

-- Coin counter text: exact up to 999,999, compact above.
function Format.coins(n: number): string
	return if math.abs(n) < 1e6 then Format.thousands(n) else Format.compact(n)
end

return Format
