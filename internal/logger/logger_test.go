package logger

import (
	"testing"

	"k8s-cluster-info-collector/internal/config"

	"github.com/sirupsen/logrus"
)

func TestNew(t *testing.T) {
	tests := []struct {
		name     string
		config   config.LoggerConfig
		expected logrus.Level
	}{
		{
			name: "debug level JSON format",
			config: config.LoggerConfig{
				Level:  logrus.DebugLevel,
				Format: "json",
			},
			expected: logrus.DebugLevel,
		},
		{
			name: "info level text format",
			config: config.LoggerConfig{
				Level:  logrus.InfoLevel,
				Format: "text",
			},
			expected: logrus.InfoLevel,
		},
		{
			name: "warn level",
			config: config.LoggerConfig{
				Level:  logrus.WarnLevel,
				Format: "json",
			},
			expected: logrus.WarnLevel,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := New(&tt.config)

			if logger == nil {
				t.Fatal("logger should not be nil")
			}

			if logger.Level != tt.expected {
				t.Errorf("expected level %v, got %v", tt.expected, logger.Level)
			}

			// Test that we can log without panic
			logger.Info("test message")
			logger.Debug("debug message")
			logger.Warn("warn message")
			logger.Error("error message")
		})
	}
}

func TestLoggerConfig(t *testing.T) {
	config := &config.LoggerConfig{
		Level:  logrus.InfoLevel,
		Format: "json",
	}

	logger := New(config)

	// Verify logger is configured correctly
	if logger.Level != logrus.InfoLevel {
		t.Errorf("expected info level, got %v", logger.Level)
	}

	// Test formatter type based on format
	switch config.Format {
	case "json":
		if _, ok := logger.Formatter.(*logrus.JSONFormatter); !ok {
			t.Error("expected JSON formatter")
		}
	case "text":
		if _, ok := logger.Formatter.(*logrus.TextFormatter); !ok {
			t.Error("expected text formatter")
		}
	}
}
