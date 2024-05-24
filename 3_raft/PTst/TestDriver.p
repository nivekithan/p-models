machine TestWithNormal3NodeRaftCluster {
    var node1, node2, node3 : Raft;
    start state Init {
        entry {
            var node1Peers, node2Peers, node3Peers : seq[Raft];
            // var stepTracker : Timer;
            var stepTracker : StepTracker;

            node1 = new Raft();
            node2 = new Raft();
            node3 = new Raft();

            node1Peers += (0, node2);
            node1Peers += (1, node3);

            node2Peers += (0, node1); 
            node2Peers += (1, node3);

            node3Peers += (0, node2);
            node3Peers += (1, node1);


            send node1, eSetRaftConfig, (id = 1, peers = node1Peers, electionTimeout = 15, heartbeatTimeout = 5, _maxHeartbeats = 10);
            send node2, eSetRaftConfig, (id = 2, peers = node2Peers, electionTimeout = 15, heartbeatTimeout = 5, _maxHeartbeats = 10);
            send node3, eSetRaftConfig, (id = 3, peers = node3Peers, electionTimeout = 15, heartbeatTimeout = 5, _maxHeartbeats = 10);

        }
        
    }
}
