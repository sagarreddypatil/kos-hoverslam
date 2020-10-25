clearscreen.

set radarOffset to 30.
lock trueRadar to alt:radar - radarOffset.			// Offset radar to get distance from gear to ground
lock g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)
lock maxDecel to (ship:availablethrust / ship:mass) - g.	// Maximum deceleration possible (m/s^2)
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require
lock idealThrottle to stopDist / trueRadar.			// Throttle required for perfect hoverslam
lock impactTime to trueRadar / abs(ship:verticalspeed).		// Time until impact, used for landing gear
set runMode to 1.

set landTarget to latlng(-0.0972080471037579,-74.5576707671538).
wait until ag9.

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

set impactPos to addons:tr:impactpos.
lock lat1 to impactPos:lat.
lock long1 to impactPos:lng.
lock lat2 to landTarget:lat.
lock long2 to landTarget:lng.

lock distTarget to sqrt((lat1-lat2)^2+(long1-long2)^2).

//PID Stuff
lock latError to 0 - (impactPos:LAT - landTarget:LAT).
lock lngError to 0 - (impactPos:LNG - landTarget:LNG).


set pidLat to PIDLOOP(15, 4, 0, -1, 1).
set pidLng to PIDLOOP(10, 4, 3, -1, 1).
set pidLat:SETPOINT to 0.
set pidLng:SETPOINT to 0.

//wait until ETA:APOAPSIS < 15.

rcs on.
sas off.

set thrott to 0.
set steer to srfRetrograde.

lock steering to steer.
lock throttle to thrott.

set startTime to time:seconds.
until runMode = 0{
    if runMode = 1{
        set impactPos to addons:tr:impactpos.
        set steer to up + HEADING(270, 10).
        if time:seconds - startTime > 10{
            set runMode to 2.
        }
    }
    if runMode = 2{
        set impactPos to addons:tr:impactpos.
        //Boostback
        set thrott to 1.0.
        set steer to up + HEADING(270, 10).
        if long1 < long2{
            set runMode to 3.
            //unlock steering.
            set thrott to 0.
        }
    }
    else if runMode = 3{
        set impactPos to addons:tr:impactpos.
        set steer to up.
        set thrott to 0.
        if trueRadar < 40000{
            set runMode to 4.
        }
    }
    else if runMode = 4{
        set impactPos to addons:tr:impactpos.
        //Coasting with guidance
        brakes on.
        set pred to r(pidLat:update(time:seconds, latError)*-45, pidLng:update(time:seconds, lngError)*-45, 180).
        //set pred to r(0, pidLng:update(time:seconds, lngError)*-45, 180).
        set steer to up + pred.
        print (pred) at (10, 6).
        if (trueRadar < stopDist) and (alt:radar < 10000){
            set runMode to 5.
        }
    }
    else if runMode = 5{
        //final landing
        set impactpos to addons:tr:impactpos.
        set thrott to idealThrottle.
        set percentIncrease to max(2, (6000/trueRadar)).
        print percentIncrease at (10, 9).
        set pred to r(pidLat:update(time:seconds, latError * percentIncrease)*-45, pidLng:update(time:seconds, lngError * percentIncrease)*-45, 180).
        set steer to srfRetrograde + pred.
        print pred at (10, 6).
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
            //unlock steering.
            set runMode to 0.
        }
        if impactTime < 3{
            gear on.
        }
    }
    print (trueRadar - stopDist) at (10, 4).
    print (distTarget) at (10, 5).
    print (ship:verticalspeed) at (10, 8).
    print (runmode) at (10, 10).
}
unlock all.
sas on.