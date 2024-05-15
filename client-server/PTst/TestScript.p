
module client = {Client, Server };

test singleClient [main=TestWithSingleClient]:
    assert ResponseIsAfterRequest, GuranteedRequestProgress in 
    (union client, { TestWithSingleClient } );