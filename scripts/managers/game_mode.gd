extends Node

## Global singleton that stores the selected game mode.
## Set from the main menu before loading the game scene.

enum Mode { CLASSIC, CHALLENGE }

var current_mode: Mode = Mode.CLASSIC

func is_challenge() -> bool:
	return current_mode == Mode.CHALLENGE

func is_classic() -> bool:
	return current_mode == Mode.CLASSIC
