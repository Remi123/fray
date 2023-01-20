@tool
class_name FrayConditionalInput
extends FrayCompositeInput

## A composite input used to create conditional inputs
##
## @desc:
##      Returns whether a specific component is pressed based on a string condition.
##      Useful for creating directional inputs which change based on what side a
##      combatant stands on as is seen in many 2D fighting games.
##
##      If no condition is true then the input will default to checking the first component.


## Type: Dictionary<int, String>
## Hint: <component index, string condition>
var _conditions_by_component: Dictionary

## Returns a builder instance
static func builder() -> Builder:
	return Builder.new()
	

func set_condition(component_index: int, condition: String) -> void:
	if component_index == 0:
		push_warning("The first component is treated as the default input. Condition will be ignored")
		return

	if component_index >= 1 and component_index < _components.size():
		_conditions_by_component[component_index] = condition
	else:
		push_warning("Failed to set condition on input. Given index out of range")
		

func _is_pressed_impl(device: int, input_interface: FrayInputInterface) -> bool:
	if _components.is_empty():
		push_warning("Conditional input has no components")
		return false

	var comp: Resource = _components[0]

	for component_index in _conditions_by_component:
		var component: Resource = _components[component_index]
		var condition: String = _conditions_by_component[component_index]

		if input_interface.is_condition_true(condition, device):
			comp = component
			break

	return comp.is_pressed(device, input_interface)


func _decompose_impl(device: int, input_interface: FrayInputInterface) -> PackedStringArray:
	# Returns the first component with a true condition. Defaults to component at index 0

	if _components.is_empty():
		return PackedStringArray()

	var component: Resource = _components[0]
	for component_index in _conditions_by_component:
		var comp: Resource = _components[component_index]
		var condition: String = _conditions_by_component[component_index]

		if input_interface.is_condition_true(condition, device):
			component = comp
			break
	return component.decompose(device, input_interface)


class Builder:
	extends CompositeBuilder

	var _conditions: PackedStringArray

	func _init() -> void:
		_composite_input = FrayConditionalInput.new()

	## Adds a composite input as a component of this conditional input
	##
	## Returns a reference to this ComponentBuilder
	func add_component(condition: String, component_builder: RefCounted) -> Builder:
		_conditions.append(condition)
		_builders.append(component_builder)
		return self 
	
	## Sets whether the input will be virtual or not
	##
	## Returns a reference to this ComponentBuilder
	func is_virtual(value: bool = true) -> Builder:
		_composite_input.is_virtual = value
		return self

	## Sets the composite input's process priority
	##
	## Returns a reference to this ComponentBuilder
	func priority(value: int) -> Builder:
		_composite_input.priority = value
		return self

	## Returns composite input instance
	func build() -> FrayCompositeInput:
		for i in len(_builders):
			_composite_input.add_component(_builders[i].build())
			
			if i != 0:
				_composite_input.set_condition(i, _conditions[i])
		return _composite_input
