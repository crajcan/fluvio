# SPU performance notes

## Code paths for spu reading and writing to disk

### This defines the different routes the spu will build responses for: 

[PublicService::respond](src/services/public/mod.rs)

### Fetching a file
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FileFetchRequest matches:
- [fetch_handler::handle_fetch_request](src/services/public/fetch_handler.rs)
    - locks a mutex and then calls [FluvioSink.encode_file_slices(&response, header.api_version())](../fluvio-socket/src/sink.rs)
    - calls [FluvioSink.write_store_values](../fluvio-socket/src/sink.rs)
      - When write_store_values receives an AsyncFileSlice, calls [ZeroCopy::copy_slice](fluvio future crate, zero_copy.rs)
        - Spawns a blocking task to write data,

_according to `async-std/src/task/spawn_blocking.rs`, this task is spawned onto a thread pool so we may be able to leave this code alone without using our new threadpool implementation._

#### Fetching File Stream (basic continuous fetch request `flvd consume`)
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FileStreamFetchRequest matches:
- [StreamFetchHandler::start](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::fetch](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::process](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::send_back_records](src/services/public/stream_fetch.rs)
    (when a smart module is not present)
    - locks a mutex and then calls [FluvioSink.encode_file_slices(&response_msg, header.api_version())](../fluvio-socket/src/sink.rs)
      - When write_store_values receives already encoded bytes, calls [AsyncWriteExt::write_all](futures util crate)
  
_could potentially be a use case for our threadpool_

#### When a smart module is present

If a smart module is found, instead of calling `encode_file_slices`,

We call [SmartModuleChainInstance::process_batch](src/smartengine/batch.rs) which reads records from file to memory
using [FileBatchIterator::next](src/smartengine/file_batch.rs). FileBatchIterator::next using the nix util [pread](nix/src/sys/uio.rs)

_since we're using `pread` here this read into memory could be a use case for our threadpool_

In memory records are then process by the SmartModule and stored in `batch`.

Finally we provide the `batch` to:
- [StreamFetchHandler::send_processed_response](src/services/public/stream_fetch.rs)
    - locks a mutex and calls:
    - [FluvioSink.send_reponse(&response_msg, self.header.api_version)](../fluvio-socket/src/sink.rs)
    - [SinkFrame::send](futures_util/src/sink/mod.rs)

_this write to the sink could also be a use case for our threadpool, according to the implmentation it creates a future_
    
#### Fetching an offset (doesn't seem to do any _slow_ IO)
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FetchOffsetsRequest matches:
- [offset_request::handle_offset_request](src/services/public/offset_request.rs)

#### Producing
-[PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::ProduceRequest matches:
  -[produce_handler::handle_produce_request](src/services/public/produce_handler.rs)
    -[produce_handler::handle_produce_topic](src/services/public/produce_handler.rs)
      -[produce_handler::handle_produce_partition](src/services/public/produce_handler.rs)
        -[LeaderReplicaState::write_record_set](src/replication/leader/replica_state.rs)
          - [SharableReplicaStorage::write_record_set](src/storage/mod.rs)
            - [FileReplica::write_recordset](../fluvio-storage/src/replica.rs)
              - [FileReplica::write_batch](../fluvio-storage/src/replica.rs)
                - [Segment::append_batch](../fluvio-storage/src/segment.rs)
                  - [MutFileRecords::write_batch](../fluvio-storage/src/mut_records.rs)
                    - [Write::write_all](std/src/io/mod.rs)
          - [LeaderReplicaState::notify_folowers](src/replication/leader/replica_state.rs)
          - [LeaderReplicaState::update_status](src/replication/leader/replica_state.rs)

## Solution

### The Request

```
This causes SPU to use too much memory. Ideally, we should just have a thread per core and a thread pool to perform blocking I/O. To solve this:

* Move all I/O to non-blocking async call (io_uring, etc)
* Assign fixed threads to each core.
* Carefully tune blocking threads.
```

### Definitions

_Blocking IO_: When the current thread can do nothing but wait until the I/O opeartion is complete. The only way to perform concurrent work with blocking I/O is with multiple threads.

_Non-blocking async call)_: 

_io\_uring_:

### Strategy

1. Create a threadpool
   
_Q: on SPU startup?_

2. Create one thread per core

_Q: How do we know how many cores on the machine?_

3. 