type tItem = (id: int);

enum PushItemStatus {
    PushItemSuccess,
    PushItemFail
}

type tPushItemReq = (item: tItem, producer : Producer, reqId: int);
type tPushItemRes = (status: PushItemStatus, resFor: int);

enum PullItemStatus {
    PullItemSuccess, 
    PullItemFail,
    PullItemDone
}

type tPullItemReq = (consumer : Consumer);
type tPullItemRes = (item: tItem, status: PullItemStatus);

event ePushItemReq : tPushItemReq;
event ePushItemRes: tPushItemRes;

event ePullItemReq : tPullItemReq;
event ePullItemRes : tPullItemRes;

event eProducerDone ;

machine Buffer {

    var items : seq[tItem];
    
    start state Init {

        on ePushItemReq do (req: tPushItemReq) {
            items += (sizeof(items), req.item);

            send req.producer, ePushItemRes, (status = PushItemSuccess, resFor = req.reqId );
            goto Init;
        }

        on ePullItemReq do (req: tPullItemReq) {

            var firstItem : tItem;

            if (sizeof(items) == 0) {
                // If there is no items to send to consumer. Send fail status 
                send req.consumer, ePullItemRes, (item = default(tItem),  status = PullItemFail);
                goto Init;
            }


            firstItem = items[0];
            items -= (0);

            send req.consumer, ePullItemRes, (item = firstItem, status = PullItemSuccess);

            goto Init;
        }

        on eProducerDone goto Done;
    }

    state Done {
        on ePullItemReq do (req : tPullItemReq) {
            send  req.consumer, ePullItemRes, (item = default(tItem), status = PullItemDone);
            goto closed;
        }
    }

    state closed {
        entry {
            // Do nothing
        }
    }
}