@icon("res://addons/fray/assets/icons/buffered_input_advancer.svg")
class_name FrayBufferedInputAdvancer
extends Node
## A node designed to advance a specified state machine using buffered inputs.
##
## This node automatically feeds buffered inputs to the designated state machine to trigger state transitions.
## When an input is accepted by the state machine, the advancer stops processing new inputs for the current frame.
## The advancer can be paused to control the timing of input feeding, but note that pausing doesn't affect the input buffer.
## Inputs can still be buffered during pauses, and they will expire if they exceed the maximum buffer time.
## This behavior allows you to define the timeframe during which user inputs can trigger state transitions.

enum AdvanceMode {
	IDLE,  ## Advance during the idle process
	PHYSICS,  ## Advance during the physics process
}

## The state machine to be controlled by the advancer
@export var state_machine: FrayStateMachine

## If [code]false[/code], the buffer does not attempt to advance by feeding inputs to the state machine.
## Enabling or disabling this property allows control over when buffered inputs are consumed.
## This can be useful for managing when a player can 'cancel' an attack using their buffered inputs.
@export var paused: bool = true

## The max time an input can exist in the buffer before it is ignored, in seconds.
@export_range(0.0, 5.0, 0.01, "suffix:sec") var max_buffer_time: float = 1.0

## Determines the process during which the advancer machine can advance the state machine.
@export var advance_mode: AdvanceMode

var _input_buffer: Array[BufferedInput]
var _accepted_input_time_stamp: int

func _process(delta: float) -> void:
	if advance_mode == AdvanceMode.IDLE:
		_advance()


func _physics_process(delta: float) -> void:
	if advance_mode == AdvanceMode.PHYSICS:
		_advance()


## Buffers an input button to be processed by the state machine
##
## [kbd]input[/kbd] is the name of the input.
## This is just an identifier used in input transitions.
## It is not default associated with any actions in godot or inputs in fray.
##
## If [kbd]is_presse[/kbd] is true then a pressed input is buffered, else a released input is buffered.
func buffer_button(input: StringName, is_pressed: bool = true) -> void:
	_input_buffer.append(BufferedInputButton.new(Time.get_ticks_msec(), input, is_pressed))


## Buffers an input sequence to be processed by the state machine
#
## [kbd]sequence_name[/kbd] is the name of the sequence.
## This is just an identifier used in input transitions.
## It is not default associated with any actions in godot or inputs in fray.
func buffer_sequence(sequence_name: StringName) -> void:
	_input_buffer.append(BufferedInputSequence.new(Time.get_ticks_msec(), sequence_name))


## Clears the input buffer
func clear_buffer() -> void:
	_input_buffer.clear()


## Returns a shallow copy of the current buffer.
func get_buffer() -> Array[BufferedInput]:
	return _input_buffer.duplicate()


func _advance() -> void:
	while not _input_buffer.is_empty() and not paused:
		var buffered_input: BufferedInput = _input_buffer.pop_front()
		var is_input_within_buffer := buffered_input.calc_elapsed_time_msec() <= Fray.sec_to_msec(max_buffer_time)
		var accepted_input_age_sec := Fray.msec_to_sec(Time.get_ticks_msec() - _accepted_input_time_stamp)
		var state_machine_input := _create_state_machine_input(buffered_input, accepted_input_age_sec)

		if is_input_within_buffer and state_machine.advance(state_machine_input):
			_accepted_input_time_stamp = Time.get_ticks_msec()
			break


func _create_state_machine_input(
	buffered_input: BufferedInput, time_since_last_input: float
) -> Dictionary:
	if buffered_input is BufferedInputButton:
		return {
			input = buffered_input.input,
			is_pressed = buffered_input.is_pressed,
			time_since_last_input = time_since_last_input,
			time_held = buffered_input.calc_elapsed_time_msec()
		}
	elif buffered_input is BufferedInputSequence:
		return {
			sequence = buffered_input.sequence_name,
			time_since_last_input = time_since_last_input,
		}
	return {}


class BufferedInput:
	extends RefCounted

	var time_stamp: int

	func _init(input_time_stamp: int = 0) -> void:
		time_stamp = input_time_stamp


	func calc_elapsed_time_msec() -> int:
		return Time.get_ticks_msec() - time_stamp


class BufferedInputButton:
	extends BufferedInput

	var input: StringName
	var is_pressed: bool

	func _init(
		input_time_stamp: int = 0, input_name: StringName = "", input_is_pressed: bool = true
	) -> void:
		super(input_time_stamp)
		input = input_name
		is_pressed = input_is_pressed


class BufferedInputSequence:
	extends BufferedInput

	var sequence_name: StringName

	func _init(input_time_stamp: int = 0, input_sequence_name: StringName = "") -> void:
		super(input_time_stamp)
		sequence_name = input_sequence_name
