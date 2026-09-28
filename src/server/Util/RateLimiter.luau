--!strict
-- Per-player token bucket. `RateLimiter.new(perSecond, burst)` returns `allow(player) -> boolean`.

local Players = game:GetService("Players")

local RateLimiter = {}

function RateLimiter.new(perSecond: number, burst: number): (Player) -> boolean
	local buckets: { [Player]: { tokens: number, last: number } } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = burst, last = now }
			buckets[player] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * perSecond)
		bucket.last = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

return RateLimiter
