
event _eStartTimer;
type tTimeout = (term : int);
event eTimeout : tTimeout;
event _eNextTick;
event _cancelTimer;

machine Timer {
    var client : machine;
    var ticks : int;
    var term : int;

    start state Init {
        entry (config : (client : machine, ticks : int, term : int)) {
            client = config.client;
            ticks = config.ticks;
            term = config.term;
        }

        on _eStartTimer goto TimerStarted;
    }

    state TimerStarted {
        entry {
            if ($) {
                ticks = ticks - 1;

                if (ticks == 0) {
                    send client, eTimeout, (term = term,);
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

fun NewTimer(client : machine, ticks : int, term : int) : Timer {
    return new Timer((client = client, ticks = ticks, term = term));
}

fun StartTimer(timer : Timer) {
    send timer, _eStartTimer;
}


fun NewAndStartTimer(client : machine, ticks : int, term : int) : Timer {
    var timer : Timer;
    timer = NewTimer(client, ticks, term);
    StartTimer(timer);
    return timer;
}

fun CancelTimer(timer : Timer) {
    send timer, _cancelTimer;
}