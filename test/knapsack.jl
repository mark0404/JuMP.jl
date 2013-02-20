########################################################################
# MathProg 
# A MILP+QP modelling langauge for Julia
# By Iain Dunning and Miles Lubin
#
# knapsack.jl
# A simple knapsack-style problem.
# 
########################################################################


require("../src/MathProg.jl")
using MathProg

m = Model("max")

#x = addVars(m, 0, 1, INTEGER, 5, "x")
@defVar(m, 0 <= x[1:5] <= 1, Int)

profit = [ 5, 3, 2, 7, 4 ]
weight = [ 2, 8, 4, 2, 5 ]
capacity = 10

@setObjective(m, sum{profit[i]*x[i], i=1:5} )

@addConstraint(m, sum{weight[i]*x[i], i=1:5} <= capacity)

status = solve(m)

println("Objective is: ",m.objVal)
println("Solution is:")
for i = 1:5
	println("x", i, " = ", getValue(x[i]))
end