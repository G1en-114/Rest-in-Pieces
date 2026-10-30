extends RefCounted
## Shared, deterministic Mixamo/common humanoid bone adapter. It never changes physics.

const REQUIRED := ["Hips", "Spine", "Head", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]
const ALIASES := {
	"Hips": ["hips", "pelvis"], "Spine": ["spine", "spine01"], "Head": ["head"],
	"LeftArm": ["leftarm", "leftupperarm", "upperarml"], "RightArm": ["rightarm", "rightupperarm", "upperarmr"],
	"LeftForeArm": ["leftforearm", "leftlowerarm", "lowerarml"], "RightForeArm": ["rightforearm", "rightlowerarm", "lowerarmr"],
	"LeftHand": ["lefthand", "handl"], "RightHand": ["righthand", "handr"],
	"LeftUpLeg": ["leftupleg", "leftupperleg", "thighl"], "RightUpLeg": ["rightupleg", "rightupperleg", "thighr"],
	"LeftLeg": ["leftleg", "leftlowerleg", "calfl"], "RightLeg": ["rightleg", "rightlowerleg", "calfr"],
	"LeftFoot": ["leftfoot", "footl"], "RightFoot": ["rightfoot", "footr"]
}


static func skeleton_in(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.find_children("*", "Skeleton3D", true, false):
		if compatible(child):
			return child
	return null


static func bone_index(skeleton: Skeleton3D, name: String) -> int:
	if skeleton == null:
		return -1
	var aliases: Array = ALIASES.get(name, [name.to_lower()])
	for i in skeleton.get_bone_count():
		var normalized := String(skeleton.get_bone_name(i)).to_lower()
		for delimiter in [":", "_", "-", " ", ".", "|"]:
			normalized = normalized.replace(delimiter, "")
		for suffix in aliases:
			if normalized.ends_with(suffix):
				return i
	return -1


static func compatible(skeleton: Skeleton3D) -> bool:
	for name in REQUIRED:
		if bone_index(skeleton, name) < 0:
			return false
	for side in ["Left", "Right"]:
		if not _descends_from(skeleton, bone_index(skeleton, side + "Hand"), bone_index(skeleton, side + "Arm")):
			return false
		if not _descends_from(skeleton, bone_index(skeleton, side + "Foot"), bone_index(skeleton, side + "UpLeg")):
			return false
	return _descends_from(skeleton, bone_index(skeleton, "Head"), bone_index(skeleton, "Hips"))


static func _descends_from(skeleton: Skeleton3D, bone: int, ancestor: int) -> bool:
	while bone >= 0:
		if bone == ancestor:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false
