package kafka

import (
	"encoding/json"
	"fmt"

	"github.com/IBM/sarama"
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/models"
)

// Producer handles sending messages to Kafka
type Producer struct {
	producer  sarama.SyncProducer
	topic     string
	partition int32
	logger    *logrus.Logger
}

// NewProducer creates a new Kafka producer
func NewProducer(cfg *config.KafkaConfig, logger *logrus.Logger) (*Producer, error) {
	if !cfg.Enabled {
		return nil, fmt.Errorf("kafka is not enabled")
	}

	// Configure Sarama
	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll // Wait for all replicas to commit
	config.Producer.Retry.Max = 5                    // Retry up to 5 times to produce the message
	config.Producer.Return.Successes = true
	config.Producer.Compression = sarama.CompressionSnappy

	// Create producer
	producer, err := sarama.NewSyncProducer(cfg.Brokers, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Kafka producer: %w", err)
	}

	logger.WithFields(logrus.Fields{
		"brokers":   cfg.Brokers,
		"topic":     cfg.Topic,
		"partition": cfg.Partition,
	}).Info("Kafka producer initialized")

	return &Producer{
		producer:  producer,
		topic:     cfg.Topic,
		partition: cfg.Partition,
		logger:    logger,
	}, nil
}

// SendClusterInfo sends cluster information to Kafka
func (p *Producer) SendClusterInfo(clusterInfo *models.ClusterInfo) error {
	// Serialize cluster info to JSON
	data, err := json.Marshal(clusterInfo)
	if err != nil {
		return fmt.Errorf("failed to marshal cluster info: %w", err)
	}

	// Create Kafka message
	message := &sarama.ProducerMessage{
		Topic:     p.topic,
		Partition: p.partition,
		Value:     sarama.ByteEncoder(data),
		Timestamp: clusterInfo.Timestamp,
	}

	// Send message
	partition, offset, err := p.producer.SendMessage(message)
	if err != nil {
		p.logger.WithError(err).Error("Failed to send message to Kafka")
		return fmt.Errorf("failed to send message to Kafka: %w", err)
	}

	p.logger.WithFields(logrus.Fields{
		"topic":     p.topic,
		"partition": partition,
		"offset":    offset,
		"timestamp": clusterInfo.Timestamp,
		"size":      len(data),
	}).Info("Cluster info sent to Kafka")

	return nil
}

// Close closes the Kafka producer
func (p *Producer) Close() error {
	if p.producer != nil {
		p.logger.Info("Closing Kafka producer")
		return p.producer.Close()
	}
	return nil
}
