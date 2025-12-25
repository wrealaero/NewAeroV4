local module = {}
local eps = 1e-9

local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1
	local p, q, D

	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else
		local sqrt_D = math.sqrt(D)
		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2
	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
	cb_p = p * p * p
	D = q * q + cb_p

	if isZero(D) then
		if isZero(q) then
			s0 = 0
			num = 1
		else
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)
		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)
		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A
	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local s0, s1, s2, s3
	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1

		do
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = #results
			s0, s1 = results[1], results[2]
		end

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		if (num == 0) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s0, s1 = results[1], results[2]
		end
		if (num == 1) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s1, s2 = results[1], results[2]
		end
		if (num == 2) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s2, s3 = results[1], results[2]
		end
	end

	sub = 0.25 * A
	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	if (num > 3) then s3 = s3 - sub end

	return {s3, s2, s1, s0}
end

local function predictMovementWithBuilding(targetPlayer, targetPart, projSpeed, gravity, origin, timeToTarget)
	if not targetPlayer or not targetPlayer.Character or not targetPart then 
		return targetPart and targetPart.Position or Vector3.zero
	end
	
	local currentPos = targetPart.Position
	local currentVel = targetPart.Velocity
	
	local isBuilding = false
	local buildDirection = Vector3.zero
	local buildSpeed = 0
	
	local nearbyBlocks = workspace:FindPartsInRegion3(
		Region3.new(
			currentPos - Vector3.new(5, 10, 5),
			currentPos + Vector3.new(5, 10, 5)
		),
		nil,
		50
	)
	
	local upwardPlacement = false
	for _, block in pairs(nearbyBlocks) do
		if block.Name:find("wool") or block.Name:find("wood") or block.Name:find("stone") then
			if block.Position.Y > currentPos.Y + 3 then
				upwardPlacement = true
				break
			end
		end
	end
	
	local distance = (currentPos - origin).Magnitude
	
	local timeMultiplier = 1.0
	if distance > 100 then
		timeMultiplier = 0.92
	elseif distance > 70 then
		timeMultiplier = 0.95
	elseif distance > 40 then
		timeMultiplier = 0.98
	elseif distance < 20 then
		timeMultiplier = 1.05
	elseif distance < 10 then
		timeMultiplier = 1.10
	end
	
	timeToTarget = timeToTarget or (distance / projSpeed) * timeMultiplier
	
	local horizontalPredictionStrength = 0.75
	if distance > 80 then
		horizontalPredictionStrength = 0.65
	elseif distance > 50 then
		horizontalPredictionStrength = 0.70
	elseif distance > 30 then
		horizontalPredictionStrength = 0.78
	elseif distance < 15 then
		horizontalPredictionStrength = 0.85
	end
	
	local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
	local predictedHorizontal = horizontalVel * timeToTarget * horizontalPredictionStrength
	
	local verticalVel = currentVel.Y
	local predictedVertical = 0
	
	local isJumping = verticalVel > 12
	local isFalling = verticalVel < -15
	local isPeaking = math.abs(verticalVel) < 5 and verticalVel < 2
	local isHighJump = verticalVel > 25
	local isLongFall = verticalVel < -30
	
	if upwardPlacement then
		isBuilding = true
		local buildVelocity = Vector3.new(0, 8, 0) 
		predictedVertical = buildVelocity.Y * timeToTarget * 0.4
		
	elseif isHighJump then
		predictedVertical = verticalVel * timeToTarget * 0.35
		
	elseif isLongFall then
		predictedVertical = verticalVel * timeToTarget * 0.28
		
	elseif isFalling then
		predictedVertical = verticalVel * timeToTarget * 0.32
		
	elseif isJumping then
		predictedVertical = verticalVel * timeToTarget * 0.30
		
	elseif isPeaking then
		predictedVertical = -3.5 * timeToTarget
		
	else
		predictedVertical = verticalVel * timeToTarget * 0.25
	end
	
	local heightOffset = 0
	if distance < 20 then
		heightOffset = 1.5 
	elseif distance < 50 then
		heightOffset = 1.0 
		heightOffset = 0.5 
	end
	
	local basePrediction = currentPos + predictedHorizontal
	
	local verticalOffset = Vector3.new(0, predictedVertical + heightOffset, 0)
	
	local finalPosition = basePrediction + verticalOffset
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {targetPlayer.Character}
	
	local groundRay = workspace:Raycast(finalPosition, Vector3.new(0, -10, 0), raycastParams)
	if groundRay then
		finalPosition = Vector3.new(
			finalPosition.X,
			math.max(finalPosition.Y, groundRay.Position.Y + 2),
			finalPosition.Z
		)
	end
	
	return finalPosition
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
	local disp = targetPos - origin
	local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -.5 * gravity

	if playerGravity and playerGravity > 0 then
		local estTime = (disp.Magnitude / projectileSpeed)
		local origq = q
		
		if playerJump then
			q = q + playerJump
		end
		
		for i = 1, 50 do
			q = origq - (.5 * playerGravity) * estTime
			local velo = targetVelocity * 0.033
			local ray = workspace:Raycast(
				Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), 
				Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), 
				params
			)
			
			if ray then
				local newTarget = ray.Position + Vector3.new(0, playerHeight + 0.5, 0)
				local heightDiff = math.abs(targetPos.Y - newTarget.Y)
				if heightDiff > 5 then
					estTime = estTime - math.sqrt((heightDiff * 2) / playerGravity)
				end
				targetPos = newTarget
				j = (targetPos - origin).Y
				q = q * 0.5
				break
			else
				break
			end
		end
	end

	local solutions = module.solveQuartic(
		l*l,
		-2*q*l,
		q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
		2*j*q + 2*h*p + 2*k*r,
		j*j + h*h + k*k
	)
	
	if solutions then
		local posRoots = {}
		for _, v in solutions do
			if v > 0 and v < 10 then 
				table.insert(posRoots, v)
			end
		end
		table.sort(posRoots)

		if posRoots[1] then
			local t = posRoots[1]
			local d = (h + p*t)/t
			local e = (j + q*t - l*t*t)/t
			local f = (k + r*t)/t
			return origin + Vector3.new(d, e, f)
		end
	elseif gravity == 0 then
		local t = (disp.Magnitude / projectileSpeed)
		local d = (h + p*t)/t
		local e = (j + q*t - l*t*t)/t
		local f = (k + r*t)/t
		return origin + Vector3.new(d, e, f)
	end
end

module.predictStrafingMovement = predictMovementWithBuilding

return module
