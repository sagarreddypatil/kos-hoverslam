clearscreen.

set radarOffset to 30.
lock trueRadar to alt:radar - radarOffset.			// Offset radar to get distance from gear to ground
lock g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)
lock maxDecel to (ship:availablethrust / ship:mass) - g.	// Maximum deceleration possible (m/s^2)
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require
lock idealThrottle to stopDist / trueRadar.			// Throttle required for perfect hoverslam
lock impactTime to trueRadar / abs(ship:verticalspeed).		// Time until impact, used for landing gear

set vabHelipad to latlng(-0.0968033160074459,-74.6186867121389).
set launchpad to latlng(-0.0971945382219646,-74.557660817427).

set landTarget to launchpad.

set steeringManager:maxstoppingtime to 7.
set steeringManager:pitchpid:kd to 1.25.
set steeringManager:yawpid:kd to 1.25.

set runMode to 0.

wait until ag9.
set startTime to time:seconds.

set runMode to 1.

set impactProvider to "tr". //tr is for trajectories, gr can be used for geoposition but doesn't really matter

function impactPos {
    if(impactProvider = "tr") return addons:tr:impactpos.
    else return ship:geoPosition.
}


set pidLat to PIDLOOP(15, 0, 5, -1, 1).
set pidLng to PIDLOOP(15, 0, 5, -1, 1).
set pidLat:setpoint to landTarget:lat.
set pidLng:setpoint to landTarget:lng.

set boostbackPidLat to PIDLOOP(2, 0, 0, -1, 1).
set boostbackPidLat:setpoint to landTarget:lat. 

rcs on.
sas off.

set thrott to 0.
set steer to up.

lock steering to steer.
lock throttle to thrott.

set pred to r(0, 0, 0).

log "time,runMode,latErr,lngErr,latPidOut,lngPidOut" to "telem.csv".

set entryBurn to true.

until runMode = 0{

    if runMode = 1{
        set tgt to up + r(0, 75, 180).
        set steer to tgt.
        if vang(ship:facing:forevector, tgt:forevector) < 5{
            set runMode to 2.
        }
    }
    else if runMode = 2{
        //Boostback
        set pred to r(boostbackPidLat:update(time:seconds, impactPos():lat) * -2.5, 75, 180).
        set steer to up + pred.
        
        set thrott to 1.0.
        if impactPos():lng < landTarget:lng{
            set runMode to 3.
            set thrott to 0.
        }
    }
    else if runMode = 3{
        if ship:verticalspeed < 0{
            set steer to srfRetrograde.
        }
        else{
            set steer to up.
        }

        set thrott to 0.
        if trueRadar < 50000{
            set runMode to 4.
            brakes on.
        }
    }
    else if runMode = 4{
        //Coasting with guidance
        set pred to r(pidLat:update(time:seconds, impactPos():lat)*45, pidLng:update(time:seconds, impactPos():lng)*45, 180).
        if entryBurn{
            set pred to r(0, 0, 0).
        }
        set steer to srfRetrograde + pred.
        // if (impactProvider <> "gr") and (ship:altitude < 8000){
        //     set impactProvider to "gr".
        // }

        if ship:verticalspeed < -900{
            set entryBurn to true.
        }
        if ship:verticalspeed > -800 and entryBurn{
            set entryBurn to false.
        }

        if entryBurn{
            set thrott to 1.0.
        }
        else{
            set thrott to 0.0.
        }

        if (trueRadar < stopDist) and (ship:altitude < 6000){
            set runMode to 5.
            //steeringManager:resettodefault().
            set pidLat:kp to 100.
            set pidLng:kp to 100.
            set pidLat:kd to 15.
            set pidLng:kd to 15.
        }
    }
    else if runMode = 5{
        //final landing
        set thrott to idealThrottle.
        set pred to r(pidLat:update(time:seconds, impactPos():lat)*45, pidLng:update(time:seconds, impactPos():lng)*45, 180).
        set steer to srfRetrograde + pred.
        if ship:verticalspeed > -250{
            set runMode to 6.
            set impactProvider to "gr".
        }
    }
    else if runMode = 6{
        //final landing
        set thrott to idealThrottle.
        set pred to r(pidLat:update(time:seconds, impactPos():lat)*-90, pidLng:update(time:seconds, impactPos():lng)*-90, 180).
        set steer to srfRetrograde + pred.
        if ship:verticalspeed > -100{
            set runMode to 7.
            set pred to r(0, 0, 0).
        }
    }
    else if runMode = 7{
        //final landing
        set thrott to idealThrottle.
        set steer to srfRetrograde.
        if ship:verticalspeed > -0.05{
            set thrott to 0.
            //unlock steering.
            set runMode to 0.
        }
        if impactTime < 3{
            gear on.
        }
    }
    print ("Run mode: " + runMode + "             ") at (0, 1).
    print ("Lat err: " + pidLat:error + "             ") at (0, 2).
    print ("Lng err: " + pidLng:error + "             ") at (0, 3).
    print ("Pred: " + pred + "              ") at (0, 4).
    print("Vertical Speed: " + ship:verticalspeed + "              ") at (0, 5).
    if runMode > 3 and runMode < 7{
        log (time:seconds - startTime) + "," + runMode + "," + pidLat:error + "," + pidLng:error + "," + pidLat:output + "," + pidLng:output to "telem.csv".
    }
}
unlock all.
sas on.