-- check which numbers are prime
return function(unitFunc, unitCode)
	local err = 0
	for i,isprime in ipairs{0,1,1,0,1,0,1,0,0,0,1,0,1} do
		err = err + math.abs(unitFunc(x) - isprime)
	end
	return math.exp(-.5 * err * err)
end