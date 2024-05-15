spec ResponseIsAfterRequest observes eRequest, eResponse {
    var noOfRequest:int ;

     start state Init {
        entry {
            noOfRequest = 0;
        }

        on eRequest do {
            print "On eRequest";
            noOfRequest = noOfRequest + 1;
        }

        on eResponse do {
            print "On eResponse";
            assert noOfRequest == 1, "Expected eRequest to be sent sending eResponse event";
        }
    
     }
}

spec GuranteedRequestProgress observes eRequest, eResponse {
    var numPendingRequests : int;
    start state noPendingRequests {
        on eRequest goto pendingRequests with   {
            numPendingRequests = numPendingRequests + 1;
        }
    }

    hot state pendingRequests {
        on eRequest goto pendingRequests  with {
            numPendingRequests =  numPendingRequests+ 1;
        }

        on eResponse do {
           numPendingRequests= numPendingRequests- 1;

            if (numPendingRequests == 0) {
                goto noPendingRequests;
            }
        }
    }
}


