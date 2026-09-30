--!strict
-- Grey-box building helpers shared by the zone and the tutorial cove.

local Geometry = {}

-- Walls, floors and ceilings are this thick.
Geometry.WALL = 2

-- Rotates a panel to lie flat (thickness along world Y).
Geometry.FLAT = CFrame.Angles(math.rad(90), 0, 0)

function Geometry.block(parent: Instance, cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Slate
	part.Color = Color3.fromRGB(90, 96, 100)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Flat panel: local X = width, local Y = height, local Z = thickness. Optional centered hole.
-- Returns the parts, so callers can restyle them.
function Geometry.panel(
	parent: Instance,
	cframe: CFrame,
	width: number,
	height: number,
	holeWidth: number,
	holeHeight: number
): { Part }
	local wall = Geometry.WALL
	if holeWidth <= 0 then
		return { Geometry.block(parent, cframe, Vector3.new(width, height, wall)) }
	end
	local sideWidth = (width - holeWidth) / 2
	local capHeight = (height - holeHeight) / 2
	local sideX = (holeWidth + sideWidth) / 2
	local capY = (holeHeight + capHeight) / 2
	return {
		Geometry.block(parent, cframe * CFrame.new(-sideX, 0, 0), Vector3.new(sideWidth, height, wall)),
		Geometry.block(parent, cframe * CFrame.new(sideX, 0, 0), Vector3.new(sideWidth, height, wall)),
		Geometry.block(parent, cframe * CFrame.new(0, capY, 0), Vector3.new(holeWidth, capHeight, wall)),
		Geometry.block(parent, cframe * CFrame.new(0, -capY, 0), Vector3.new(holeWidth, capHeight, wall)),
	}
end

-- Four walls around a vertical square shaft of inner width `size`, from bottomY to topY.
function Geometry.shaft(parent: Instance, center: Vector3, size: number, bottomY: number, topY: number)
	local height = topY - bottomY
	local wall = Geometry.WALL
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local wallCenter = Vector3.new(center.X, (bottomY + topY) / 2, center.Z) + dir * (size / 2 + wall / 2)
		Geometry.panel(parent, CFrame.lookAt(wallCenter, wallCenter + dir), size + wall * 2, height, 0, 0)
	end
end

-- Climbable TrussPart from bottomY to topY at `position` (X/Z). TrussPart sizes snap to
-- multiples of 2, so the height is rounded up to an even number.
function Geometry.ladder(parent: Instance, position: Vector3, bottomY: number, topY: number): TrussPart
	local height = math.ceil((topY - bottomY) / 2) * 2
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, height, 2)
	ladder.CFrame = CFrame.new(position.X, bottomY + height / 2, position.Z)
	ladder.Color = Color3.fromRGB(230, 180, 40)
	ladder.Parent = parent
	return ladder
end

return Geometry
