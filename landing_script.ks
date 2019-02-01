clearscreen.
set radarOffset to 14.
lock trueRadar to alt:radar - radarOffset.			// Offset radar to get distance from gear to ground
lock g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)
lock maxDecel to (ship:availablethrust / ship:mass) - g.	// Maximum deceleration possible (m/s^2)
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require
lock idealThrottle to stopDist / trueRadar.			// Throttle required for perfect hoverslam
lock impactTime to trueRadar / abs(ship:verticalspeed).		// Time until impact, used for landing gear
set runMode to 1.
set landTarget to latlng(-0.10266804865356,-74.575385655446).

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

lock impactPos to addons:tr:impactpos.
lock lat1 to impactPos:lat.
lock long1 to impactPos:lng.
lock lat2 to landTarget:lat.
lock long2 to landTarget:lng.

lock distTarget to sqrt((lat1-lat2)^2+(long1-long2)^2).

//PID Stuff
lock latError to 0 - (impactPos:LAT - landTarget:LAT).
lock lngError to 0 - (impactPos:LNG - landTarget:LNG).

set pidLat to PIDLOOP(10, 1, 0, -1, 1).
set pidLng to PIDLOOP(10, 1, 0, -1, 1).
set pidLat:SETPOINT to 0.
set pidLng:SETPOINT to 0.

wait until ETA:APOAPSIS < 10.

rcs on.
sas off.

until runMode = 0{
    if runMode = 1{
        //Boostback
        lock steering to up + r(0, 80, 90).
        lock throttle to 1.0.
        if distTarget < 0.1{
            set runMode to 2.
            unlock steering.
            unlock throttle.
        }
    }
    else if runMode = 2{
        //Coasting with guidance
        brakes on.
        lock steering to r(pidLat:update(time:seconds, latError)*90, pidLng:update(time:seconds, lngError)*90, 90).
        print (steering) at (10, 6).
        if trueRadar < stopDist{
            set runMode to 3.
        }
    }
    else if runMode = 3{
        lock throttle to idealThrottle.
        lock steering to srfretrograde + r(0, 0, 90).
        if ship:verticalspeed > -0.05{
            unlock throttle.
            unlock steering.
            set runMode to 0.
        }
    }
    print (trueRadar - stopDist) at (10, 4).
    print (distTarget) at (10, 5).
}
unlock throttle.
unlock steering.
sas on.
