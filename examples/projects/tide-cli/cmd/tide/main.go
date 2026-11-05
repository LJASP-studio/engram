// Command tide prints the next high and low tide for a harbour.
package main

import (
	"fmt"
	"os"

	"example.invalid/tide-cli/internal/forecast"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: tide <harbour>")
		os.Exit(2)
	}
	fmt.Println(forecast.Next(os.Args[1]))
}
