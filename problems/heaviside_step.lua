-- best fit to heaviside step function
return function(unitFunc, unitCode)
	local err = 0
	for x=-5,5 do
		err = err + math.abs(unitFunc(x) - (x < 0 and 0 or 1))
	end
	return math.exp(-.5 * err * err)
end