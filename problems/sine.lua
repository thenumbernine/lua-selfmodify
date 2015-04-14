-- best fit to sine wave
return function(unitFunc, unitCode)
	local err = 0
	for x=-5,5 do
		err = err + math.abs(unitFunc(x) - math.sin(x))
	end
	return math.exp(-.5 * err * err)
end