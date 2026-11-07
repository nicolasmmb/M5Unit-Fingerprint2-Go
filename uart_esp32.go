//go:build esp32

package finger2

import "machine"

// New returns a Device bound to uart. Configure the UART for 115200 8N1 before
// calling Init.
//
// This helper exists only on ESP32 because it takes the concrete machine type.
// Use NewTransport on any other chip.
func New(uart *machine.UART) *Device {
	return newDevice(uart)
}
