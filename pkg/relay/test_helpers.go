package relay

// mockRelayLogger implements relayLogger interface for testing
type mockRelayLogger struct {
	logs []string
}

func (ml *mockRelayLogger) Info(msg string, fields ...interface{}) {
	ml.logs = append(ml.logs, "INFO: "+msg)
}

func (ml *mockRelayLogger) Error(msg string, fields ...interface{}) {
	ml.logs = append(ml.logs, "ERROR: "+msg)
}

func (ml *mockRelayLogger) Debug(msg string, fields ...interface{}) {
	ml.logs = append(ml.logs, "DEBUG: "+msg)
}

func (ml *mockRelayLogger) Warn(msg string, fields ...interface{}) {
	ml.logs = append(ml.logs, "WARN: "+msg)
}

// newMockRelayLogger creates a new mock relay logger
func newMockRelayLogger() *mockRelayLogger {
	return &mockRelayLogger{
		logs: make([]string, 0),
	}
}

// newTestRelayLogger creates a real relay logger for testing
func newTestRelayLogger() *relayLogger {
	return NewRelayLogger("TEST")
}
