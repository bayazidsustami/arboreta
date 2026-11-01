-- Recursive barometric lullaby generator
local p,r=1013,function(n,t)return n<1 and 0 or(math.sin(t*n*p/5e3)+r(n-1,t))/2 end
for t=1,30 do print(r(5,t))end