
machine Consumer {

    var buffer : Buffer;
    var timer : Timer;

    start state Init {
        entry (input: (buffer : Buffer) ) {
            buffer = input.buffer;
            timer = NewAndStartTimer(this, 5);
            goto PullItems;
        }

        defer eTimeout;
    }

    state PullItems {
        entry {
            send buffer, ePullItemReq, (consumer = this,);
        }

        on ePullItemRes do (res : tPullItemRes) {
            if (res.status == PullItemFail) {
                goto WaitForTimeout;
            }

            if (res.status == PullItemSuccess) {
                // Process the item then goto PullItems
                goto WaitForTimeout;
            }

            if (res.status == PullItemDone) {
                goto Done;
            }
        }

        defer eTimeout;
    }

    hot state WaitForTimeout {
        on eTimeout do {
            timer = NewAndStartTimer(this, 5);
            goto PullItems;
        }
    }

    state Done {
        entry {
            CancelTimer(timer); 
        }

        ignore eTimeout;
    }

}