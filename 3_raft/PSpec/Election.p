
spec LeaderHasChoosen observes eStateUpdate{
    var leaderIds : set[int];

    start state Init {
        entry {
            goto WaitForLeader;
        }
    }

    hot state WaitForLeader {
        entry {
            assert sizeof(leaderIds) == 0, "Leader has already been choosen";
        }

        on eStateUpdate do (args : tStateUpdate) {
            if (args.newState == Leader ) {
                leaderIds += (args.id);
                goto LeaderChoosen;
            }
        }
    }

    state LeaderChoosen {
        entry {
            assert sizeof(leaderIds) == 1, "There should be exactly one leader";
        }

        on eStateUpdate do (args : tStateUpdate) {
            if (args.id in leaderIds) {
                assert args.newState != Leader, "Leader cannot transition to leader again";

                leaderIds -= (args.id);
                goto WaitForLeader;
            } else if (args.newState == Leader) {
                leaderIds += (args.id);
                goto MultipleLeaders;
            }
        }
    }

    hot state MultipleLeaders {
        entry {
            assert sizeof(leaderIds) > 1, "There should be more than one leader";
        }

        on eStateUpdate do (args : tStateUpdate) {
            if (args.id in leaderIds) {
                assert args.newState != Leader, "Leader cannot transition to leader again";

                leaderIds -= (args.id);
                if (sizeof(leaderIds) == 1) {
                    goto LeaderChoosen;
                }
            } else if (args.newState == Leader) {
                leaderIds += (args.id);
            }
        }
    }
} 