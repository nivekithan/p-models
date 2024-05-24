event _eCount;
event eDone;

machine StepTracker {
    var for : machine;
    var steps : int;

    start state Init {
        entry (config : (for : machine, steps : int)) {
            for = config.for;
            steps = config.steps;
            goto Counting;
        }
    }

    state Counting {
        entry {
            steps = steps - 1;

            if (steps == 0) {
                goto Done;
            }

            send this, _eCount;
        }

        on _eCount do {
            goto Counting;
        }

        
    }

    state Done {
        entry {
            send for, eDone;
        }
    }

}