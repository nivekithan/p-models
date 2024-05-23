type tAppendEntriesArgs = (term : int, leaderId : int, from : machine);
type tAppendEntriesReply = (term : int, success : bool);

event eAppendEntriesArgs : tAppendEntriesArgs;
event eAppendEntriesReply : tAppendEntriesReply;


machine AppendEntries {

    start state Init {
        entry (args : (raft : Raft, peers : seq[Raft], term : int, id : int)) {

            var peer : Raft; 
            var responseRecived : int;

            foreach (peer in args.peers) {
                send peer, eAppendEntriesArgs, (term = args.term, leaderId = args.id, from = this);
            }

            responseRecived = 0;

            while (responseRecived < sizeof(args.peers)) {
                receive {
                    case eAppendEntriesReply: (reply : tAppendEntriesReply) {
                        if (reply.term > args.term) {
                            send args.raft, eForceTransitionToFollower, (term = args.term, newTerm = reply.term);
                            continue;
                        }
                    }
                }
            }
            

        }
    }

}