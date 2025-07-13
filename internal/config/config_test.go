package config

import (
	"os"
	"testing"

	"github.com/sirupsen/logrus"
)

func TestLoad(t *testing.T) {
	tests := []struct {
		name        string
		envVars     map[string]string
		expectError bool
	}{
		{
			name: "default values",
			envVars: map[string]string{
				"DB_HOST": "",
				"DB_PORT": "",
				"DB_USER": "",
			},
			expectError: false,
		},
		{
			name: "custom values",
			envVars: map[string]string{
				"DB_HOST":     "custom-host",
				"DB_PORT":     "5433",
				"DB_USER":     "custom-user",
				"DB_PASSWORD": "custom-pass",
				"DB_NAME":     "custom-db",
				"LOG_LEVEL":   "debug",
			},
			expectError: false,
		},
		{
			name: "invalid log level",
			envVars: map[string]string{
				"LOG_LEVEL": "invalid",
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set environment variables
			for key, value := range tt.envVars {
				if value == "" {
					os.Unsetenv(key)
				} else {
					os.Setenv(key, value)
				}
			}

			// Load configuration
			cfg, err := Load()

			if tt.expectError && err == nil {
				t.Error("expected error but got none")
			}
			if !tt.expectError && err != nil {
				t.Errorf("unexpected error: %v", err)
			}

			if !tt.expectError && cfg != nil {
				// Verify default values
				if cfg.Database.Host == "" {
					t.Error("DB_HOST should have default value")
				}
				if cfg.Database.Port == "" {
					t.Error("DB_PORT should have default value")
				}
			}

			// Clean up
			for key := range tt.envVars {
				os.Unsetenv(key)
			}
		})
	}
}

func TestGetEnvOrDefault(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue string
		envValue     string
		expected     string
	}{
		{
			name:         "env var exists",
			key:          "TEST_VAR",
			defaultValue: "default",
			envValue:     "custom",
			expected:     "custom",
		},
		{
			name:         "env var doesn't exist",
			key:          "TEST_VAR_MISSING",
			defaultValue: "default",
			envValue:     "",
			expected:     "default",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
			}

			result := getEnvOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, result)
			}

			os.Unsetenv(tt.key)
		})
	}
}

func TestLogLevelParsing(t *testing.T) {
	tests := []struct {
		name     string
		level    string
		expected logrus.Level
	}{
		{"debug", "debug", logrus.DebugLevel},
		{"info", "info", logrus.InfoLevel},
		{"warn", "warn", logrus.WarnLevel},
		{"error", "error", logrus.ErrorLevel},
		{"invalid", "invalid", logrus.InfoLevel}, // Should default to info
		{"empty", "", logrus.InfoLevel},          // Should default to info
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.level != "" {
				os.Setenv("LOG_LEVEL", tt.level)
			}

			cfg, err := Load()
			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}

			if cfg.Logger.Level != tt.expected {
				t.Errorf("expected %v, got %v", tt.expected, cfg.Logger.Level)
			}

			os.Unsetenv("LOG_LEVEL")
		})
	}
}
