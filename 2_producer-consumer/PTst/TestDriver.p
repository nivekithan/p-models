machine TestWithSingleProducerBufferConsumer {
    start state Init {
        entry {
            var buffer : Buffer;
            var producer : Producer;
            var consumer : Consumer;

            buffer = new Buffer();
            producer = new Producer((buffer = buffer,));
            consumer = new Consumer((buffer = buffer,));
            
            send producer, eSendItems, (totalItems = 10,);
        }
    }
}