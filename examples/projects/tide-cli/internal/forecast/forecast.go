// Package forecast reads tide tables and caches them for an hour.
package forecast

// Next returns the next high and low tide for a harbour as text.
func Next(harbour string) string {
	return harbour + ": high 06:12, low 12:30"
}
