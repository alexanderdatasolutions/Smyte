# TaskAssignmentManager.gd - Manages god task assignments and progress
# Handles assigning gods to tasks, tracking progress, collecting rewards
extends Node
class_name TaskAssignmentManager

# ==============================================================================
# SIGNALS
# ==============================================================================
signal task_assigned(god_id: String, task_id: String, territory_id: String)
signal task_unassigned(god_id: String, task_id: String)
signal task_completed(god_id: String, task_id: String, rewards: Dictionary)
signal task_progress_updated(god_id: String, task_id: String, progress: float)
signal tasks_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const TASKS_DATA_PATH = "res://data/tasks.json"
const PROGRESS_UPDATE_INTERVAL = 1.0  # Check progress every second

# ==============================================================================
# STATE
# ==============================================================================
var _tasks: Dictionary = {}  # task_id -> Task
var _task_categories: Dictionary = {}  # category_id -> category_data
var _skills: Dictionary = {}  # skill_id -> skill_data
var _active_assignments: Dictionary = {}  # god_id -> [{task_id, territory_id, start_time}]
var _is_loaded: bool = false

var _trait_manager: TraitManager = null
var _progress_timer: float = 0.0

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	load_tasks_from_json()

func set_trait_manager(manager: TraitManager) -> void:
	_trait_manager = manager

