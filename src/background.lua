local function Background()
	if clientstate:GetNetChannel() then
		Players = entities.FindByClass("CTFPlayer")
		Sentries = entities.FindByClass("CObjectSentrygun")
		Dispensers = entities.FindByClass("CObjectDispenser")
		Teleporters = entities.FindByClass("CObjectTeleporter")
	else
		Players, Sentries, Dispensers, Teleporters = nil, nil, nil, nil
	end
end

callbacks.Register("CreateMove", "CM garlic bread background", Background)
