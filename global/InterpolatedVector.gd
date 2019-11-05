extends Object

class_name InterpolatedObject

var __currentValue: Vector2
var __targetValue: Vector2

export var speed := 5

func _init(currentValue: Vector2, targetValue: Vector2):
	self.__currentValue = currentValue
	self.__targetValue = targetValue

func update(delta: float):
	return self.__currentValue.linear_interpolate(self.__targetValue, delta * speed)

func setTarget(target: Vector2):
	self.__targetValue = target

func getTarget():
	return self.__targetValue

func setCurrentValue(val: Vector2):
	self.__currentValue = val

func getCurrentValue():
	return self.__currentValue
