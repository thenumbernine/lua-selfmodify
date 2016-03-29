#!/usr/bin/env lua -lluarocks.require
--[[
GA:
1) establish all fitnesses
2) pick weighted by fitness
3) duplicate and modify slightly
4) kill the weak
--]]
require 'ext'
require 'lfs'

local maxpop = 50
local popdir = 'pop'

local function dir(loc)
	local results = table()
	for f in lfs.dir(loc) do
		if f:sub(1,1) ~= '.' then
			results:insert(f)
		end
	end
	return results
end

-- units is a collection of: {id=id, code=code, fitness=fitness} 
local units = table()
local familyTree = assert(load('return {'..(file.familytree or '')..'}'))()

-- load units from disk
for _,filename in ipairs(dir(popdir)) do
	local id = filename:match('^(%d+)%.lua$')
	if id then
		id = tonumber(id)
		if id then
			units:insert{
				id=id,
				code=file[popdir..'/'..filename],
			}
		end
	end
end

math.randomseed(os.time())

-- problem-specific:
-- fitness must be non-negative real
--local fitnessFunction = require 'problems.heaviside_step'
--local fitnessFunction = require 'problems.sine'
local fitnessFunction = require 'problems.primes'

local function calcFitness(unitCode)
	local result, fitness = pcall(function()
		local fitness = fitnessFunction(load(unitCode)(), unitCode)
		return type(fitness) == 'number' and fitness == fitness and fitness
	end)
	return result and fitness
end

local genIndex = 0
function generation()
	genIndex = genIndex + 1

	print('gen '..genIndex)
	-- evaluate units
	for _,unit in ipairs(units) do
		unit.fitness = calcFitness(unit.code)
		-- sometimes, even if a unit passed the initial test, it can still fail later
		--  (courtesy of math.random()'s use -- that is an unaccounted-for external state)
		-- for that reason, validate fitenss here:
		unit.fitness = unit.fitness or 0
		local codeTrimmed = unit.code
		if #codeTrimmed > 80 then codeTrimmed = codeTrimmed:sub(1,77)..'...' end
		print(unit.id, unit.fitness, codeTrimmed)
	end

	local totalFitness = 0
	for _,unit in ipairs(units) do
		totalFitness = totalFitness + unit.fitness
	end

	local pickFitness = math.random() * totalFitness
	for _,unit in ipairs(units) do
		pickFitness = pickFitness - unit.fitness
		if pickFitness <= 0 then
			pickUnit = unit
			break
		end
	end

	print('picking unit '..pickUnit.id..' for mutation...')

	local mutate = require'mutate'
	local newUnit = {code=mutate(pickUnit.code)}

	print('new unit:', newUnit.code)

	-- validation test
	local result, callback = xpcall(load:bind(newUnit.code), function(err)
		io.stderr:write('new unit died in load\n')
		io.stderr:write(err..'\n'..debug.traceback())
	end)
	if not result then return end
	if not xpcall(callback, function(err)
		io.stderr:write('new unit died executing global scope\n')
		io.stderr:write(err..'\n'..debug.traceback())
	end) then return end
	newUnit.fitness = calcFitness(newUnit.code)
	if not newUnit.fitness then
		io.stderr:write('new unit died in execution\n')
		--io.stderr:write(err..'\n'..debug.traceback())
		return
	end

	newUnit.id = units:map(function(unit) return unit.id end):sup()+1
	file[popdir..'/'..newUnit.id..'.lua'] = newUnit.code
	local newUnitFamilyTreeInfo = {parent=pickUnit.id, fitness=newUnit.fitness, code=newUnit.code}
	familyTree[newUnit.id] = newUnitFamilyTreeInfo 
	-- NOTICE this asserts that the units are created once and never replaced
	-- currently this is true.  if I start throwing out the stateful units that--after creation--return bad fitnesses then this won't be true anymore
	file.familytree = (file.familytree or '') .. tolua(newUnitFamilyTreeInfo) .. ';\n'
	
	if #units > maxpop-1 then
		-- kill the weakest
		local weakestUnitIndex = select(2, units:map(function(unit) return unit.fitness end):inf())
		local weakestUnit = units[weakestUnitIndex]
		print('killing weak unit:', weakestUnit.id, weakestUnit.fitness, weakestUnit.code)
		units:remove(weakestUnitIndex)
		file[popdir..'/'..weakestUnit.id..'.lua'] = nil
	end

	units:insert(newUnit)
end

local cmd = arg[1]
local switch = {
	forever = function()
		while true do 
			generation()
		end
	end,
	reset = function()
		print'resetting...'
		for _,filename in ipairs(dir(popdir)) do
			file[popdir..'/'..filename] = nil
		end
		file[popdir..'/0.lua'] = file['0.lua']
		file.familytree = nil
	end,
	maketree = function()
		-- build dot file of generations
		local colors = {
			{1,0,0},
			{1,1,0},
			{0,1,0},
			{0,1,1},
			{0,0,1},
			{1,0,1},
		}
		file['familytree.dot'] = table{
			'digraph tree {',
			table.map(familyTree, function(info, id, dest)
				-- color by fitness
				local x = math.max(0,math.min(1,math.log10(info.fitness)/25+1)) * (#colors - 1) + 1
				-- color by generation
				--local x = id/#familyTree * (#colors-1) + 1
				local f = math.floor(x)
				local s = x - f
				local t = 1 - s
				local cn = colors[f%#colors+1]
				local cp = colors[f]
				local r = (cn[1] * s + cp[1] * t) * 255
				local g = (cn[2] * s + cp[2] * t) * 255
				local b = (cn[3] * s + cp[3] * t) * 255
				local color = ('"#%02x%02x%02x"'):format(r,g,b)
				return '\t' .. info.parent .. ' -> ' .. id .. ' [color=' .. color .. ']', #dest+1
			end):concat'\n',
			'}',
		}:concat'\n'
	
		os.execute'dot -Tsvg -o familytree.svg familytree.dot'	
	end,
}
(switch[cmd] or function()	-- default
	for i=1,(tonumber(cmd) or 1) do
		generation()
	end
end)()
