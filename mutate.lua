local parser = require 'parser'
local ast = require 'parser.ast'
require 'ext'

local function pickrandom(x) 
	return x[math.random(#x)] 
end

local globalVars = table{'huge', 'pi'}:map(function(v) return 'math.'..v end)

-- which functions we let the mutation call out to
local globalFuncs = 
	table()	
	:append(table{'abs', 'acos', 'asin', 'atan', 'ceil', 'cos', 'cosh', 'deg', 'exp', 'floor', 'frexp', 'log', 'log10', 'modf', 'rad', --[['randomseed', halts mutation]] 'sin', 'sinh', 'sqrt', 'tan', 'tanh'}
		:map(function(v) return {name='math.'..v, nargs={1,1}} end))	-- 1
	:append(table{'atan2', 'fmod', 'ldexp', 'pow'}
		:map(function(v) return {name='math.'..v, nargs={2,2}} end))	-- 2
	--[[ results are not reproducable
	:append(table{'random'}
		:map(function(v) return {name='math.'..v, nargs={0,2}} end))	-- 0..2 --]]
	:append(table{'max', 'min'}
		:map(function(v) return {name='math.'..v, nargs={1,2}} end))	-- 1..n
	-- convert to structure similar to astExprs
	:map(function(info)
		local func = ast._var(assert(info.name))
		info.func = function(...) return ast._call(func, ...) end
		info.name = nil
		return info
	end)

local astExprs = table()
for _,name in ipairs{'_unm', '_not', '_len', '_par'} do
	astExprs:insert{func=ast[name], nargs={1,1}}
end
for _,name in ipairs{'_add', '_sub', '_mul', '_div', '_mod', '_concat', '_lt', '_le', '_gt', '_ge', '_eq', '_ne', '_and', '_or'} do
	astExprs:insert{func=ast[name], nargs={2,2}}
end

local varletters = 
	table{'_'}
	:append(range(('a'):byte(),('z'):byte()):map(function(x) return string.char(x) end))
	:append(range(('A'):byte(),('Z'):byte()):map(function(x) return string.char(x) end))

local function newname() 
	local s = range(math.random(2,5))
		:map(pickrandom:bind(varletters)):concat()
	return s
end

local function mutate(code)
	local tree = parser.parse(code)
	local body = tree[1].exprs[1]

	-- mutate 
	-- determine mutation type
	--  deletion of a statement or sub-expression
	--  insertion of a new statement or sub-expression
	--  modification of a statement or sub-expression

	-- insertion:
	-- determine location
	--print('num stmts', #body)
	
	local actions = table()

	-- add random state variable assignment permuting the variable 
	actions:insert(function()
		local insertLocation = math.random(#body)
		
		local allvars = table(body.args)
		-- add to body.args any variables declared before this statement
		for i=1,insertLocation-1 do
			if getmetatable(body[i]) == ast._local then
				local localExpr = body[i].exprs[1]
				if getmetatable(localExpr) == ast._assign then
					allvars:append(localExpr.vars)
				end
			end
		end
		
		local pickExpr = function()
			-- TODO instead of giving functions equal footing with astExprs 
			--  how about making them a single branch of astExprs
			local pickAstExpr = pickrandom(table():append(astExprs):append(globalFuncs))
			return pickAstExpr.func(range(math.random(unpack(pickAstExpr.nargs))):map(function()
				return pickrandom{
					function() -- var
						return pickrandom(
							-- local vars get weight of 1
							allvars:map(function(var)
								return function()
									return var
								end
							-- all global vars collectively get a weight of 1
							end):append{function()
								return pickrandom(
									globalVars:map(function(n) return ast._var(n) end)
								)
							end}
						)()
					end,
					function() -- literal
						return pickrandom{
							function() -- nil
								return ast._nil()
							end,
							function() 	-- bool
								return pickrandom{ast._true(), ast._false()} 
							end,
							function()	-- number
								return ast._number(math.random(1,10))
							end,
							function() 	-- string
								return ast._string(
									string.char(range(math.random(1,10))
										:map(function() return math.random(32,127) end):unpack()))
							end,
							function()	-- table ... TODO random init args?
								return ast._table{}
							end,
							--function()	-- function ...
							--end,
						}()
					end,
				}()
			end):unpack())
		end
		local expr = pickExpr()
		-- [[ with variable creation
		local newvar = ast._var(newname())
		local var = pickrandom(table(allvars):append{newvar})
		--]]
		--[[ without
		local var = pickrandom(allvars)
		--]]
		local stmt = ast._assign({var}, {expr})
		--if var == newvar then 
			stmt = ast._local{stmt} 
		--end
		table.insert(body, insertLocation, stmt)
	end)

	-- remove random statement
	-- make this a condition for adding the 'remove' function to the pickrandom
	--  (so we don't randomly roll this if we can't execute it)
	if #body > 1 then
		actions:insert(function()
			table.remove(body, math.random(#body-1))
		end)
	end

	-- TODO modify random statement ...
	-- ... requires reflection info of all ast objects 
	
	pickrandom(actions)()
	
	-- profit
	return tostring(tree)
end

return mutate
