
machine Consumer {

    var buffer : Buffer;

    start state Init {
        entry (input: (buffer : Buffer) ) {
            buffer = input.buffer;
            goto PullItems;
        }
    }

    state PullItems {
        entry {
            print "Sending PullItems";
            send buffer, ePullItemReq, (consumer = this,);
        }

        on ePullItemRes do (res : tPullItemRes) {
            if (res.status == PullItemFail) {
                goto PullItems;
            }

            if (res.status == PullItemSuccess) {
                // Process the item then goto PullItems
                goto PullItems;
            }

            if (res.status == PullItemDone) {
                goto Done;
            }
        }

    }

    state Done {
        entry {
            // Do nothing
        }
    }

}