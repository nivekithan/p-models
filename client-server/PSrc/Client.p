machine Client {
    start state Init {
        
        entry(input: (serv: Server, id: int)) {
            send input.serv, eRequest, (client = this, reqId = 0);
        }

        on eResponse goto Done;
    }

    state Done {
        entry {
            // Do nothing
        }
    }
}