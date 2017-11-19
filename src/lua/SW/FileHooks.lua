debug_stickywebs = setmetatable({}, {__index = debug})

do
	local old = debug_stickywebs.getupvalue
	local function getupvalue(f, up, recursive)
		if type(up) ~= "string" then
			return old(f, up)
		end

		if recursive == nil then
			recursive = true
		end

		local funcs   = {}
		local i, n, v = 0
		repeat
			i = i + 1
			n, v = old(f, i)
			if recursive and type(v) == "function" then
				table.insert(funcs, v)
			end
		until
			n == nil or n == up

		-- Do a recursive search
		if n == nil then
			for _, subf in ipairs(funcs) do
				v, f, i = getupvalue(subf, up)
				if f ~= nil then
					return v, f, i
				end
			end
		elseif n == up then
			return v, f, i
		end
	end
	debug_stickywebs.getupvalue = getupvalue
end

do
	local old = debug_stickywebs.setupvalue
	local function setupvalue(f, up, v, recursive)
		if type(up) ~= "string" then
			return old(f, up, v)
		end

		local _, f, i = debug_stickywebs.getupvalue(f, up, recursive)
		old(f, i, v)
	end
	debug_stickywebs.setupvalue = setupvalue
end

do
	local function joinupvalues(dest, src, extras)
		assert(type(dest) == "function", "first argument is not a function!")
		assert(type(src)  == "function", "second argument is not a function!")
		local i, n, v = 0
		while true do
			i = i + 1
			n, v = debug_stickywebs.getupvalue(dest, i)
			if n == nil then
				break
			end

			local _, _, src_i = debug_stickywebs.getupvalue(src, n, false)
			if src_i ~= nil then
				debug_stickywebs.upvaluejoin(dest, i, src, src_i)
				if v ~= nil then
					local _, original = debug_stickywebs.getupvalue(dest, i)
					if type(original) == "function" and type(v) == "function" then
						joinupvalues(v, original)
					end
					debug_stickywebs.setupvalue(dest, i, v)
				end
			end
		end

		if extras then
			for k, v in pairs(extras) do
				debug_stickywebs.setupvalue(src, k, v)
			end
		end
	end
	debug_stickywebs.joinupvalues = joinupvalues
end

do
	local function replaceupvalue(f, up, v, recursive)
		local original, owner_func, i = debug_stickywebs.getupvalue(f, up, recursive)
		assert(owner_func, "Could not find the specified upvalue!")
		debug_stickywebs.joinupvalues(v, original)
		debug_stickywebs.setupvalue(owner_func, i, v)
	end
	debug_stickywebs.replaceupvalue = replaceupvalue
end

do
	local function replacemethod(classname, n, v, original)
		local derived = Script.GetDerivedClasses(classname)
		if derived == nil then return end
		for _, d in ipairs(derived) do
			local class = _G[d]
			if class[n] == original then
				class[n] = v
				replacemethod(d, n, v, original)
			end
		end
	end

	function debug_stickywebs.replacemethod(classname, n, v)
		assert(type(v) == "function", "third argument is not a function!")
		local class = _G[classname]
		local original = class[n]
		debug_stickywebs.joinupvalues(v, original)
		class[n] = v
		replacemethod(classname, n, v, original)
	end
end

ModLoader.SetupFileHook("lua/Weapons/Alien/Web.lua", "lua/SW/Web.lua", "post")
ModLoader.SetupFileHook("lua/Weapons/Alien/HealSprayMixin.lua", "lua/SW/HealSprayMixin.lua", "post")
