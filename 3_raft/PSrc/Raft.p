type tRaftConfig = (
    id : int, 
    peers: seq[Raft], 
    electionTimeout: int, 
    heartbeatTimeout: int,
    _maxHeartbeats : int
);

enum NodeState {
    Leader,
    Follower,
    Candidate
}

event eSetRaftConfig : tRaftConfig;

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

    // Variables to make raft finite 
    var _maxHeartbeats : int;
    var _trackedHeartbeats : int;

    start state Init {
        on eSetRaftConfig do (config : tRaftConfig) {
            assert config.electionTimeout > 0, "Election timeout should be greater than 0";
            assert config.heartbeatTimeout > 0, "Heartbeat timeout should be greater than 0";
            assert config.electionTimeout > config.heartbeatTimeout, "Election timeout should be greater than heartbeat timeout";

            id = config.id; 
            peers = config.peers;
            electionTimeout = config.electionTimeout; // Randomize election timeout
            heartbeatTimeout = config.heartbeatTimeout;
            nodeState = Follower;
            currentTerm = 0;
            votedFor = -1 ;
            electionTimer = NewAndStartTimer(this, RandomTimeout(electionTimeout), currentTerm);
            _maxHeartbeats = config._maxHeartbeats;
            _trackedHeartbeats = 0;
            goto MainLoop;
        }
        defer eTimeout, eAppendEntriesArgs, eRequestVoteArgs;
    }

    state MainLoop {
        entry {
            while (true) {
                if (nodeState == Follower) {
                    FollowerLoop();
                } else if (nodeState == Candidate) {
                    CandidateLoop();
                } else if (nodeState == Leader) {
                    LeaderLoop();
                } 
            }
        }
    }

    fun FollowerLoop() {
        assert nodeState == Follower, "In FollowerLoop while state is not Follower";

        while (nodeState == Follower) {
            assert electionTimer != default(Timer), "No value set on Election timer";

            receive  { 
                case eTimeout: (args : tTimeout) {
                    if (args.term != currentTerm) {
                        // Ignore this event
                        continue;
                    }
                    StartElection();
                }

                case eRequestVoteArgs: (args : tRequestVoteArgs) {
                    RespondToRequestVote(args);
                }

                case eAppendEntriesArgs: (args : tAppendEntriesArgs)  {
                    RespondToAppendEntires(args);
                }

                case eDone: {
                    Close();
                }

            }
        }
    }

    fun CandidateLoop() {
        
        assert nodeState == Candidate, "In CandidateLoop while state is not Candidate";
        assert votedFor == id, "In CandidateLoop while votedFor is not id";


        
        while (nodeState == Candidate) {
            receive {
                case eTimeout: (args : tTimeout) {
                    if (args.term != currentTerm) {
                        // Ignore this event
                        continue;
                    }
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
                        print "Ignoring transition to leader event";
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

                case eDone: {
                    Close();
                }

            }
        }
    }

    fun LeaderLoop() {
        assert nodeState == Leader, "In LeaderLoop while state is not Leader";

        while (nodeState == Leader) {
            receive { 
                case eTimeout: (args : tTimeout) {
                    if (args.term != currentTerm) {
                        // Ignore this event
                        continue;
                    }
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

                case eDone: {
                    Close();
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
            ResetElectionTimer();
            send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = true);
        } else {
            send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = false);
        }
    }

    fun RespondToAppendEntires(args : tAppendEntriesArgs) {
        if (currentTerm > args.term) {
            send args.from, eAppendEntriesReply, (term = currentTerm,  success = false);
            return;
        }


        if (args.term > currentTerm) {
            ConvertToFollower(args.term);
        }

        ResetElectionTimer();
        send args.from, eAppendEntriesReply, (term = currentTerm, success = true);
        return;
    }

    fun StartElection() {
        var requestVote : RequestVote ;
        currentTerm = currentTerm + 1;
        votedFor = id;
        nodeState = Candidate;
        requestVote = new RequestVote((raft = this, peers = peers, term = currentTerm, id = id, heartbeatTimeout = heartbeatTimeout));
        ResetElectionTimer();
        announce eStateUpdate, (id = id, newState = Candidate) ;
        _trackedHeartbeats = 0;
    }

    fun ConvertToFollower(newTerm: int) {
        currentTerm = newTerm;
        votedFor = -1;
        nodeState = Follower;
        announce eStateUpdate, (id = id, newState = Follower) ;
        ResetElectionTimer();
        if (heartbeatTimer != default(Timer)) {
            CancelTimer(heartbeatTimer);
        }

        _trackedHeartbeats = 0;
    }

    fun ConvertToLeader() {
        nodeState = Leader;
        announce eStateUpdate, (id = id, newState = Leader) ;
        SendHeartbeats();
        _trackedHeartbeats = 0;
    }

    fun ResetElectionTimer() {
        if (electionTimer != default(Timer)) {
            CancelTimer(electionTimer);
        }
        electionTimer = NewAndStartTimer(this, RandomTimeout(electionTimeout), currentTerm);
    }

    fun ResetHeartbeatTimer() {
        if (heartbeatTimer != default(Timer)) {
            CancelTimer(heartbeatTimer);
        }
        heartbeatTimer = NewAndStartTimer(this, heartbeatTimeout, currentTerm);
    }

    fun SendHeartbeats() {

        var appendEntries : AppendEntries;
        _trackedHeartbeats = _trackedHeartbeats + 1;
        appendEntries = new AppendEntries((raft = this, peers = peers, term = currentTerm, id = id, heartbeatTimeout = heartbeatTimeout ));
        ResetHeartbeatTimer();

        if (_trackedHeartbeats == _maxHeartbeats) {
            StopTesting();
        }
    }

    fun StopTesting() {
        var peer : Raft;

        foreach (peer in peers) {
            send peer, eDone;
        }

        goto Done;
    }

    fun Close() {
        if (electionTimer != default(Timer)) {
            CancelTimer(electionTimer);
        }

        if (heartbeatTimer != default(Timer)) {
            CancelTimer(heartbeatTimer);
        }
        goto Done;
    }


    state Done {
        ignore eAppendEntriesArgs, eAppendEntriesReply, eRequestVoteArgs, eRequestVoteReply, eTimeout, eTransitionToLeader, eForceTransitionToFollower;
        
        entry {
            // Do nothing
        }
    }

    fun RandomTimeout(timeout : int) : int {
        return timeout + choose(timeout);
    }
}

type tForceTransitionToFollower = (term : int, newTerm : int);
event eForceTransitionToFollower : tForceTransitionToFollower;

type tStateUpdate = (id : int, newState : NodeState);
event eStateUpdate : tStateUpdate;