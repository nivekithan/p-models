type tRequestVoteArgs = (term : int, candidateId: int, from: machine);
type tRequestVoteReply = (term : int, voteGranted: bool);

event eRequestVoteArgs : tRequestVoteArgs;
event eRequestVoteReply: tRequestVoteReply;

type tForceTransitionToFollower = (term : int, newTerm : int);
event eForceTransitionToFollower : tForceTransitionToFollower;

type tTransitionToLeader = (term : int);
event eTransitionToLeader: tTransitionToLeader;


machine RequestVote {
    var raftMachine : Raft;

    start state Init {
        entry (config : (raft : Raft, peers : seq[Raft], term : int, id : int))  {
            var peer : Raft;
            var responseRecived, totalVotes : int;

            raftMachine = config.raft;

            foreach (peer in config.peers) {
                send peer, eRequestVoteArgs, (term = config.term, candidateId = config.id, from = this);
            }

            responseRecived = 0;
            totalVotes = 1;

            while (responseRecived < sizeof(config.peers)) {
                receive { 
                    case eRequestVoteReply: (reply: tRequestVoteReply) {
                        if (reply.term > config.term) {
                            send  raftMachine, eForceTransitionToFollower, (term = config.term, newTerm = reply.term);
                        } else if (reply.voteGranted) {
                            totalVotes = totalVotes + 1;

                            if (totalVotes > sizeof(config.peers) / 2) {
                                send raftMachine, eTransitionToLeader, (term = config.term,);
                            }
                        } 
                    }
                }

                responseRecived = responseRecived + 1;
            }
        }
    }
}