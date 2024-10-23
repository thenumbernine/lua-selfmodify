local parser = require 'parser'
local ast = parser.ast
require 'ext'

local globalVars = table{'huge', 'pi'}:mapi(function(v) return 'math.'..v end)

-- which functions we let the mutation call out to
local globalFuncs =
	table()
	:append(table{'abs', 'acos', 'asin', 'atan', 'ceil', 'cos', 'cosh', 'deg', 'exp', 'floor', 'frexp', 'log', --[['log10',]] 'modf', 'rad', --[['randomseed', halts mutation]] 'sin', 'sinh', 'sqrt', 'tan', 'tanh'}
		:mapi(function(v) return {name='math.'..v, nargs={1,1}} end))	-- 1
	:append(table{'atan2', 'fmod', 'ldexp', 'pow'}
		:mapi(function(v) return {name='math.'..v, nargs={2,2}} end))	-- 2
	--[[ results are not reproducable
	:append(table{'random'}
		:mapi(function(v) return {name='math.'..v, nargs={0,2}} end))	-- 0..2 --]]
	:append(table{'max', 'min'}
		:mapi(function(v) return {name='math.'..v, nargs={1,2}} end))	-- 1..n
	-- convert to structure similar to astExprs
	:mapi(function(info)
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
	:append(range(('a'):byte(),('z'):byte()):mapi(function(x) return string.char(x) end))
	:append(range(('A'):byte(),('Z'):byte()):mapi(function(x) return string.char(x) end))

local function newname()
	local s = range(math.random(2,5))
		:mapi(table.pickRandom:bind(varletters)):concat()
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
			if ast._local:isa(body[i]) then
				local localExpr = body[i].exprs[1]
				if ast._assign(localExpr) then
					allvars:append(localExpr.vars)
				end
			end
		end

		local pickExpr = function()
			-- TODO instead of giving functions equal footing with astExprs
			--  how about making them a single branch of astExprs
			local pickAstExpr = table():append(astExprs):append(globalFuncs):pickRandom()
			return pickAstExpr.func(range(math.random(table.unpack(pickAstExpr.nargs))):mapi(function()
				return table.pickRandom{
					function() -- var
						return table.pickRandom(
							-- local vars get weight of 1
							allvars:mapi(function(var)
								return function()
									return var
								end
							-- all global vars collectively get a weight of 1
							end):append{function()
								return globalVars:mapi(function(n) return ast._var(n) end):pickRandom()
							end}
						)()
					end,
					function() -- literal
						return table.pickRandom{
							function() -- nil
								return ast._nil()
							end,
							function() 	-- bool
								return table.pickRandom{ast._true(), ast._false()}
							end,
							function()	-- number
								return ast._number(math.random(1,10))
							end,
							function() 	-- string
								return ast._string(
									string.char(range(math.random(1,10))
										:mapi(function() return math.random(32,127) end):unpack()))
							end,
							function()	-- table ... TODO random init args?
								return ast._table()
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
		local var = table(allvars):append{newvar}:pickRandom()
		--]]
		--[[ without
		local var = allvars:pickRandom()
		--]]
		local stmt = ast._assign({var}, {expr})
		--if var == newvar then
			stmt = ast._local{stmt}
		--end
		table.insert(body, insertLocation, stmt)
	end)

	-- remove random statement
	-- make this a condition for adding the 'remove' function to the table.pickRandom
	--  (so we don't randomly roll this if we can't execute it)
	if #body > 1 then
		actions:insert(function()
			table.remove(body, math.random(#body-1))
		end)
	end

	-- TODO modify random statement ...
	-- ... requires reflection info of all ast objects

	actions:pickRandom()()

	-- profit
	return tree:toLua()
end

return mutate
