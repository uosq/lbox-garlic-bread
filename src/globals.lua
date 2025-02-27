GB_GLOBALS = {
	bIsStacRunning = false,

	bIsAimbotShooting = false,
	nAimbotTarget = nil,

	bWarping = false,
	bRecharging = false,

	flCustomFOV = 90,
	nPreAspectRatio = 0,
	nAspectRatio = 1.78,

	bNoRecoil = true,

	bBhopEnabled = false,

	bSpectated = false,
}

callbacks.Register("Unload", "UNLOAD garlic bread globals", function ()
	GB_GLOBALS = nil
end)