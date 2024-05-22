module queue = {Buffer, Consumer, Producer, Timer};

test SingleProducerBufferConsumer [main = TestWithSingleProducerBufferConsumer]:
    assert AllItemsGetsConsumed in (union queue, {TestWithSingleProducerBufferConsumer});