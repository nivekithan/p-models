event eStartTimer; 
event eTimeout;
event eCancelTimer;

event eNextTick;

machine Timer {
    var client : machine;
    var ticks: int;

    start state Init {
        entry(input: (client : machine, ticks : int)) {
            client = input.client;
            ticks = input.ticks;
        }

        on eStartTimer goto TimerStarted ;
    }

    hot state TimerStarted {

        entry {
            if ($) {
                ticks = ticks - 1;

                if (ticks == 0 ) {
                    send client, eTimeout;
                    goto Done;
                }

                send this, eNextTick;
            } else {
                send this, eNextTick;
            }
        }

        on eNextTick goto TimerStarted;
        on eCancelTimer goto Done;
    }

    state Done {
        entry {
            // Do nothing
        }

        ignore eCancelTimer, eNextTick;
    }
}

fun NewTimer(client: machine, ticks : int) : Timer {
    return new Timer((client = client, ticks = ticks));
}

fun StartTimer(timer: Timer) {
    send timer, eStartTimer;
}

fun NewAndStartTimer(client : machine, ticks : int) : Timer {
    var timer : Timer;
    timer = NewTimer(client, ticks);
    StartTimer(timer);
    return timer;

}

fun CancelTimer(timer: Timer) {
    send timer, eCancelTimer;
}