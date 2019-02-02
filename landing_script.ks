clearscreen.

set radarOffset to 30.
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

set pidLat to PIDLOOP(3, 1, 1, -1, 1).
set pidLng to PIDLOOP(3, 1, 1, -1, 1).
set pidLat:SETPOINT to 0.
set pidLng:SETPOINT to 0.

wait until ETA:APOAPSIS < 15.

rcs on.
sas off.

set thrott to 0.
set steer to srfprograde.

lock steering to steer.
lock throttle to thrott.

set randomCondition to true.

until runMode = 0{
    if runMode = 1{
        //Boostback
        set steer to up + r(0, 65, 180).
        if randomCondition{ wait 1. }
        set randomCondition to false.
        set thrott to 0.8.
        if long1 < long2-0.1{
            set runMode to 2.
            //unlock steering.
            set thrott to 0.
        }
    }
    else if runMode = 2{
        set steer to up.
        set thrott to 0.
        if trueRadar < 25000{
            set runMode to 3.
        }
    }
    else if runMode = 3{
        //Coasting with guidance
        brakes on.
        set pred to r(pidLat:update(time:seconds, latError)*-45, pidLng:update(time:seconds, lngError)*-45, 90).
        //set pred to r(0, pidLng:update(time:seconds, lngError)*-45, 180).
        set steer to up + pred.
        print (pred) at (10, 6).
        if trueRadar < stopDist{
            set runMode to 4.
        }
    }
    else if runMode = 4{
        //final landing
        set impactpos to landtarget.
        set thrott to idealThrottle.
        set steer to srfretrograde + r(0, 0, 180).
        if ship:verticalspeed > -0.05{
            set thrott to 0.
            //unlock steering.
            set runMode to 0.
        }
    }
    print (trueRadar - stopDist) at (10, 4).
    print (distTarget) at (10, 5).
}
unlock all.
sas on.