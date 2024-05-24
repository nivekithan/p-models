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
            goto FollowerLoop;
        }
        defer eTimeout, eAppendEntriesArgs, eRequestVoteArgs;
    }

    state FollowerLoop {
        entry {
            assert nodeState == Follower, "In FollowerLoop while state is not Follower";

            while (true) {
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
    }

    state CandidateLoop {
        entry {
            var requestVote : RequestVote ;
            
            assert nodeState == Candidate, "In CandidateLoop while state is not Candidate";
            assert votedFor == id, "In CandidateLoop while votedFor is not id";

            // Ask for Votes from all peers 
            requestVote = new RequestVote((raft = this, peers = peers, term = currentTerm, id = id, heartbeatTimeout = heartbeatTimeout));
            ResetElectionTimer();

            
            while (true) {
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
    }

    state LeaderLoop {
        entry {
            assert nodeState == Leader, "In LeaderLoop while state is not Leader";

            while (true) {
                receive { 
                    case eTimeout: (args : tTimeout) {
                        if (args.term != currentTerm) {
                            // Ignore this event
                            continue;
                        }
                        SendHeartbeats();
                        ResetHeartbeatTimer();
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
    }

    fun RespondToRequestVote(args : tRequestVoteArgs) {
        if (currentTerm > args.term) {
            send args.from, eRequestVoteReply, (term = currentTerm, voteGranted = false);
            return;
        }

        if (args.term > currentTerm) {
            currentTerm = args.term;
            votedFor = -1;
            send this, eForceTransitionToFollower, (term = args.term, newTerm = args.term);
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
        var termUpdated : bool;
        termUpdated = false;
        if (currentTerm > args.term) {
            send args.from, eAppendEntriesReply, (term = currentTerm,  success = false);
            return;
        }


        if (args.term > currentTerm) {
            currentTerm = args.term;
            votedFor = -1;
            termUpdated = true;
        }

        ResetElectionTimer();
        send args.from, eAppendEntriesReply, (term = currentTerm, success = true);
        if (termUpdated) {
            send this, eForceTransitionToFollower, (term = args.term, newTerm = args.term);
        }
        return;
    }

    fun StartElection() {
        currentTerm = currentTerm + 1;
        votedFor = id;
        nodeState = Candidate;
        announce eStateUpdate, (id = id, newState = Candidate) ;
        _trackedHeartbeats = 0;
        goto CandidateLoop;
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
        goto FollowerLoop;
    }

    fun ConvertToLeader() {
        nodeState = Leader;
        announce eStateUpdate, (id = id, newState = Leader) ;
        SendHeartbeats();
        ResetHeartbeatTimer();
        _trackedHeartbeats = 0;
        goto LeaderLoop;
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

        send this, eDone;
        foreach (peer in peers) {
            send peer, eDone;
        }
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