module queue = {Buffer, Consumer, Producer};

test SingleProducerBufferConsumer [main = TestWithSingleProducerBufferConsumer]:
    assert AllItemsGetsConsumed in (union queue, {TestWithSingleProducerBufferConsumer});