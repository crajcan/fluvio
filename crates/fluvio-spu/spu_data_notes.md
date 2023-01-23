# Code paths for spu reading and writing to disk

## This defines the different routes the spu will build responses for: 

[PublicService::respond](src/services/public/mod.rs)

### Fetching a file
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FileFetchRequest matches:
- [fetch_handler::handle_fetch_request](src/services/public/fetch_handler.rs)
    - locks a mutex and then calls [FluvioSink.encode_file_slices(&response, header.api_version())](../fluvio-socket/src/sink.rs)
    
Which it got by doing all this to get the file descriptor:

- [fetch_handler::handle_fetch_topic](src/services/public/fetch_handler.rs)
- [fetch_handler::handle_fetch_partition](src/services/public/fetch_handler.rs)
- [SharableReplicaStorage::read_records](src/storage/mod.rs)
- [FileReplica::read_partition_slice](../fluvio-storage/src/replica.rs)
- [FileReplica::read_records](../fluvio-storage/src/replica.rs)
- [FileReplica::records_slice](../fluvio-storage/src/segment.rs)
- [FileRecordsSlice::as_file_slice_from_to](../fluvio-storage/src/records.rs)
- [File::raw_slice](/Users/carsonrajcan/.cargo/registry/src/github.com-1ecc6299db9ec823/fluvio-future-0.4.4/src/fs)
- [File::as_raw_fd()](/Users/carsonrajcan/.cargo/registry/src/github.com-1ecc6299db9ec823/async-fs-1.6.0/src/lib.rs)

### Fetching an offset
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FetchOffsetsRequest matches:
- [offset_request::handle_offset_request](src/services/public/offset_request.rs)

### Fetching File Stream (basic continuous fetch request `flvd consume`)
- [PublicService::respond](src/services/public/mod.rs) - When SpuServerRequest::FileStreamFetchRequest matches:
- [StreamFetchHandler::start](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::fetch](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::process](src/services/public/stream_fetch.rs)
- [StreamFetchHandler::send_back_records](src/services/public/stream_fetch.rs)
    (when a smart moudl eis not present)
    - locks a mutex and then calls [FluvioSink.encode_file_slices(&response_msg, header.api_version())](../fluvio-socket/src/sink.rs)

#### When a smart module is present

If a smart module is found, instead of calling `encode_file_slices`,

We call [SmartModuleChainInstance::process_batch](src/smartengine/batch.rs) which reads records from file to memory
using [FileBatchIterator::next](src/smartengine/file_batch.rs)

In memory records are then process by the SmartModule and stored in `batch`.

Finally we provide the `batch` to:
- [StreamFetchHandler::send_processed_response](src/services/public/stream_fetch.rs)
    - locks a mutex and calls:
    - [FluvioSink.send_repsonse(&response_msg, self.header.api_version)](../fluvio-socket/src/sink.rs)
    