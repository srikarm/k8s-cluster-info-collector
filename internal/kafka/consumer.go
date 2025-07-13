package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/IBM/sarama"
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/models"
	"k8s-cluster-info-collector/internal/store"
)

// Consumer handles consuming messages from Kafka
type Consumer struct {
	consumer sarama.ConsumerGroup
	store    *store.Store
	topic    string
	groupID  string
	logger   *logrus.Logger
	wg       sync.WaitGroup
	cancel   context.CancelFunc
}

// NewConsumer creates a new Kafka consumer
func NewConsumer(cfg *config.KafkaConfig, store *store.Store, logger *logrus.Logger) (*Consumer, error) {
	if !cfg.Enabled {
		return nil, fmt.Errorf("kafka is not enabled")
	}

	// Configure Sarama
	config := sarama.NewConfig()
	config.Consumer.Group.Rebalance.Strategy = sarama.BalanceStrategyRoundRobin
	config.Consumer.Offsets.Initial = sarama.OffsetOldest
	config.Consumer.Group.Session.Timeout = 30 * time.Second   // 30 seconds
	config.Consumer.Group.Heartbeat.Interval = 3 * time.Second // 3 seconds

	// Create consumer group
	groupID := "cluster-info-consumer"
	consumer, err := sarama.NewConsumerGroup(cfg.Brokers, groupID, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Kafka consumer group: %w", err)
	}

	logger.WithFields(logrus.Fields{
		"brokers": cfg.Brokers,
		"topic":   cfg.Topic,
		"groupID": groupID,
	}).Info("Kafka consumer initialized")

	return &Consumer{
		consumer: consumer,
		store:    store,
		topic:    cfg.Topic,
		groupID:  groupID,
		logger:   logger,
	}, nil
}

// Start starts consuming messages from Kafka
func (c *Consumer) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	c.cancel = cancel

	c.wg.Add(1)
	go func() {
		defer c.wg.Done()
		for {
			// Check if context is done
			if ctx.Err() != nil {
				return
			}

			// Consume messages
			if err := c.consumer.Consume(ctx, []string{c.topic}, c); err != nil {
				c.logger.WithError(err).Error("Error consuming from Kafka")
				continue
			}
		}
	}()

	c.logger.Info("Kafka consumer started")
	return nil
}

// Stop stops the Kafka consumer
func (c *Consumer) Stop() error {
	c.logger.Info("Stopping Kafka consumer")

	if c.cancel != nil {
		c.cancel()
	}

	c.wg.Wait()

	if c.consumer != nil {
		return c.consumer.Close()
	}

	return nil
}

// Setup is run at the beginning of a new session, before ConsumeClaim
func (c *Consumer) Setup(sarama.ConsumerGroupSession) error {
	c.logger.Info("Kafka consumer session setup")
	return nil
}

// Cleanup is run at the end of a session, once all ConsumeClaim goroutines have exited
func (c *Consumer) Cleanup(sarama.ConsumerGroupSession) error {
	c.logger.Info("Kafka consumer session cleanup")
	return nil
}

// ConsumeClaim must start a consumer loop of ConsumerGroupClaim's Messages().
func (c *Consumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	// Process messages
	for {
		select {
		case message := <-claim.Messages():
			if message == nil {
				return nil
			}

			if err := c.processMessage(message); err != nil {
				c.logger.WithError(err).WithFields(logrus.Fields{
					"topic":     message.Topic,
					"partition": message.Partition,
					"offset":    message.Offset,
				}).Error("Failed to process message")
				// Continue processing other messages instead of failing
				continue
			}

			// Mark message as processed
			session.MarkMessage(message, "")

		case <-session.Context().Done():
			return nil
		}
	}
}

// processMessage processes a single Kafka message
func (c *Consumer) processMessage(message *sarama.ConsumerMessage) error {
	c.logger.WithFields(logrus.Fields{
		"topic":     message.Topic,
		"partition": message.Partition,
		"offset":    message.Offset,
		"timestamp": message.Timestamp,
		"size":      len(message.Value),
	}).Info("Processing message from Kafka")

	// Deserialize cluster info from JSON
	var clusterInfo models.ClusterInfo
	if err := json.Unmarshal(message.Value, &clusterInfo); err != nil {
		return fmt.Errorf("failed to unmarshal cluster info: %w", err)
	}

	// Store cluster info in database
	if err := c.store.StoreClusterInfo(clusterInfo); err != nil {
		return fmt.Errorf("failed to store cluster info: %w", err)
	}

	c.logger.WithField("timestamp", clusterInfo.Timestamp).Info("Successfully stored cluster info from Kafka")
	return nil
}
