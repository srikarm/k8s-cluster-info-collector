package logger

import (
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/config"
)

// New creates a new logger instance based on configuration
func New(cfg *config.LoggerConfig) *logrus.Logger {
	logger := logrus.New()
	logger.SetLevel(cfg.Level)

	// Set formatter based on configuration
	switch cfg.Format {
	case "json":
		logger.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: "2006-01-02T15:04:05Z07:00",
		})
	case "text":
		logger.SetFormatter(&logrus.TextFormatter{
			FullTimestamp:   true,
			TimestampFormat: "2006-01-02 15:04:05",
		})
	default:
		// Default to JSON format
		logger.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: "2006-01-02T15:04:05Z07:00",
		})
	}

	return logger
}
