

We can use the [smdk](foobar) to generate a map type SmartModule:

```
mkdir weather_research_group
cd weather_research_group
../fluvio/target/debug/smdk generate \
    --no-params \
    --sm-type map \
    --project-group weather-research-group \
    --sm-public false \
    weather-event-cleaner
```

This gives us a boilerplate _map_ SmartModule:

```
// src/lib.rs
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

Also included are all the configs (`Cargo.toml`, `SmartModule.toml` and `rust-toolchain.toml`) that we'll need to build the SmartModule.

Now let's update the SmartModule for our use case. We'll use [serde](), which is already included in the generated Cargo.toml to model the JSON data being produced by our weather-buttons:

```
// src/input_weather_event.rs

use serde::{Deserialize, Serialize};

#[derive(Default, Serialize, Deserialize, Debug)]
pub(crate) struct InputWeatherEvent {
    pub device_id: usize,
    pub device_version: String,
    pub resident_email: String,
    pub source: String,
    pub timestamp: String,
    pub observation_location: InputObservationLocation,
    pub thermometer_reading: InputThermometerReading,
    pub barometer_reading: InputBarometerReading,
    pub sunlight_sensor_reading: InputSunlightSensorReading,
}

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct InputObservationLocation {
    pub city: String,
    pub state: String,
    pub country: String,
    pub latitude: f64,
    pub longitude: f64,
    pub zip: usize,
    pub altitude: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct InputThermometerReading {
    pub temperature: f64,
    pub humidity: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct InputBarometerReading {
    pub absolute_pressure: f64,
    pub temperature: f64,
    pub humidity: usize,
    pub computed_altitude: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct InputSunlightSensorReading {
    pub illuminance: f64,
}
```

_*Note*: The InfinyOn certified SmartModule [Jolt](https://www.infinyon.com/blog/2022/08/fluvio-jolt-intro/) is available to allow developers to implement JSON to JSON transformations like ours using a simple DSL. 

Next let's use `serde` again to describe our SmartModule's output type. This time we'll define our structure without the unwanted metadata and redundant data, and we'll reduce the nesting:

```
// src/output_weather_event.rs

use serde::{Deserialize, Serialize};

#[derive(Default, Serialize, Deserialize)]
pub(crate) struct OutputWeatherEvent {
    pub device_id: usize,
    pub timestamp: String,
    pub observation_location: OutputObservationLocation,
    pub temperature: f64,
    pub absolute_pressure: f64,
    pub humidity: usize,
    pub illuminance: f64,
}

#[derive(Default, Serialize, Deserialize)]
pub struct OutputObservationLocation {
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: usize,
}
```

Finally, we can implement the `From` trait to convert between our two types. This is all we need to fill in our `map()` method. It will just deserialize the input JSON, call the `from` method, and then serialize the output JSON:

```
// src/lib.rs

use fluvio_smartmodule::{smartmodule, Record, RecordData, Result};

mod output_weather_event;
mod input_weather_event;

use output_weather_event::{OutputWeatherEvent, OutputObservationLocation};
use input_weather_event::InputWeatherEvent;

impl From<InputWeatherEvent> for OutputWeatherEvent {
    fn from(input_event: InputWeatherEvent) -> Self {
        OutputWeatherEvent {
            device_id: input_event.device_id,
            timestamp: input_event.timestamp,
            observation_location: OutputObservationLocation {
                latitude: input_event.observation_location.latitude,
                longitude: input_event.observation_location.longitude,
                altitude: input_event.observation_location.altitude,
            },
            temperature: input_event.thermometer_reading.temperature,
            absolute_pressure: input_event.barometer_reading.absolute_pressure,
            humidity: input_event.barometer_reading.humidity,
            illuminance: input_event.sunlight_sensor_reading.illuminance,
        }
    }
}

#[smartmodule(map)]
pub fn map(record: &Record) -> Result<(Option<RecordData>, RecordData)> {
    let key = record.key.clone();

    let input_event: InputWeatherEvent =
        serde_json::from_slice(record.value.as_ref())?;

    let output_event = OutputWeatherEvent::from(input_event);
    let value = serde_json::to_vec_pretty(&output_event)?;

    Ok((key, value.into()))
}
```

Our map SmartModule is ready to build using the `smdk`:

```
$ cd weather_resarch_group/weather-event-cleaner
$ smdk build
```

And add to the cluster:

```
$ cd weather_research_group/weather-event-cleaner
$ smdk load
```

_*Note*: You can also use the `fluvio smartmodule create` command to add smartmodules to your cluster_

Now, to test will happen when our receives records from the weather-buttons, we save a sample `weather_event.json`:

```
{
    "device_id": 3407,
    "device_version": "1.8.0",
    "resident_email": "johndoe@test.com",
    "source": "weatherbutton data collector",
    "timestamp": "2023-04-12T15:07:55.312Z",
    "observation_location": {
        "city": "Houston",
        "state": "TX",
        "country": "US",
        "latitude": 29.7432,
        "longitude": -95.4011,
        "zip": 77002,
        "altitude": 80
    },
    "thermometer_reading": {
        "temperature": 23.88,
        "humidity": 54
    },
    "barometer_reading": {
        "absolute_pressure": 0.0,
        "temperature": 0.0,
        "humidity": 0,
        "computed_altitude": 0
    },
    "sunlight_sensor_reading": {
        "illuminance": 9582.5
    }
}
```

And produce it:

```
// delete the new lines so the entire JSON is interpreted as one record
tr -d '\n' < weather_event1.json | fluvio produce weather-events --smartmodule weather-event-cleaner
```

And view the resulting records:

```
$ fluvio consume weather-events -B -d
Consuming records from 'recipes' starting from the beginning of log
{
  "device_id": 2067,
  "timestamp": "2023-04-12T15:07:54.308Z",
  "observation_location": {
    "latitude": 29.7432,
    "longitude": -95.4011,
    "altitude": 80
  },
  "temperature": 23.88,
  "absolute_pressure": 30.01,
  "humidity": 52,
  "illuminance": 9572.3
}
```

That's a lot of storage space saved per record! And we still have all the data we need to feed our model.

## Expanding Our SmartModule's Functionality

Mapping our input data down is a useful function, but there is a lot more we can ask the SPU to help us with before commiting our records.

Suppose now that the barometers we shipped with our weather-buttons were a bit unreliable. About 1 out of every 50 events our weather buttons send contains only the default values for the barometer data:

```
    // --snipped
    "barometer_reading": {
        "absolute_pressure": 0.0,
        "temperature": 0.0,
        "humidity": 0,
        "computed_altitude": 0
    },
    // --snipped
```

We'll have to remove events such as these or they will skew our results. Luckily, if we remove these invalid events from our data pool, we will still have the density of data needed to feed to our model. We could ask the `SPU` to perform this filtering on write (for the producer) or on read (for the consumer). To save a few more bucks on disk space we'll modify our weather-event-cleaner SmartModule to filter out these records in addition to performing the JSON mapping.

To facilitate the filtering, we'll first have to trade in the `#[smartmodule(map)]` attribute for `#[smartmodule(filter_map)]`. Then we'll have to modify the return type from  `Result<(Option<RecordData>, RecordData)> ` to `Result<Option<(Option<RecordData>, RecordData)>>` so that we can return `Ok(None)` when we want to drop the record:

```
#[smartmodule(filter_map)]
pub fn filter_map(record: &Record) -> Result<Option<(Option<RecordData>, RecordData)>> {
    let key = record.key.clone();

    let input_event: InputWeatherEvent =
        serde_json::from_slice(record.value.as_ref())?;

    // filter out the invalid data
    if input_event.barometer_reading.absolute_pressure == 0.0 {
        return Ok(None);
    }

    let output_event = OutputWeatherEvent::from(input_event);
    let value = serde_json::to_vec_pretty(&output_event)?;

    Ok(Some((key, value.into()))) // remember to adjust the return value for new signature
}
```

Again we can build our SmartModule:

```
$ cd weather-event-cleaner
$ smdk build
```

And replace our old SmartModule:

```
$ smdk load --package-name weather-event-cleaner
```

Then to test that the new SmartModule still performs the mapping but also omits our invalid events, we'll add another test file:

```
{
    "device_id": 3407,
    "device_version": "1.8.0",
    "resident_email": "johndoe@test.com",
    "source": "weatherbutton data collector",
    "timestamp": "2023-04-12T15:07:55.312Z",
    "observation_location": {
        "city": "Houston",
        "state": "TX",
        "country": "US",
        "latitude": 29.7432,
        "longitude": -95.4011,
        "zip": 77002,
        "altitude": 80
    },
    "thermometer_reading": {
        "temperature": 23.88,
        "humidity": 54
    },
    "barometer_reading": {
        "absolute_pressure": 0.0,
        "temperature": 0.0,
        "humidity": 0,
        "computed_altitude": 0
    },
    "sunlight_sensor_reading": {
        "illuminance": 9582.5
    }
}
```

```
// again remove the new lines but leave one to delimit
(tr -d '\n' < input.json; echo ''; tr -d '\n' < input2.json) | fluvio produce weather-events --smartmodule weather-event-cleaner
```