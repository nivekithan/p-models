type tRequestVoteArgs = (term : int, candidateId: int, from: machine);
type tRequestVoteReply = (term : int, voteGranted: bool);

event eRequestVoteArgs : tRequestVoteArgs;
event eRequestVoteReply: tRequestVoteReply;

type tTransitionToLeader = (term : int);
event eTransitionToLeader: tTransitionToLeader;


machine RequestVote {
    var raftMachine : Raft;

    start state Init {
        entry (config : (raft : Raft, peers : seq[Raft], term : int, id : int, heartbeatTimeout: int))  {
            var peer : Raft;
            var responseRecived, totalVotes : int;
            var timer : Timer;
            var sentElectionResult : bool;

            raftMachine = config.raft;

            foreach (peer in config.peers) {
                send peer, eRequestVoteArgs, (term = config.term, candidateId = config.id, from = this);
            }

            responseRecived = 0;
            totalVotes = 1;

            timer = NewAndStartTimer(this, config.heartbeatTimeout * 2, 0);

            while (responseRecived < sizeof(config.peers)) {
                receive { 
                    case eRequestVoteReply: (reply: tRequestVoteReply) {
                        if (reply.term > config.term) {
                            send  raftMachine, eForceTransitionToFollower, (term = config.term, newTerm = reply.term);
                        } else if (reply.voteGranted) {
                            totalVotes = totalVotes + 1;

                            if (!sentElectionResult && totalVotes > sizeof(config.peers) / 2) {
                                send raftMachine, eTransitionToLeader, (term = config.term,);
                                CancelTimer(timer);
                                sentElectionResult = true;
                                goto Done;
                            }

                        } 
                    }

                    case eTimeout: (args : tTimeout) {
                        goto Done;
                    }
                }

                responseRecived = responseRecived + 1;
            }

            goto Done;
        }
    }

    state Done {
        ignore eTimeout, eRequestVoteReply;
        entry {
            // Do nothing
        }
    }
}