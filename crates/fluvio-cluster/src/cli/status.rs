use clap::Parser;
use crate::{cli::ClusterCliError};
use crate::cli::ClusterTarget;
use fluvio::config::ConfigFile;
use fluvio_future::io::StreamExt;
use fluvio_controlplane_metadata::{spu::SpuSpec, topic::TopicSpec, partition::PartitionSpec};

use fluvio::{Fluvio, FluvioConfig, FluvioAdmin};

#[derive(Debug, Parser)]
pub struct StatusOpt {}

impl StatusOpt {
    pub async fn process(self, target: ClusterTarget) -> Result<(), ClusterCliError> {
        let fluvio_config = target.load().unwrap();
        let fluvio = Fluvio::connect_with_config(&fluvio_config).await;

        match fluvio {
            Ok(_fluvio) => {
                println!("SC Running {}", Self::cluster_location_description());
            },
            Err(err) => {
                println!("none");
                return Err(ClusterCliError::from(err));
            }
        }

        let admin = FluvioAdmin::connect_with_config(&fluvio_config).await;
        let (spus_running, cluster_has_data) = match admin {
            Ok(admin) => {
                if Self::spus_running(&admin).await {
                    (true, Self::cluster_has_data(&fluvio_config, &admin).await)
                } else {
                    (false, false)
                }
            }
            Err(_) => (false, false),
        };

        match (spus_running, cluster_has_data) {
            (true, true) => (),
            (true, false) => {
                println!("spus are empty")
            }
            (false, _) => {
                println!("no spus running");
            }
        }

        Ok(())
    }

    async fn spus_running(admin: &FluvioAdmin) -> bool {
        let filters: Vec<String> = vec![];
        let spus = admin.list::<SpuSpec, _>(filters).await;

        match spus {
            Ok(spus) => spus.iter().any(|spu| spu.status.is_online()),
            Err(_) => false,
        }
    }

    /// Check if any topic in the cluster has data in any partitions.
    async fn cluster_has_data(config: &FluvioConfig, admin: &FluvioAdmin) -> bool {
        let topics = Self::topics(admin).await;

        for topic in topics {
            let partitions = Self::num_partitions(admin, &topic).await;

            for partition in 0..partitions {
                if let Some(_record) = Self::last_record(config, &topic, partition as u32).await {
                    return true;
                }
            }
        }

        false
    }

    /// All the topics served by the cluster
    async fn topics(admin: &FluvioAdmin) -> Vec<String> {
        let filters: Vec<String> = vec![];
        let topics = admin.list::<TopicSpec, _>(filters).await;

        match topics {
            Ok(topics) => topics.iter().map(|t| t.name.to_string()).collect(),
            Err(_) => vec![],
        }
    }

    /// Get the number of partiitions for a given topic
    async fn num_partitions(admin: &FluvioAdmin, topic: &str) -> usize {
        let partitions = admin
            .list::<PartitionSpec, _>(vec![topic.to_string()])
            .await;

        partitions.unwrap().len()
    }

    /// Get the last record in a given partition of a given topic
    async fn last_record(
        fluvio_config: &FluvioConfig,
        topic: &str,
        partition: u32,
    ) -> Option<String> {
        let fluvio = Fluvio::connect_with_config(fluvio_config).await.unwrap();
        let consumer = fluvio.partition_consumer(topic, partition).await.unwrap();

        let mut stream = consumer.stream(fluvio::Offset::from_end(1)).await.unwrap();

        if let Some(Ok(record)) = stream.next().await {
            let string = String::from_utf8_lossy(record.value());
            return Some(string.to_string());
        }

        None
    }

    fn cluster_location_description() -> String {
        let config = ConfigFile::load_default_or_new().unwrap();

        match config.config().current_profile_name() {
            Some("local") => "locally".to_string(),
            // Cloud cluster
            Some(other) if other.contains("cloud") => "on cloud based k8s".to_string(),
            _ => "on local k8s".to_string(),
        }
    }
}
