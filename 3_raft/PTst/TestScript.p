module raft = {AppendEntries, Raft, RequestVote, Timer, StepTracker};

test Simple3Node [main =TestWithNormal3NodeRaftCluster ]: 
    assert LeaderHasChoosen in (union raft, {TestWithNormal3NodeRaftCluster});