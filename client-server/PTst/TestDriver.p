machine TestWithSingleClient {
    start state Init {
        entry {
            var server: Server; 
            var client: Client;

            server = new Server();
            client = new Client((serv = server, id = 0));
        }
    }
}


