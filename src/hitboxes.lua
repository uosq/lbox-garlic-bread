--[[
Hitboxes i'll use:
Head, center, left leg, right leg, left arm, right arm
im fucked
--]]

local CLASS_HITBOXES = {
	--[[scout]]
	[1] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[soldier]]
	[3] = {
		--[[HeadUpper =]]
		6, -- 32,
		--[[Head =]]
		32, -- 6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[[pyro]]
	[7] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		16,
		--[[RightLeg =]]
		20,
		--[[LeftArm =]]
		9,
		--[[RightArm =]]
		13,
	},

	--[[demoman]]
	[4] = {
		--[[Head =]]
		16,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		12,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		14,
	},

	--[[heavy]]
	[6] = {
		--[[Head =]]
		6,
		--[[Body =]]
		3,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[engi]]
	[9] = {
		--[[HeadUpper =]]
		8, --61,
		--[[Head =]]
		61, --8,
		--[[Body =]]
		4,
		--[[LeftLeg =]]
		10,
		--[[RightLeg =]]
		2,
		--[[LeftArm =]]
		13,
		--[[RightArm =]]
		16,
	},

	--[[medic]]
	[5] = {
		--[[HeadUpper =]]
		6, --33,
		--[[Head =]]
		33, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[sniper]]
	[2] = {
		--[[HeadUpper =]]
		6, --23,
		--[[Head =]]
		23, --6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		15,
		--[[RightLeg =]]
		16,
		--[[LeftArm =]]
		11,
		--[[RightArm =]]
		12,
	},

	--[[spy]]
	[8] = {
		--[[Head =]]
		6,
		--[[Body =]]
		2,
		--[[LeftLeg =]]
		18,
		--[[RightLeg =]]
		19,
		--[[LeftArm =]]
		12,
		--[[RightArm =]]
		13,
	},
}

return CLASS_HITBOXES
