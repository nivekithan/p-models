
event _eStartTimer;
event eTimeout;
event _eNextTick;
event _cancelTimer;

machine Timer {
    var client : machine;
    var ticks : int;

    start state Init {
        entry (config : (client : machine, ticks : int)) {
            client = config.client;
            ticks = config.ticks;
        }

        on _eStartTimer goto TimerStarted;
    }

    state TimerStarted {
        entry {
            if ($) {
                ticks = ticks - 1;

                if (ticks == 0) {
                    send client, eTimeout;
                    goto Done;
                }

                send this, _eNextTick;
            } else {
                send this, _eNextTick;
            }
        }

        on _eNextTick goto TimerStarted;
        on _cancelTimer goto Done;
    }

    state Done {
        entry {
        // Do Nothing 
        }
        ignore _eNextTick, _cancelTimer;
    }
}

fun NewTimer(client : machine, ticks : int) : Timer {
    return new Timer((client = client, ticks = ticks));
}

fun StartTimer(timer : Timer) {
    send timer, _eStartTimer;
}


fun NewAndStartTimer(client : machine, ticks : int) : Timer {
    var timer : Timer;
    timer = NewTimer(client, ticks);
    StartTimer(timer);
    return timer;
}

fun CancelTimer(timer : Timer) {
    send timer, _cancelTimer;
}