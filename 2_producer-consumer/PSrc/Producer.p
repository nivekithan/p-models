
type tSendItems = (totalItems : int);
event eSendItems : tSendItems;

machine Producer {
    var buffer : Buffer;

    start state Init {
        entry (input : ( buffer : Buffer)) {
            buffer = input.buffer;
        }
        on eSendItems goto SendItems;

    }

    state SendItems {

        entry (input: tSendItems ) {
            var i, totalItems, itemsSent, nextId : int;

            i  = 0;
            totalItems = input.totalItems;
            itemsSent  = 0 ;

            while (i < totalItems) {

                if (totalItems == 0 || totalItems == itemsSent) {
                    goto AllItemsSent;
                }

                nextId = itemsSent + 1;

                send buffer, ePushItemReq, (item = (id = nextId,), producer = this, reqId = nextId);

                receive { 
                    case ePushItemRes: (result : tPushItemRes) {
                        // Do nothing
                    }
                }

                itemsSent =  itemsSent + 1;

                i = i + 1;
            }

            send buffer, eProducerDone;

        }
    }

    state AllItemsSent {
        entry {
            // Do nothing
        }
    }
}