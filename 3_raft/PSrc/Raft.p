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
    var heartbeatTimer : Timer;

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
            electionTimer = NewAndStartTimer(this, electionTimeout);
            goto FollowerLoop;
        }

        defer eTimeout;
    }

    state FollowerLoop {
        entry {
            assert nodeState == Follower, "In FollowerLoop while state is not Follower";

            

            while (true) {
                assert electionTimer != default(Timer), "No value set on Election timer";

                receive  { 
                    case eTimeout: {
                        StartElection();
                    }

                    case eRequestVoteArgs: (args : tRequestVoteArgs) {
                        RespondToRequestVote(args);
                    }

                    case eAppendEntriesArgs: (args : tAppendEntriesArgs)  {
                        RespondToAppendEntires(args);
                    }

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
            ResetElectionTimer();

            
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
                    
                    case eRequestVoteArgs: (args : tRequestVoteArgs) {
                        RespondToRequestVote(args);
                    }

                    case eAppendEntriesArgs: (args : tAppendEntriesArgs) {
                        RespondToAppendEntires(args);
                    }
                }
            }
        }
    }

    state LeaderLoop {
        entry {
            assert nodeState == Leader, "In LeaderLoop while state is not Leader";

            while (true) {
                receive { 
                    case eTimeout: {
                        SendHeartbeats();
                    }

                    case eForceTransitionToFollower: (args: tForceTransitionToFollower) {
                        if (args.term != currentTerm) {
                            // Ignore this 
                            continue;
                        }
                        ConvertToFollower(args.newTerm);
                    }

                    case eAppendEntriesArgs: (args : tAppendEntriesArgs) {
                        RespondToAppendEntires(args);
                    }

                    case eRequestVoteArgs: (args : tRequestVoteArgs) {
                        RespondToRequestVote(args);
                    }
                }
            }
        }
    }

    fun RespondToRequestVote(args : tRequestVoteArgs) {
        if (currentTerm > args.term) {
            send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = false);
            return;
        }

        if (args.term > currentTerm) {
            ConvertToFollower(args.term);
        }

        if (votedFor == -1 || votedFor == args.candidateId) {
            votedFor = args.candidateId;
            send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = true);
            return;
        } 

        send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = false);
    }

    fun RespondToAppendEntires(args : tAppendEntriesArgs) {
        if (currentTerm > args.term) {
            send args.from, eAppendEntriesReply, (term = currentTerm,  success = false);
            return;
        }

        ResetElectionTimer();

        if (args.term > currentTerm) {
            ConvertToFollower(args.term);
        }

        send args.from, eAppendEntriesReply, (term = currentTerm, success = true);
        return;
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
        ResetElectionTimer();
        goto FollowerLoop;
    }

    fun ConvertToLeader() {
        nodeState = Leader;
        ResetHeartbeatTimer();
        goto LeaderLoop;
    }

    fun ResetElectionTimer() {
        CancelTimer(electionTimer);
        electionTimer = NewAndStartTimer(this, electionTimeout);
    }

    fun ResetHeartbeatTimer() {
        CancelTimer(heartbeatTimer);
        heartbeatTimer = NewAndStartTimer(this, heartbeatTimeout);
    }

    fun SendHeartbeats() {
        var appendEntries : AppendEntries;
        appendEntries = new AppendEntries((raft = this, peers = peers, term = currentTerm, id = id));
        ResetHeartbeatTimer();
    }
}

type tForceTransitionToFollower = (term : int, newTerm : int);
event eForceTransitionToFollower : tForceTransitionToFollower;
