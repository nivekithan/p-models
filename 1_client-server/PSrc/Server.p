type tRequest = (client: Client, reqId: int);

event eRequest : tRequest;  
event eResponse;


machine Server {
    start state WaitForRequest {
        on eRequest do (req: tRequest) {
            send req.client, eResponse; 
        }
    }
}