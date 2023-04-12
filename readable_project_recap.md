## What's The Ask?

Get the Stream Processing Unit to apply Smart Module transformations for the Producer requests coming from the CLI (before commit). At present, Fluvio Smart Modules are only applied for Consumer requests after being read from disk.

## Why This Problem?

While investigating another issue, I had recently gained some insight into how the Stream Processing Unit handles Producer requests, as well as how it uses the Fluvio Smart Engine to transform records for the Consumer. Critically, I noticed that the Smart Engine was well encapsulated -- it was going to be easy to repurpose. Also that the Producer request handler was well organized, it wasn't going to be a nightmare to plug in some additional functionality.

## The Workflow

Where was I going to start? Well, TDD is my friend. There were plenty of test cases for Consumer Smart Module transformations that used the CLI. All I had to do was move the Smart Module options from the Consumer commands over to the Producer commands:

```
echo "foobar@test.com" | fluvio produce emails
fluvio consume emails -B -d --smartmodule downcase
```

becomes:

```
echo "foobar@test.com" | fluvio produce emails --smartmodule downcase
fluvio consume emails -B -d 
```

## The Task

With my TDD workflow ready to go, I made the changes from the outside-in.

### In The CLI
    1. Added the Smart Module options to the CLI Produce Command.
    2. Used those arguments to build SmartModuleInvocation(s), a type used to model Smart Modules during network requests.
    3. Added the SmartModuleInvocation(s) to the ProduceRequest

### For the transfer 
    4. Had to define how the SmartModuleInvocation(s) would be encoded & decoded

### On the SPU
    5. Translated the SmartModuleInvocation(s) into a SmartModuleChain, a type which can be passed to the Smart Engine.
    6. Finally, I fed the SmartModuleChain and the Produce requests's records to the SmartEngine.

## Problems I Faced

### Types In A New Domain

Learning to translate between types in someone else's codebase can be challenging. There are many types to become familiar with in the Stream Processing Unit. Notably, the SPU uses a few different types to model Records. You end up seeing `Batch<Records>`, `Batch<RawRecords>`, `Batch<MemoryRecords>` quite often. It took me a while to figure out when and where to use each, and how to convert between them.

### Compression and Smart Modules

What happens when a Producer sends compressed records and requests the SPU performs a Smart Module Transformation?

The records must be decompressed so they can be fed to the SmartEngine, then compressed again before storage. To pull this off I had to dig up the code that performs the compression, decompression and figure out how to utilize it while handling Producer requests.

### What Next?

Smart Modules that perform filtering and aggregation can now be applied before commit to save storage. Time intensive SmartModule operations can be performed on write, rather than while consuming. 