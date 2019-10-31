extends Object
class_name PlayerStats

var seeker_captures : int = 0
var hider_captures : int = 0
var hider_escapes : int = 0

func toDTO() -> Dictionary:
	var result = {
		seeker_captures = self.seeker_captures,
		hider_captures = self.hider_captures,
		hider_escapes = self.hider_escapes
	}
	return result

func fromDTO(dto: Dictionary):
	self.seeker_captures = int(dto.seeker_captures);
	self.hider_captures = int(dto.hider_captures);
	self.hider_escapes = int(dto.hider_escapes);

func addStats(newStats: PlayerStats):
	self.seeker_captures += newStats.seeker_captures;
	self.hider_captures += newStats.hider_captures;
	self.hider_escapes += newStats.hider_escapes;
