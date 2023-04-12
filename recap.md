
_Why This Problem?_

[io_uring for blocking File IO](https://github.com/infinyon/fluvio/issues/2215)
[SPU I/O investigation](crates/fluvio-spu/spu_data_notes.md)

_The Workflow_

_The Task_

- CLI
    1. [Add the smartmodule options to the interface](crates/fluvio-cli/src/client/produce/mod.rs)
    2. [Use those arguments to build SmartModuleInvocation(s)](crates/fluvio-cli/src/client/produce/mod.rs)
    3. [Add the SmartModuleInvocation(s) to the ProduceRequest](crates/fluvio/src/producer/partition_producer.rs)
- In Between
    4. [Define how the SmartModuleInvocation(s) would be encoded & decoded](crates/fluvio-spu-schema/src/produce/request.rs)
- SPU
    5. [Use the SmartModuleInvocation(s) to build a SmartModuleChain](crates/fluvio-spu/src/services/public/produce_handler.rs)
    6. [Feed the SmartModuleChain and the batches to the SmartEngine](crates/fluvio-spu/src/services/public/produce_handler.rs)

** Questions / Discussion ** 

_Design Decisions_

- Where to Apply the SmartModules
  - [producer data writing process](crates/fluvio-spu/spu_data_notes.md)
  - [apply_smartmodules_for_partition_request](crates/fluvio-spu/src/services/public/produce_handler.rs)

- Whether to adapt #process_batch() for our needs
  - [original #process_batch()](https://github.com/infinyon/fluvio/blob/e9f238/crates/fluvio-spu/src/smartengine/batch.rs)
  - [new #process_batch()](crates/fluvio-spu/src/smartengine/batch.rs)
  - [struct produce_batch{}](crates/fluvio-spu/src/smartengine/produce_batch.rs)
  - [struct file_batch{}](crates/fluvio-spu/src/smartengine/file_batch.rs)

_Problems I Faced_

- Translating types for #produce_batch() 
  - [apply_smartmodules_for_partition_request](crates/fluvio-spu/src/services/public/produce_handler.rs)
- How to uncompress, recompress
  - [new #process_batch()](crates/fluvio-spu/src/smartengine/batch.rs)
  - [next() in FileBatchIterator](crates/fluvio-spu/src/smartengine/file_batch.rs)
  - [next() in ProduceBatchIterator](crates/fluvio-spu/src/smartengine/produce_batch.rs)
- What happens when a smartmodule filters out every record in a batch
  - [new #process_batch()](crates/fluvio-spu/src/smartengine/batch.rs)
  - [PartitionWriteResult::filtered()](crates/fluvio-spu/src/services/public/produce_handler.rs)


_What Comes Next_

- CLI docs on the website need updating
- Just a little work needed for Rust API? An example of this for the website.
- CLI side producer smartmodules    ?