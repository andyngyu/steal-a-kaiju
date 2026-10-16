-- KaijuAnimation.Util: small math helpers for the kaiju animation engine. Everything here is allocation-free so it can
-- run every frame: easing, smooth noise, the breathing curve, exact damped springs and keyframe curves.
local Util = {}

local clamp, exp, sin, cos, sqrt, noise = math.clamp, math.exp, math.sin, math.cos, math.sqrt, math.noise

Util.TAU = math.pi * 2
Util.RAD = math.pi / 180

-- 0..1 ease in and out (never linear)
function Util.smooth(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Smooth noise in about -1..1: two octaves of Perlin noise along x; seed picks an independent track.
function Util.noise(x, seed)
	return clamp((noise(x, seed, 0.37) + 0.5 * noise(x * 2.07 + 11.3, seed, 0.71)) * 1.55, -1, 1)
end

-- One breathing cycle (p in 0..1) to 0..1: an eased inhale over the first 42 percent, a slower eased exhale after.
function Util.breath(p)
	if p < 0.42 then
		local x = p / 0.42
		return x * x * (3 - 2 * x)
	end
	local x = (p - 0.42) / 0.58
	return 1 - x * x * (3 - 2 * x)
end

-- Exact damped spring (frame-rate independent at any dt). springCoeffs gives the step's coefficients for an angular
-- frequency omega (rad/s) and damping ratio zeta (below 1: a slight overshoot); springStep advances one axis, where x is
-- the offset from the target and v its velocity.
function Util.springCoeffs(omega, zeta, dt)
	local zw = zeta * omega
	local wd = omega * sqrt(1 - zeta * zeta)
	return exp(-zw * dt), cos(wd * dt), sin(wd * dt), zw, wd
end

function Util.springStep(x, v, e, c, s, zw, wd)
	local b = (v + zw * x) / wd
	return e * (x * c + b * s), e * ((b * wd - zw * x) * c - (x * wd + zw * b) * s)
end

-- Keyframe curve from a flat list { t1, v1, t2, v2, ... } (t ascending, 0..1). Monotone cubic interpolation: it passes
-- through every key, eases in and out at both ends and at every turning point, and never overshoots a key.
function Util.curve(list)
	local n = #list // 2
	local T, V, M = table.create(n), table.create(n), table.create(n, 0)
	for i = 1, n do
		T[i] = list[2 * i - 1]
		V[i] = list[2 * i]
	end
	for i = 2, n - 1 do
		local h0, h1 = T[i] - T[i - 1], T[i + 1] - T[i]
		if h0 > 0 and h1 > 0 then
			local d0, d1 = (V[i] - V[i - 1]) / h0, (V[i + 1] - V[i]) / h1
			if d0 * d1 > 0 then
				local w0, w1 = 2 * h1 + h0, h1 + 2 * h0
				M[i] = (w0 + w1) / (w0 / d0 + w1 / d1)
			end
		end
	end
	return { T = T, V = V, M = M, n = n }
end

function Util.evalCurve(c, x)
	local T, V, n = c.T, c.V, c.n
	if x <= T[1] then
		return V[1]
	end
	if x >= T[n] then
		return V[n]
	end
	local i = 1
	while T[i + 1] < x do
		i += 1
	end
	local h = T[i + 1] - T[i]
	if h <= 0 then
		return V[i + 1]
	end
	local M = c.M
	local u = (x - T[i]) / h
	local u2 = u * u
	local u3 = u2 * u
	return (2 * u3 - 3 * u2 + 1) * V[i] + (u3 - 2 * u2 + u) * h * M[i] + (3 * u2 - 2 * u3) * V[i + 1] + (u3 - u2) * h * M[i + 1]
end

-- 0..1..0 window over [from, to] with soft edges (fade seconds as a fraction of the window), for oscillations
function Util.window(x, from, to, fade)
	if x <= from or x >= to then
		return 0
	end
	local a = (x - from) / fade
	local b = (to - x) / fade
	local w = a < b and a or b
	if w >= 1 then
		return 1
	end
	return w * w * (3 - 2 * w)
end

-- random number in { lo, hi } using a Random object
function Util.range(rng, pair)
	return rng:NextNumber(pair[1], pair[2])
end

return Util
