/* 
Estimation of Nonparametric instrumental variable (NPIV) models with cross validation
This command is built upon `npiv' command. 

Author : Dongwoo Kim (University College London)

Version 1.1.2 25th Oct 2017

This program estimates the nonparametric function g(x) and a vector of coefficients of a linear index γ in

Y = g(X) + Z'γ + e with E(e|W)=0

where Y is a scalar dependent variable ("depvar"), 
X is a scalar endogenous variable ("expvar"), 
Z is a vector of exogeneous covariats ("exovar"), and 
W a scalar instrument ("inst").

The optimal number of knots is selected automatically by cross validation. 

Syntax:
npivcv depvar expvar inst [exovar] [if] [in] [, power_exp(#) power_inst(#) pctile(#) polynomial increasing decreasing] 

For faster computation, cross validation is done in the following way.

1. Divide the sample in two pieces (Y0, Y1)
2. Run npiv regression on Y0 and Y1 separately with different number of knots
3. Define the fitted values of Y0 (Y1) by using estimation result from Y1 (Y0)
4. Evaluate MSE for each subsample and choose the number of knots minimisng average MSE

where power_exp is the power of basis functions for X (defalut = 2),
power_inst is the power of basis functions for W (defalut = 3),
pctile (default = 5) indicates the domain over which the NPIV sieve estimator is computed.
polonomial option gives the basis functions for power polynomials (default is bslpline).

# shape restrictions (bspline is used - power of bslpine for "expvar" is fixed to 2).
increasing option imposes a increasing shape restriction on function g(X).
decreasing option imposes a decreasing shape restriction on function g(X).

When polynomial is used, shape restrictions cannot be imposed.
(error message will come out)

Users can freely modify the power and the type of basis functions
when shape restrictions are not imposed.

If unspecified, the command runs on a default setting.
*/

program define npivcv, eclass
		version 11
		
// initializations
syntax varlist(numeric fv) [, power_exp(integer 2) power_inst(integer 3) pctile(integer 5) maxknot(integer 5) POLYnomial INCreasing DECreasing]

// generate temporary names to avoid any crash in Stata spaces
tempvar Y1 Y0 samplesplit splitdummy xlpct xupct 
tempname opt_knot

// local macro assignments
gettoken dep varlist : varlist
gettoken exp varlist : varlist
gettoken iv varlist : varlist
local exo `varlist'
local power1 `power_exp'
local power2 `power_inst'
local upctile = 100 - `pctile'
				
quietly egen `xlpct' = pctile(`exp'), p(`pctile')
quietly egen `xupct' = pctile(`exp'), p(`upctile')
local xmin = `xlpct'
local xmax = `xupct'
				
quietly summarize `dep'
local knot = max( r(N)^(1/5), `maxknot')

set seed 1004
gen double `samplesplit' = rnormal(0, 1)
quietly summarize `samplesplit', detail
local med = r(p50)
gen byte `splitdummy' = (`samplesplit' > `med')

quietly gen `Y1' = `dep' if `splitdummy'
quietly gen `Y0' = `dep' if 1-`splitdummy'

