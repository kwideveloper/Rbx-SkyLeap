-- Handles platforms with attributes:
--  Breakable: boolean (true to enable)
--  TimeToDissapear: number seconds (fade-out duration)
--  TimeToAppear: number seconds (delay before reappear + fade-in duration)

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local function setupBreakable(part)
	if not part:GetAttribute("Breakable") then
		return
	end

	if part:GetAttribute("_BreakableWired") then
		return
	end
	part:SetAttribute("_BreakableWired", true)

	-- Persist original properties on the instance so clones always know true defaults
	if part:GetAttribute("OriginalSize") == nil then
		part:SetAttribute("OriginalSize", part.Size)
	end
	if part:GetAttribute("OriginalTransparency") == nil then
		part:SetAttribute("OriginalTransparency", part.Transparency)
	end
	if part:GetAttribute("OriginalCanCollide") == nil then
		part:SetAttribute("OriginalCanCollide", part.CanCollide)
	end
	if part:GetAttribute("OriginalAnchored") == nil then
		part:SetAttribute("OriginalAnchored", part.Anchored)
	end

	local originalTransparency = part:GetAttribute("OriginalTransparency") or part.Transparency
	local originalCanCollide = part:GetAttribute("OriginalCanCollide")
	if originalCanCollide == nil then
		originalCanCollide = part.CanCollide
	end
	local originalAnchored = part:GetAttribute("OriginalAnchored")
	if originalAnchored == nil then
		originalAnchored = part.Anchored
	end
	local originalParent = part.Parent
	local template = part:Clone()
	-- Ensure template isn't marked as already wired so respawns can rewire
	if template:GetAttribute("_BreakableWired") ~= nil then
		template:SetAttribute("_BreakableWired", nil)
	end

	local function tweenTransparency(target, duration)
		local tween = TweenService:Create(
			part,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = target }
		)
		tween:Play()
		tween.Completed:Wait()
	end

	local function stagedDisappearWhileTouched()
		local total = tonumber(part:GetAttribute("TimeToDissapear")) or 2
		local step = total / 5
		local thresholds = { step, step * 2, step * 3, step * 4, step * 5 }
		local targetTransparencyByStage = { 0, 0.3, 0.55, 0.9 }

		local progress = 0
		local stage = 0
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = {}
		overlapParams.RespectCanCollide = false
		-- Include everything and detect humanoids by ancestor

		local function hasHumanoidAncestor(inst)
			while inst and inst ~= workspace do
				local hum = inst:FindFirstChildOfClass("Humanoid")
				if hum then
					return hum
				end
				inst = inst.Parent
			end
			return nil
		end

		local function isTouched()
			if not part or not part.Parent then
				return false
			end
			local expand = Vector3.new(2, 3, 2)
			local parts = workspace:GetPartBoundsInBox(part.CFrame, part.Size + expand, overlapParams)
			for _, p in ipairs(parts) do
				local hum = hasHumanoidAncestor(p)
				if hum and hum.Health > 0 then
					return true
				end
			end
			return false
		end

		local function setStage(newStage)
			if newStage > stage and targetTransparencyByStage[newStage] ~= nil then
				stage = newStage
				tweenTransparency(targetTransparencyByStage[newStage], math.min(0.1, step * 0.25))
				-- Subtle shake on the last stage (about to break)
				if stage == 4 then
					local started = false
					if not started and part and part.Parent then
						started = true
						local running = true
						local originalCF = part.CFrame
						local function doShakeOnce()
							if not running or not part or not part.Parent then
								return
							end
							local amp = 0.12
							local off = Vector3.new(
								(math.random() - 0.5) * amp,
								(math.random() - 0.5) * amp,
								(math.random() - 0.5) * amp
							)
							local rotY = math.rad((math.random() - 0.5) * 2)
							local target = originalCF * CFrame.new(off) * CFrame.Angles(0, rotY, 0)
							local t1 = TweenService:Create(
								part,
								TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
								{ CFrame = target }
							)
							t1:Play()
							t1.Completed:Wait()
							local t2 = TweenService:Create(
								part,
								TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
								{ CFrame = originalCF }
							)
							t2:Play()
							t2.Completed:Wait()
						end
						task.spawn(function()
							while running and part and part.Parent and stage == 4 do
								if part.Anchored then
									doShakeOnce()
								else
									-- For non-anchored, do a tiny transparency pulse instead
									local tUp = TweenService:Create(
										part,
										TweenInfo.new(0.06),
										{ Transparency = math.min(1, part.Transparency + 0.03) }
									)
									tUp:Play()
									tUp.Completed:Wait()
									local tDn = TweenService:Create(
										part,
										TweenInfo.new(0.06),
										{ Transparency = math.max(0, part.Transparency - 0.03) }
									)
									tDn:Play()
									tDn.Completed:Wait()
								end
								task.wait(0.02)
							end
						end)
						-- Stop shaking when destroyed
						part.Destroying:Once(function()
							running = false
						end)
					end
				end
			end
		end

		local last = os.clock()
		local didInitialTouch = false
		local hb
		hb = RunService.Heartbeat:Connect(function()
			if not part or not part.Parent then
				hb:Disconnect()
				return
			end
			local now = os.clock()
			local dt = now - last
			last = now

			if isTouched() then
				if not didInitialTouch and stage == 0 then
					-- instant jump to state #2 (70%) for immediate feedback
					part.Transparency = targetTransparencyByStage[2] or 0.3
					stage = 2 - 1 -- ensure subsequent setStage logic considers next thresholds
					didInitialTouch = true
				end
				progress = progress + dt
				if progress >= thresholds[5] then
					-- destroy and cleanup
					hb:Disconnect()
					part.Transparency = 1
					part.CanCollide = false
					part.Anchored = true
					local currentCFrame = part.CFrame
					part:Destroy()
					local cooldown = tonumber((template:GetAttribute("Cooldown"))) or 0.6
					task.delay(cooldown, function()
						-- Respawn with same behavior
						if originalParent then
							local newPart = template:Clone()
							newPart:SetAttribute("_BreakableWired", nil)
							newPart.Parent = originalParent
							newPart.CFrame = currentCFrame
							-- Read originals from attributes (carry across clones)
							local origTrans = newPart:GetAttribute("OriginalTransparency")
							if origTrans == nil then
								origTrans = originalTransparency
							end
							local origCollide = newPart:GetAttribute("OriginalCanCollide")
							if origCollide == nil then
								origCollide = originalCanCollide
							end
							local origAnch = newPart:GetAttribute("OriginalAnchored")
							if origAnch == nil then
								origAnch = originalAnchored
							end
							local origSize = newPart:GetAttribute("OriginalSize") or newPart.Size

							newPart.Transparency = origTrans
							-- Collision/anchor should reflect original immediately on appear
							newPart.CanCollide = origCollide
							newPart.Anchored = origAnch
							local appearDuration = tonumber(newPart:GetAttribute("TimeToAppear")) or 0.8
							local targetSize = origSize
							newPart.Size = targetSize * 0.2
							local tween = TweenService:Create(
								newPart,
								TweenInfo.new(appearDuration, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
								{ Size = targetSize }
							)
							tween:Play()
							tween.Completed:Wait()
							-- Keep original physics; nothing else to restore here
							setupBreakable(newPart)
						end
					end)
					return
				elseif progress >= thresholds[4] then
					setStage(4)
				elseif progress >= thresholds[3] then
					setStage(3)
				elseif progress >= thresholds[2] then
					setStage(2)
				elseif progress >= thresholds[1] then
					setStage(1)
				end
				if part:GetAttribute("Debug") == true then
					print(string.format("[Breakable] progress=%.2f / %.2f", progress, thresholds[5]))
				end
			end
		end)

		-- No per-part events needed; occupancy is sampled every Heartbeat
	end

	local function respawnWithScale(atCFrame)
		local newPart = template:Clone()
		newPart.Parent = originalParent
		newPart.CFrame = atCFrame
		newPart.Transparency = originalTransparency
		newPart.CanCollide = originalCanCollide
		newPart.Anchored = originalAnchored

		local appearDuration = tonumber(newPart:GetAttribute("TimeToAppear")) or 0.8
		local targetSize = template.Size
		newPart.Size = targetSize * 0.2
		local tween = TweenService:Create(
			newPart,
			TweenInfo.new(appearDuration, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Size = targetSize }
		)
		tween:Play()
		tween.Completed:Wait()
		-- Keep original physics
		-- Re-wire breakable behavior on the new instance
		setupBreakable(newPart)
	end

	local active = false
	part.Touched:Connect(function(hit)
		if active then
			return
		end
		local character = hit and hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		if not part:GetAttribute("Breakable") then
			return
		end
		active = true
		stagedDisappearWhileTouched()
		-- Do not reset 'active' here; loop handles destroy/respawn
	end)

	-- Proactively start deterioration if a humanoid is already overlapping at respawn (Touched may not fire)
	local function hasHumanoidInBounds()
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = {}
		overlapParams.RespectCanCollide = false
		local expand = Vector3.new(2, 3, 2)
		local parts = workspace:GetPartBoundsInBox(part.CFrame, part.Size + expand, overlapParams)
		local function hasHum(inst)
			while inst and inst ~= workspace do
				local hum = inst:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					return true
				end
				inst = inst.Parent
			end
			return false
		end
		for _, p in ipairs(parts) do
			if hasHum(p) then
				return true
			end
		end
		return false
	end

	if not active and part:GetAttribute("Breakable") and hasHumanoidInBounds() then
		active = true
		stagedDisappearWhileTouched()
	end
end

local function scanWorkspace(container)
	for _, inst in ipairs(container:GetDescendants()) do
		if inst:IsA("BasePart") then
			setupBreakable(inst)
		end
	end
end

scanWorkspace(workspace)
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("BasePart") then
		setupBreakable(inst)
	end
end)
