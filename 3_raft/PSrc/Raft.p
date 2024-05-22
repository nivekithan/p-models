type tRaftConfig = (id : int, peers: seq[Raft], electionTimeout: int, heartbeatTimeout: int);

enum NodeState {
    Leader,
    Follower,
    Candidate
}

machine Raft {
    // Raft Config variables 
    var id : int;
    var peers : seq[Raft];
    var electionTimeout : int;
    var heartbeatTimeout: int;
    var nodeState : NodeState;

    // Raft Perist Variables 
    var currentTerm: int; // >= 0
    var votedFor : int; // -1 if none 


    // Internal Variables 
    var electionTimer : Timer;

    start state Init {
        entry (config: tRaftConfig) {
            assert config.electionTimeout > 0, "Election timeout should be greater than 0";
            assert config.heartbeatTimeout > 0, "Heartbeat timeout should be greater than 0";
            assert config.electionTimeout > config.heartbeatTimeout, "Election timeout should be greater than heartbeat timeout";

            id = config.id; 
            peers = config.peers;
            electionTimeout = config.electionTimeout + choose(electionTimeout); // Randomize election timeout
            heartbeatTimeout = config.heartbeatTimeout;
            nodeState = Follower;
            currentTerm = 0;
            votedFor = -1 ;
            goto FollowerLoop;
        }
    }

    state FollowerLoop {
        entry {
            assert nodeState == Follower, "In FollowerLoop while state is not Follower";
            electionTimer = NewAndStartTimer(this, electionTimeout);

            receive  { 
                case eTimeout: {
                    StartElection();
                }
            }
        }
    }

    state CandidateLoop {
        entry {
            var requestVote : RequestVote ;
            
            assert nodeState == Candidate, "In CandidateLoop while state is not Candidate";
            assert votedFor == id, "In CandidateLoop while votedFor is not id";

            // Ask for Votes from all peers 
            requestVote = new RequestVote((raft = this, peers = peers, term = currentTerm, id = id));
            electionTimer = NewAndStartTimer(this, electionTimeout);

            
            while (true) {
                receive {
                    case eTimeout: {
                        StartElection();
                    } 

                    case eForceTransitionToFollower: (args: tForceTransitionToFollower) {
                        if (args.term != currentTerm) {
                            // Ignore this event
                            continue;
                        }
                        ConvertToFollower(args.newTerm);
                    }

                    case eTransitionToLeader: (args: tTransitionToLeader) {
                        if (args.term != currentTerm) {
                            // Ignore this event
                            continue;
                        }

                        ConvertToLeader();
                    }
                }
            }
        }
    }

    state LeaderLoop {
        entry {

        }
    }

    fun StartElection() {
        currentTerm = currentTerm + 1;
        votedFor = id;
        nodeState = Candidate;
        goto CandidateLoop;
    }

    fun ConvertToFollower(newTerm: int) {
        currentTerm = newTerm;
        votedFor = -1;
        nodeState = Follower;
        goto FollowerLoop;
    }

    fun ConvertToLeader() {
        nodeState = Leader;
        goto LeaderLoop;
    }
}