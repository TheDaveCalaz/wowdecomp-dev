-- ModernUI: built into the client (not in the original 3.3.5a).
-- ModelScene frames and their actors, on this client's PlayerModel. A modern ModelScene holds actors (models
-- placed in one 3D scene); here each actor is a PlayerModel the size of its scene, which shows the same unit,
-- creature or file. Placement in the scene (position, yaw, scale, animation) is passed on where a PlayerModel
-- can show it. Every other documented method of scenes and actors exists and does nothing.

local _G = _G
local type, pairs, pcall, rawget = type, pairs, pcall, rawget

local function documented(group, into)
	local docs = rawget(_G, "ModernUI_ObjectMethodDocs")
	local answerFor = rawget(_G, "ModernUI_SurfaceAnswerFor")
	if type(docs) == "table" and answerFor then
		for name, rets in pairs(docs[group] or {}) do
			if into[name] == nil then
				into[name] = answerFor(rets)
			end
		end
	end
	return into
end

local Actor = {}
function Actor:SetModelByUnit(unit)
	self:SetUnit(unit)
	if self.onModelLoadedCallback then
		pcall(self.onModelLoadedCallback, self)
	end
	return true
end
function Actor:SetModelByCreatureDisplayID(displayID)
	if self.SetDisplayInfo then
		self:SetDisplayInfo(displayID)
	elseif self.SetCreature then
		self:SetCreature(displayID)
	end
	return true
end
function Actor:SetModelByFileID(file)
	if type(file) == "string" then
		self:SetModel(file)
	end
	return true
end
Actor.SetModelByPath = Actor.SetModelByFileID
function Actor:ClearModel() self:ClearModel_335() end
function Actor:SetYaw(yaw) self.actorYaw = yaw or 0 self:SetFacing(self.actorYaw) end
function Actor:GetYaw() return self.actorYaw or 0 end
function Actor:SetScale(scale) self.actorScale = scale or 1 if self.SetModelScale then self:SetModelScale(self.actorScale) end end
function Actor:GetScale() return self.actorScale or 1 end
function Actor:SetPosition(x, y, z) self.actorX, self.actorY, self.actorZ = x or 0, y or 0, z or 0 end
function Actor:GetPosition() return self.actorX or 0, self.actorY or 0, self.actorZ or 0 end
function Actor:IsLoaded() return true end
function Actor:GetActiveBoundingBox() return 0, 0, 0, 1, 1, 2 end
function Actor:GetMaxBoundingBox() return 0, 0, 0, 1, 1, 2 end

local Scene = {}
function Scene:CreateActor(name, template)
	local ok, actor = pcall(CreateFrame, "PlayerModel", name, self)
	if not ok or not actor then
		return nil
	end
	actor:SetAllPoints(self)
	actor.ClearModel_335 = actor.ClearModel
	for k, v in pairs(Actor) do
		actor[k] = v
	end
	documented("FrameAPIModelSceneFrameActor", actor)
	documented("FrameAPIModelSceneFrameActorBase", actor)
	self.modernActors = self.modernActors or {}
	self.modernActors[#self.modernActors + 1] = actor
	return actor
end
function Scene:GetNumActors() return self.modernActors and #self.modernActors or 0 end
function Scene:GetActorAtIndex(index) return self.modernActors and self.modernActors[index] end
function Scene:ReleaseAllActors()
	for _, actor in ipairs(self.modernActors or {}) do
		actor:Hide()
	end
	self.modernActors = {}
end

function ModernUI_DecorateModelScene(frame)
	for k, v in pairs(Scene) do
		if frame[k] == nil then
			frame[k] = v
		end
	end
	documented("FrameAPIModelSceneFrame", frame)
	return frame
end