mata : mse    = J(2, `knot', 10^10)
mata : Y1     = st_data(., "`Y1'", 0)
mata : Y0     = st_data(., "`Y0'", 0)
mata : fitted1 = J(rows(Y1),`knot', 0) 
mata : fitted0 = J(rows(Y0),`knot', 0) 


display " "
display "Execute cross validation for subsample 0"

forvalues i = 3/`knot' {
local knots `i'
local x_distance = (`xmax' - `xmin')/(`knots' - 1 )	

if "`polynomial'" == "" {
	// check whether increasing option is used        
	if "`increasing'" == "increasing" {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 0, power_exp(2) power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile') increasing
	quietly bspline if `splitdummy' == 1, xvar(`exp') gen(temp1basis) knots(`xmin'(`x_distance')`xmax') power(2)
	}
	
	else if "`decreasing'" == "decreasing" {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 0, power_exp(2) power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile') decreasing
	quietly bspline if `splitdummy' == 1, xvar(`exp') gen(temp1basis) knots(`xmin'(`x_distance')`xmax') power(2)
	}
	
	else {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 0, power_exp(`power1') power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile')
	quietly bspline if `splitdummy' == 1, xvar(`exp') gen(temp1basis) knots(`xmin'(`x_distance')`xmax') power(`power1')
	}
}

else {
	if "`increasing'" == "increasing" {
	display in red "shape restriction (increasing) not allowed"	
	error 498
	}
	else if "`decreasing'" == "decreasing" {
	display in red "shape restriction (decreasing) not allowed"	
	error 498
	}
	else {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 0, power_exp(`knots') power_inst(`knots') pctile(`pctile') polynomial
	quietly polyspline `exp' if `splitdummy' == 1, gen(temp1basis) refpts(`xmin'(`x_distance')`xmax') power(`knots') 
	
	}
}
			

mata : b = st_matrix("e(b)")'			
mata : T = st_data(., "temp1basis*",0)
mata : n = cols(T)
mata : fitted1[,`i'] = T*b[1..n]
mata : mse[1, `i'] = sum( (Y1  - fitted1[,`i']):^2)/rows(Y1)

capture drop grid* 
capture drop temp1basis* 
capture drop npest*
}

display " "
display "Execute cross validation for subsample 1"

forvalues i = 3/`knot' {
local knots `i'
local x_distance = (`xmax' - `xmin')/(`knots' - 1 )	

if "`polynomial'" == "" {
	// check whether increasing option is used        
	if "`increasing'" == "increasing" {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 1, power_exp(2) power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile') increasing
	quietly bspline if `splitdummy' == 0, xvar(`exp') gen(temp0basis) knots(`xmin'(`x_distance')`xmax') power(2)
	}
	
	else if "`decreasing'" == "decreasing" {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 1, power_exp(2) power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile') decreasing
	quietly bspline if `splitdummy' == 0, xvar(`exp') gen(temp0basis) knots(`xmin'(`x_distance')`xmax') power(2)
	}
	
	else {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 1, power_exp(`power1') power_inst(`power2') num_exp(`knots') num_inst(`knots') pctile(`pctile')
	quietly bspline if `splitdummy' == 0, xvar(`exp') gen(temp0basis) knots(`xmin'(`x_distance')`xmax') power(`power1')
	}
}

else {
	if "`increasing'" == "increasing" {
	display in red "shape restriction (increasing) not allowed"	
	error 498
	}
	else if "`decreasing'" == "decreasing" {
	display in red "shape restriction (decreasing) not allowed"	
	error 498
	}
	else {
	npiv `dep' `exp' `iv' `exo' if `splitdummy' == 1, power_exp(`knots') power_inst(`knots') pctile(`pctile') polynomial
	quietly polyspline `exp' if `splitdummy' == 0, gen(temp0basis) refpts(`xmin'(`x_distance')`xmax') power(`knots') 
	
	}
}
			

mata : b = st_matrix("e(b)")'			
mata : T = st_data(., "temp0basis*",0)
mata : n = cols(T)
mata : fitted0[,`i'] = T*b[1..n]
mata : mse[2, `i'] = sum( (Y0  - fitted0[,`i']):^2)/rows(Y0)

capture drop grid* 
capture drop temp0basis* 
capture drop npest*
}

mata : criterion = colsum(mse)
mata : s      = (criterion :== min(criterion))
mata : opt_knot = select(1..cols(mse), s)
mata : st_numscalar("`opt_knot'", opt_knot)

local opt_knot = `opt_knot'
display " "
display "Run NPIV regression with the optimal knots"

if "`polynomial'" == "" {
	// check whether increasing option is used        
	if "`increasing'" == "increasing" {
	npiv `dep' `exp' `iv' `exo', power_exp(2) power_inst(`power2') num_exp(`opt_knot') num_inst(`opt_knot') pctile(`pctile') increasing
	}
	
	else if "`decreasing'" == "decreasing" {
	npiv `dep' `exp' `iv' `exo', power_exp(2) power_inst(`power2') num_exp(`opt_knot') num_inst(`opt_knot') pctile(`pctile') decreasing
	}
	
	else {
	npiv `dep' `exp' `iv' `exo', power_exp(`power1') power_inst(`power2') num_exp(`opt_knot') num_inst(`opt_knot') pctile(`pctile')
	}
}

else {
	if "`increasing'" == "increasing" {
	display in red "shape restriction (increasing) not allowed"	
	error 498
	}
	else if "`decreasing'" == "decreasing" {
	display in red "shape restriction (decreasing) not allowed"	
	error 498
	}
	else {
	npiv `dep' `exp' `iv' `exo', power_exp(`opt_knot') power_inst(`opt_knot') pctile(`pctile') polynomial
	}
}

display "The number of optimal knots = " `opt_knot'

ereturn scalar maxknot = `knot'
ereturn scalar optknot = `opt_knot'
ereturn local cmd "npivcv" 
ereturn local title "Nonparametric IV regression with cross-validation" 
end