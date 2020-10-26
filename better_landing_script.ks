clearscreen.

set radarOffset to 30.
lock trueRadar to alt:radar - radarOffset.			// Offset radar to get distance from gear to ground
lock g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)
lock maxDecel to (ship:availablethrust / ship:mass) - g.	// Maximum deceleration possible (m/s^2)
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require
lock idealThrottle to stopDist / trueRadar.			// Throttle required for perfect hoverslam
lock impactTime to trueRadar / abs(ship:verticalspeed).		// Time until impact, used for landing gear
set runMode to 1.

set landTarget to ship:geoposition.
wait until ag9.

rcs on.
sas off.

log "time,runmode,latError,lngError" to log.csv.

if ADDONS:TR:AVAILABLE {
    if ADDONS:TR:HASIMPACT {
        //PRINT ADDONS:TR:IMPACTPOS.
    } else {
        PRINT "Impact position is not available".
        set runMode to 0.
    }
} else {
    PRINT "Trajectories is not available.".
    set runMode to 0.
}

function getSign{
    parameter ipt.
    if ipt > 0{
        return 1.
    }
    else{
        return 0.
    }
}

set impactPos to addons:tr:impactpos.
lock lat1 to impactPos:lat.
lock long1 to impactPos:lng.
lock lat2 to landTarget:lat.
lock long2 to landTarget:lng.

lock distTarget to sqrt((lat1-lat2)^2+(long1-long2)^2).

set toMul to 1.

lock latDiff to (latlng(lat1, 0):position - latlng(lat2, 0):position):mag * (abs(lat1 - lat2)/(lat1 - lat2)) * toMul.
lock lngDiff to (latlng(long1, 0):position - latlng(long2, 0):position):mag * (abs(long1 - long2)/(long1 - long2)) * toMul.

//PID Stuff
lock latError to 0 - (latDiff).
lock lngError to 0 - (lngDiff).

set pidLat to PIDLOOP(0.15, 0, 0.4, -1, 1).
set pidLng to PIDLOOP(0.275, 0, 0.3, -1, 1).
set pidLat:SETPOINT to 0.
set pidLng:SETPOINT to 0.

set thrott to 0.0.
set steer to heading(270, 10).

lock steering to steer.
lock throttle to thrott * 1.0.

set startTime to time:seconds.
ag1 on.

until runMode = 0{
    if runMode = 1{
        //orient to boostback 
        set steer to heading(270, 10).
        set thrott to 0.0.
        if time:seconds - startTime > 25{
            set runMode to 2.
        }
    }
    if runMode = 2{
        //boostback
        set impactPos to addons:tr:impactpos.
        set steer to heading(270, 10).
        set thrott to 1.0.
        if long1 < long2{
            set runMode to 3.
        }
    }
    if runMode = 3{
        //coasting until guidance
        set steer to up.
        set thrott to 0.0.
        if trueRadar < 40000{
            set runMode to 4.
        }
    }
    else if runMode = 4{
        //Coasting with guidance
        set impactPos to addons:tr:impactpos.
        brakes on.
        set pred to r(pidLat:update(time:seconds, latError)*-60, pidLng:update(time:seconds, lngError)*-60, 180).
        set steer to up + pred.
        if (trueRadar < stopDist) and (alt:radar < 10000){
            set runMode to 5.
        }
    }
    else if runMode = 5{
        //final landing
        set toMul to 1.
        set impactpos to addons:tr:impactpos.
        set thrott to idealThrottle.
        set percentIncrease to 1.
        set pred to r(pidLat:update(time:seconds, latError * percentIncrease)*-15, pidLng:update(time:seconds, lngError * percentIncrease)*-15, 180).
        set steer to up + pred.
        if trueRadar < 500{
            set runMode to 6.
        }
    }
    else if runMode = 6{
        //final landing
        set impactpos to ship:geoposition.
        set thrott to idealThrottle.
        set steer to srfretrograde.
        if ship:verticalspeed > -0.05{
            set thrott to 0.
            unlock steering.
            set runMode to 0.
        }
        if impactTime < 3{
            gear on.
            log ship:geoposition to wow.txt.
        }
    }
    print ("Run mode: " + runMode) at (0, 1).
    print ("Vert diff: " + latDiff) at (0, 2).
    print ("Horiz diff: " + lngDiff) at (0, 3).
    print ("Lat diff: " + (lat1 - lat2)) at (0, 4).
    print ("Lng diff: " + (long1 - long2)) at (0, 5).
    print ("Lat err: " + latError) at (0, 6).
    print ("Lng err: " + lngError) at (0, 7).
    print ("Ground: " + ship:geoposition) at (0, 8).
    log "" + (time:seconds - startTime) + "," + runMode + "," + latDiff + "," + lngDiff to log.csv.
}

sas on.
set sasMode to "RADIALOUT".