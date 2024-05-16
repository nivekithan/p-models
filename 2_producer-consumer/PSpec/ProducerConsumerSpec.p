
spec AllItemsGetsConsumed observes eSendItems, ePullItemRes, eProducerDone {
    var noOfItems : int;
    start state Init {

        entry {
            noOfItems = 0;
        }

        on eSendItems goto WaitForPulls with (input: tSendItems) {
            noOfItems = input.totalItems;
        }

        on ePullItemRes do (input : tPullItemRes) {
            assert input.status == PullItemFail, "Expected PullItemRes status to be PullItemFail" ;
        }

        on eProducerDone goto WaitForPullItemDone;
    }

    hot state WaitForPulls {

        on ePullItemRes do (input: tPullItemRes) {
            if (input.status == PullItemFail) {
                goto WaitForPulls ;

            }
            noOfItems = noOfItems -  1;
            
            if (noOfItems == 0) {
                goto Init;
            } else {
                goto WaitForPulls;
            }
        }

        on eProducerDone goto WaitForPullItemDone;

    }

    hot state WaitForPullItemDone {

        on ePullItemRes do (input: tPullItemRes) {
            if (input.status == PullItemDone ) {
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