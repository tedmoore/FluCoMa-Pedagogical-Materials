var mins = [99999.,99999.,99999.,99999.,99999.,99999.,99999.]
var maxs = [-99999.,-99999.,-99999.,-99999.,-99999.,-99999.,-99999.]

function list(){

    vals = []
    for(var i = 0; i < arguments.length; i++){
        mins[i] = Math.min(mins[i],arguments[i])
		maxs[i] = Math.max(maxs[i],arguments[i])
		var v = (arguments[i] - mins[i]) / (maxs[i] - mins[i])
		vals.push(v)
    }

    outlet(0,vals)
}

function reset(){
	mins = [99999.,99999.,99999.,99999.,99999.,99999.,99999.]
	maxs = [-99999.,-99999.,-99999.,-99999.,-99999.,-99999.,-99999.]
}