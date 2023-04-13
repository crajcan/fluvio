

We can use the [smdk](foobar) to generate a map type SmartModule.

```
mkdir weather_research_group
cd weather_research_group
../fluvio/target/debug/smdk generate \
    --no-params \
    --sm-type map \
    --project-group weather_research_group \
    --sm-public false \
    weather_button_map
```

This gives us a boilerplate _map_ SmartModule:

```
use fluvio_smartmodule::{smartmodule, Result, Record, RecordData};

#[smartmodule(map)]
pub fn map(record: &Record) -> Result<(Option<RecordData>, RecordData)> {
    let key = record.key.clone();

    let string = std::str::from_utf8(record.value.as_ref())?;
    let int = string.parse::<i32>()?;
    let value = (int * 2).to_string();

    Ok((key, value.into()))
}
```

We can update the generated SmartModule for our use case:

```
<foobar>
```

And build our new map SmartModule using the `smdk`

```
cd weather_button_map
../../fluvio/target/debug/smdk build
```