use fluvio_smartmodule::{smartmodule, Record, RecordData, Result};
use serde::{Deserialize, Serialize};

#[derive(Default, Serialize, Deserialize, Debug)]
struct InputWeatherEvent {
    device_id: usize,
    device_version: String,
    resident_email: String,
    source: String,
    timestamp: String,
    observation_location: InputObservationLocation,
    thermometer_reading: InputThermometerReading,
    barometer_reading: InputBarometerReading,
    sunlight_sensor_reading: InputSunlightSensorReading,
}

#[derive(Default, Serialize, Deserialize, Debug)]
struct InputObservationLocation {
    city: String,
    state: String,
    country: String,
    latitude: f64,
    longitude: f64,
    zip: usize,
    altitude: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
struct InputThermometerReading {
    temperature: f64,
    humidity: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
struct InputBarometerReading {
    absolute_pressure: f64,
    temperature: f64,
    humidity: usize,
    computed_altitude: usize,
}

#[derive(Default, Serialize, Deserialize, Debug)]
struct InputSunlightSensorReading {
    illuminance: f64,
}

#[derive(Default, Serialize, Deserialize)]
struct OutputWeatherEvent {
    device_id: usize,
    timestamp: String,
    observation_location: OutputObservationLocation,
    temperature: f64,
    absolute_pressure: f64,
    humidity: usize,
    illuminance: f64,
}

#[derive(Default, Serialize, Deserialize)]
struct OutputObservationLocation {
    latitude: f64,
    longitude: f64,
    altitude: usize,
}

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
    println!("input_event: {:?}", input_event);

    let output_event = OutputWeatherEvent::from(input_event);
    let value = serde_json::to_vec_pretty(&output_event)?;

    Ok((key, value.into()))
}