func load_tasks_from_json() -> void:
	"""Load all task definitions from JSON"""
	if not FileAccess.file_exists(TASKS_DATA_PATH):
		push_error("TaskAssignmentManager: Tasks data file not found: " + TASKS_DATA_PATH)
		return

	var file = FileAccess.open(TASKS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("TaskAssignmentManager: Failed to open tasks data file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("TaskAssignmentManager: Failed to parse tasks JSON: " + json.get_error_message())
		return

	var data = json.get_data()

	# Load task definitions
	if data.has("tasks"):
		for task_id in data.tasks:
			var task_data = data.tasks[task_id]
			task_data["id"] = task_id
			var loaded_task = Task.from_dict(task_data)
			if loaded_task:
				_tasks[task_id] = loaded_task

	# Load categories
	if data.has("task_categories"):
		_task_categories = data.task_categories.duplicate(true)

	# Load skills
	if data.has("skills"):
		_skills = data.skills.duplicate(true)

	_is_loaded = true
	tasks_loaded.emit()
	print("TaskAssignmentManager: Loaded %d tasks, %d categories, %d skills" % [_tasks.size(), _task_categories.size(), _skills.size()])

# ==============================================================================
# TASK QUERIES
# ==============================================================================

func get_task(task_id: String) -> Task:
	"""Get a task by ID"""
	return _tasks.get(task_id, null)

func get_all_tasks() -> Array[Task]:
	"""Get all loaded tasks"""
	var result: Array[Task] = []
	for task in _tasks.values():
		result.append(task)
	return result

func get_tasks_by_category(category: Task.TaskCategory) -> Array[Task]:
	"""Get all tasks in a category"""
	var result: Array[Task] = []
	for task in _tasks.values():
		if task.category == category:
			result.append(task)
	return result

func get_available_tasks_for_territory(territory_level: int, building_ids: Array[String]) -> Array[Task]:
	"""Get tasks available in a territory based on level and buildings"""
	var result: Array[Task] = []
	for task in _tasks.values():
		if task.required_territory_level <= territory_level:
			if task.required_building_id == "" or task.required_building_id in building_ids:
				result.append(task)
	return result

func get_available_tasks_for_god(god: God, territory_level: int, building_ids: Array[String]) -> Array[Task]:
	"""Get tasks a specific god can perform in a territory"""
	var result: Array[Task] = []
	var available = get_available_tasks_for_territory(territory_level, building_ids)

	for task in available:
		if task.can_god_perform(god):
			result.append(task)

	return result

# ==============================================================================
# TASK ASSIGNMENT
# ==============================================================================

func assign_god_to_task(god: God, task_id: String, territory_id: String) -> bool:
	"""Assign a god to work on a task"""
	if not god:
		push_warning("TaskAssignmentManager: Cannot assign null god")
		return false

	var target_task = get_task(task_id)
	if not target_task:
		push_warning("TaskAssignmentManager: Unknown task ID: " + task_id)
		return false

	# Check if god can perform this task
	if not target_task.can_god_perform(god):
		push_warning("TaskAssignmentManager: God cannot perform task: " + task_id)
		return false

	# Check multitask capacity
	var multitask_info = {"count": 1, "efficiency": 1.0}
	if _trait_manager:
		multitask_info = _trait_manager.get_multitask_info(god)

	if god.get_current_task_count() >= multitask_info.count:
		push_warning("TaskAssignmentManager: God at max task capacity")
		return false

	# Check if already assigned to this task
	if god.is_assigned_to_task(task_id):
		return false

	# Assign the task
	var current_time = Time.get_unix_time_from_system()
	god.current_tasks.append(task_id)
	god.task_start_times.append(int(current_time))
	god.task_progress[task_id] = 0.0

	# Track in active assignments
	if not _active_assignments.has(god.id):
		_active_assignments[god.id] = []
	_active_assignments[god.id].append({
		"task_id": task_id,
		"territory_id": territory_id,
		"start_time": current_time
	})

	task_assigned.emit(god.id, task_id, territory_id)
	return true

func unassign_god_from_task(god: God, task_id: String) -> bool:
	"""Remove a god from a task (loses progress per design decision)"""
	if not god:
		return false

	var idx = god.current_tasks.find(task_id)
	if idx == -1:
		return false

	# Remove from god's task list
	god.current_tasks.remove_at(idx)
	if idx < god.task_start_times.size():
		god.task_start_times.remove_at(idx)
	god.task_progress.erase(task_id)

	# Remove from active assignments
	if _active_assignments.has(god.id):
		var assignments = _active_assignments[god.id]
		for i in range(assignments.size() - 1, -1, -1):
			if assignments[i].task_id == task_id:
				assignments.remove_at(i)
				break

	task_unassigned.emit(god.id, task_id)
	return true

func unassign_god_from_all_tasks(god: God) -> void:
	"""Remove a god from all tasks"""
	if not god:
		return

	var tasks_to_remove = god.current_tasks.duplicate()
	for task_id in tasks_to_remove:
		unassign_god_from_task(god, task_id)

# ==============================================================================
# PROGRESS TRACKING
# ==============================================================================

func _process(delta: float) -> void:
	_progress_timer += delta
	if _progress_timer >= PROGRESS_UPDATE_INTERVAL:
		_progress_timer = 0.0
		_update_all_task_progress()

func _update_all_task_progress() -> void:
	"""Update progress for all active task assignments"""
	var current_time = Time.get_unix_time_from_system()

	for god_id in _active_assignments.keys():
		var assignments = _active_assignments[god_id]
		for assignment in assignments:
			_update_task_progress_for_assignment(god_id, assignment, current_time)

func _update_task_progress_for_assignment(god_id: String, assignment: Dictionary, current_time: float) -> void:
	"""Update progress for a single assignment"""
	var assigned_task = get_task(assignment.task_id)
	if not assigned_task:
		return

	# Get god reference (would normally come from CollectionManager)
	# For now, calculate based on stored data
	var elapsed = current_time - assignment.start_time
	var duration = assigned_task.base_duration_seconds  # Would apply bonuses with god reference

	var progress = min(elapsed / duration, 1.0)

	# Emit progress update
	task_progress_updated.emit(god_id, assignment.task_id, progress)

func get_task_progress(god: God, task_id: String) -> float:
	"""Get current progress for a god's task (0.0 to 1.0)"""
	if not god or not god.is_assigned_to_task(task_id):
		return 0.0

	var current_task = get_task(task_id)
	if not current_task:
		return 0.0

	var idx = god.current_tasks.find(task_id)
	if idx == -1 or idx >= god.task_start_times.size():
		return 0.0

	var start_time = god.task_start_times[idx]
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - start_time

	# Calculate duration with bonuses
	var trait_bonus = 0.0
	if _trait_manager:
		trait_bonus = _trait_manager.get_task_bonus_for_god(god, task_id)

	# Get multitask efficiency penalty
	var multitask_efficiency = 1.0
	if _trait_manager and god.get_current_task_count() > 1:
		var info = _trait_manager.get_multitask_info(god)
		multitask_efficiency = info.efficiency

	var duration = current_task.get_duration_for_god(god, trait_bonus, 0)  # skill_level would come from god
	duration = int(duration / multitask_efficiency)  # Efficiency affects duration

	return min(float(elapsed) / float(duration), 1.0)

func get_time_remaining(god: God, task_id: String) -> int:
	"""Get seconds remaining for a task"""
	var progress = get_task_progress(god, task_id)
	if progress >= 1.0:
		return 0

	var remaining_task = get_task(task_id)
	if not remaining_task:
		return 0

	var trait_bonus = 0.0
	if _trait_manager:
		trait_bonus = _trait_manager.get_task_bonus_for_god(god, task_id)

	var multitask_efficiency = 1.0
	if _trait_manager and god.get_current_task_count() > 1:
		var info = _trait_manager.get_multitask_info(god)
		multitask_efficiency = info.efficiency

	var duration = remaining_task.get_duration_for_god(god, trait_bonus, 0)
	duration = int(duration / multitask_efficiency)

	var idx = god.current_tasks.find(task_id)
	if idx == -1 or idx >= god.task_start_times.size():
		return duration

	var start_time = god.task_start_times[idx]
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - start_time

	return max(0, duration - int(elapsed))

func is_task_complete(god: God, task_id: String) -> bool:
	"""Check if a task is ready to be collected"""
	return get_task_progress(god, task_id) >= 1.0

# ==============================================================================
# REWARD COLLECTION
# ==============================================================================

func collect_task_rewards(god: God, task_id: String) -> Dictionary:
	"""Collect rewards for a completed task"""
	if not god:
		return {}

	if not is_task_complete(god, task_id):
		return {}

	var completed_task = get_task(task_id)
	if not completed_task:
		return {}

	# Calculate rewards with bonuses
	var trait_bonus = 0.0
	if _trait_manager:
		trait_bonus = _trait_manager.get_task_bonus_for_god(god, task_id)

	var rewards = completed_task.get_rewards_for_god(god, trait_bonus, 0)

	# Add XP rewards
	rewards["god_xp"] = completed_task.experience_rewards.get("god_xp", 0)
	rewards["territory_xp"] = completed_task.experience_rewards.get("territory_xp", 0)
	rewards["skill_xp"] = completed_task.skill_xp_reward
	rewards["skill_id"] = completed_task.skill_id

	# Roll for item rewards
	var item_drops: Array = []
	for item_info in completed_task.item_rewards:
		if randf() <= item_info.chance:
			var count = randi_range(item_info.min, item_info.max)
			item_drops.append({"id": item_info.id, "count": count})
	rewards["items"] = item_drops

	# Remove task assignment
	unassign_god_from_task(god, task_id)

	# Re-assign if repeatable (auto-restart)
	# Per design, we don't auto-restart - player must manually reassign

	task_completed.emit(god.id, task_id, rewards)
	return rewards

# ==============================================================================
# OFFLINE PROGRESS (Full offline progress per design decision)
# ==============================================================================

func calculate_offline_progress(god: God, offline_duration_seconds: int) -> Array[Dictionary]:
	"""Calculate and apply offline progress for a god's tasks"""
	var completed_tasks: Array[Dictionary] = []

	if not god or god.current_tasks.size() == 0:
		return completed_tasks

	for i in range(god.current_tasks.size()):
		var task_id = god.current_tasks[i]
		var offline_task = get_task(task_id)
		if not offline_task:
			continue

		var start_time = god.task_start_times[i] if i < god.task_start_times.size() else 0

		# Calculate how many completions happened offline
		var trait_bonus = 0.0
		if _trait_manager:
			trait_bonus = _trait_manager.get_task_bonus_for_god(god, task_id)

		var multitask_efficiency = 1.0
		if _trait_manager and god.get_current_task_count() > 1:
			var info = _trait_manager.get_multitask_info(god)
			multitask_efficiency = info.efficiency

		var duration = offline_task.get_duration_for_god(god, trait_bonus, 0)
		duration = int(duration / multitask_efficiency)

		# Time already spent before going offline
		var time_before_offline = Time.get_unix_time_from_system() - offline_duration_seconds - start_time
		if time_before_offline < 0:
			time_before_offline = 0

		# Total time including offline
		var total_time = time_before_offline + offline_duration_seconds

		# Calculate completions
		var completions = int(total_time / duration)
		if completions > 0:
			# Calculate rewards for all completions
			var base_rewards = offline_task.get_rewards_for_god(god, trait_bonus, 0)
			var total_rewards: Dictionary = {}

			for key in base_rewards:
				total_rewards[key] = base_rewards[key] * completions

			total_rewards["completions"] = completions
			total_rewards["task_id"] = task_id
			total_rewards["god_xp"] = offline_task.experience_rewards.get("god_xp", 0) * completions
			total_rewards["territory_xp"] = offline_task.experience_rewards.get("territory_xp", 0) * completions
			total_rewards["skill_xp"] = offline_task.skill_xp_reward * completions
			total_rewards["skill_id"] = offline_task.skill_id

			completed_tasks.append(total_rewards)

			# Update start time for remaining progress
			var remainder = total_time - (completions * duration)
			god.task_start_times[i] = int(Time.get_unix_time_from_system() - remainder)

	return completed_tasks

# ==============================================================================
# UTILITY
# ==============================================================================

func get_gods_working_in_territory(territory_id: String) -> Array[String]:
	"""Get IDs of gods working on tasks in a territory"""
	var result: Array[String] = []

	for god_id in _active_assignments.keys():
		for assignment in _active_assignments[god_id]:
			if assignment.territory_id == territory_id:
				if god_id not in result:
					result.append(god_id)
				break

	return result

func get_task_count_in_territory(territory_id: String, task_id: String) -> int:
	"""Get number of gods working on a specific task in a territory"""
	var count = 0

	for god_id in _active_assignments.keys():
		for assignment in _active_assignments[god_id]:
			if assignment.territory_id == territory_id and assignment.task_id == task_id:
				count += 1

	return count

func is_loaded() -> bool:
	"""Check if tasks have been loaded"""
	return _is_loaded

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving"""
	return {
		"active_assignments": _active_assignments.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	"""Load saved data"""
	if data.has("active_assignments"):
		_active_assignments = data.active_assignments.duplicate(true)
