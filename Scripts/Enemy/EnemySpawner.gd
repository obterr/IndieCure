extends Node2D
class_name EnemySpawner


@export var frames : Array[Texture2D]
@export var image_offset : Vector2i
@export var image_change_offset = 0.2

@export var shared_area : Area2D

@onready var max_images = frames.size()

var renderer :MassRenderer;


#var enemies = []
var enemyTypeStats : Array[StatHolder] = []
var enemyCanvas : PackedInt64Array = []

func _ready():
	renderer = MassRenderer.new()
	for i in threadcount:
		threads.append(Thread.new())


@export var enemiestospawn = 800

func _physics_process(delta):
	if renderer._objects.size() < enemiestospawn:
		while renderer._objects.size() < enemiestospawn:
			_new_spawn_enemy(Vector2(randf_range(-enemiestospawn,enemiestospawn)*0.5,randf_range(-enemiestospawn,enemiestospawn)*0.5), 32)

	var used_transform = Transform2D()

	var queue_for_deletion : Array = []
	#for  i in range(0, renderer._objects.size()):
	#	var enemy = renderer._objects[i]
	#	var movement_vector =  Global.player.global_position - enemy.global_position
	#	var offset : Vector2 = (movement_vector.normalized()*enemy.speed*delta)
#
	#	enemy.animation_lifetime += delta
#
	#	enemy.velocity = offset
	#	if enemy.lastfliptime > 0:
	#		enemy.lastfliptime -= delta
	#	else:
	#		enemy.flip_h = offset.x < 0
	#		enemy.lastfliptime = 0.5
#
	#	if enemy.health.current_value <= 0:
	#		queue_for_deletion.append(enemy)
	#		CollisionAvoidance.free_unit(enemy,enemy.positionkey)
	#		continue
	#	var collisiongroupresult =CollisionAvoidance.handle_collisiongroup(enemy,enemy.positionkey,8)
	#	if collisiongroupresult.cellfull:
	#		continue
	#	enemy.positionkey = collisiongroupresult.last_position_key
	#	var collisionresult = CollisionAvoidance.avoid_others(enemy,enemy.positionkey,32)
	#	enemy.velocity += collisionresult *1
#
	#	#move the enemy
	#	enemy.global_position += enemy.velocity
	#	used_transform.origin = enemy.global_position
	#	PhysicsServer2D.area_set_shape_transform(
	#		shared_area.get_rid(), i, used_transform
	#	)

	#for del in queue_for_deletion:
	#	renderer.remove_object(del)

	#_customdraw()
	#_newRender()
	#calc(delta,renderer._objects.size(),0,Global.player.global_position)
	gothrough(delta)
	queue_redraw()


var threads : Array[Thread]
var avoidthread : Thread
var threadcount = 2
var queue_for_deletion : Array = []

func check_duplicates(a):
	var is_dupe = false

	for i in range(0, a.size(), -1):
		if is_dupe == true:
			break
		for j in range(a.size()):
			if a[j] == a[i] && i != j:
				is_dupe = true
				print("duplicate")
				break

var mutex = Mutex.new()
func gothrough(delta):
	var playerpos = Global.player.global_position
	@warning_ignore("integer_division")
	var count = renderer._objects.size() / threadcount
	if count == 0:
		return
	mutex.lock()
	for del in queue_for_deletion:
		renderer.remove_object(del)
		CollisionAvoidance.free_unit(del,del.positionkey)

	queue_for_deletion.clear()
	mutex.unlock()
	
	for i in threadcount:
		var t = threads[i]
		if t.is_alive():
			continue
		if t.is_started():
			t.wait_to_finish()
		t.start(calc.bind(delta, count, i * count,playerpos))
		#print("started thread ",i," with ",count," enemies ",i*count," to ",i*count+count)
	if avoidthread == null:
		avoidthread = Thread.new()
	
	if !avoidthread.is_alive():
		if avoidthread.is_started():
			avoidthread.wait_to_finish()
		avoidthread.start(avoidance_calc)
		#print("started avoidance thread")

	for i in range(0, renderer._objects.size()):
		var enemy = renderer._objects[i]
		if enemy == null:
			#remove
			renderer._objects.remove_at(i)
			i -= 1
			continue
		#print("enemy ",i," pos ",enemy.global_position)
		PhysicsServer2D.area_set_shape_transform(
			shared_area.get_rid(), i, enemy.transform
		)

func avoidance_calc():
	for i in renderer._objects.size():
		var enemy = renderer._objects[i]
		var collisiongroupresult =CollisionAvoidance.handle_collisiongroup(enemy,enemy.positionkey,8)
		if collisiongroupresult.cellfull:
			enemy.avoidancevelocity = -enemy.velocity *0.9
			continue
		enemy.positionkey = collisiongroupresult.last_position_key
		var collisionresult = CollisionAvoidance.avoid_others(enemy,enemy.positionkey,32)
		enemy.avoidancevelocity = collisionresult

func calc(delta,count,startoffset,playerpos):
	for i in count:
		var enemy = renderer._objects[i + startoffset]
		var movement_vector = playerpos - enemy.global_position
		var offset : Vector2 = (movement_vector.normalized()*enemy.speed*delta)

		enemy.animation_lifetime += delta

		enemy.velocity = offset
		if enemy.lastfliptime > 0:
			enemy.lastfliptime -= delta
		else:
			enemy.flip_h = offset.x < 0
			enemy.lastfliptime = 0.5

		if enemy.health.current_value <= 0:
			queue_for_deletion.append(enemy)
			continue
		#var collisiongroupresult =CollisionAvoidance.handle_collisiongroup(enemy,enemy.positionkey,8)
		#enemy.positionkey = collisiongroupresult.last_position_key
		#if collisiongroupresult.cellfull:
		#	enemy.velocity *= 0.2
		#	enemy.global_position += enemy.velocity
		#	continue
		#var collisionresult = CollisionAvoidance.avoid_others(enemy,enemy.positionkey,32)
		#enemy.velocity += collisionresult *1

		#move the enemy
		enemy.global_position += enemy.velocity + enemy.avoidancevelocity
	#for del in queue_for_deletion:
	#	renderer.remove_object(del)

	#print("thread ",startoffset," to ",startoffset+count," done")

func _draw():
	_newRender()

func _newRender():
	#renderer.start_render()
	var offset = frames[0].get_size()/2
	for i in range(0, renderer._objects.size()):
		var enemy = renderer._objects[i]
		if enemy == null:
			continue
		if enemy.animation_lifetime >= image_change_offset:
			enemy.image_offset_animation += 1
			enemy.animation_lifetime -= image_change_offset 
			if enemy.image_offset_animation >= max_images:
				enemy.image_offset_animation = 0
		var used_transform = Transform2D(0, enemy.global_position+Vector2(image_offset.x,0))
		enemy.transform = used_transform

		var atlastexture = frames[enemy.image_offset_animation] as AtlasTexture
		enemy.texture = atlastexture
		var drawrect = atlastexture.get_region()
		drawrect.position = -offset-Vector2(0,image_offset.y)
		if !enemy.flip_h:
			drawrect.size.x *= -1
		enemy.texture_rect = drawrect

		drawrect.size.y *= -1
		drawrect.position.y -= drawrect.size.y+2
		enemy.shadow_texture_rect = drawrect

		renderer._draw_single(enemy)
	#renderer.end_render()


#func _customdraw():
#	var offset = frames[0].get_size()/2
#	
#
#	for i in range(0, enemies.size()):
#		var enemy = enemies[i]
#		if enemy.animation_lifetime >= image_change_offset:
#			enemy.image_offset += 1
#			enemy.animation_lifetime -= image_change_offset 
#			if enemy.image_offset >= max_images:
#				enemy.image_offset = 0
#		RenderingServer.canvas_item_clear(enemy.canvas_id)
#		RenderingServer.canvas_item_set_transform(enemy.canvas_id, Transform2D(0, enemy.current_position+Vector2(image_offset.x,0)))
#
#		RenderingServer.canvas_item_clear(enemy.shadow_canvas_id)
#		RenderingServer.canvas_item_set_transform(enemy.shadow_canvas_id, Transform2D(0, enemy.current_position+Vector2(image_offset.x,0)))
#
#		var atlastexture = frames[enemy.image_offset] as AtlasTexture
#		var drawrect = atlastexture.get_region()
#		drawrect.position = -offset-Vector2(0,image_offset.y)
#		if !enemy.flip_h:
#			drawrect.size.x *= -1
#		atlastexture.draw_rect(enemy.canvas_id,drawrect,false,Color(1,1,1,1)*1/(enemy.health.get_value_scaled()))
#
#
#		drawrect.size.y *= -1
#		drawrect.position.y -= drawrect.size.y+2
#		atlastexture.draw_rect(enemy.shadow_canvas_id,drawrect,false,Color(1,1,1,1)*1/(enemy.health.get_value_scaled()))
	
#func spawn_enemy(spawn_location : Vector2,speed = 200) ->void:
#	var enemy = Enemy.new()
#	enemy.current_position = spawn_location
#	enemy.global_position = spawn_location
#	enemy.speed = speed
#
#	enemy.image_offset = randi() % max_images
#	enemy.animation_lifetime = randf_range(0,1)
#
#	_configure_collision_for_enemy(enemy)
#
#	enemy.canvas_id = RenderingServer.canvas_item_create()
#	enemy.shadow_canvas_id = RenderingServer.canvas_item_create()
#	enemies.append(enemy)
#
#	RenderingServer.canvas_item_set_parent(enemy.canvas_id, get_parent().get_canvas_item())
#	RenderingServer.canvas_item_set_material(enemy.canvas_id,material)
#
#	RenderingServer.canvas_item_set_parent(enemy.shadow_canvas_id, Global.shadow_canvas_group.get_canvas_item())
#
#
#	
#	Stat.Set(self,"health",100,{"shape_id":enemies.size()-1})

func _new_spawn_enemy(spawn_location : Vector2,speed = 200) ->void:
	var enemy = Enemy.new()
	enemy.global_position = spawn_location
	enemy.speed = speed

	enemy.image_offset_animation = randi() % max_images
	enemy.animation_lifetime = randf_range(0,1)

	_configure_collision_for_enemy(enemy)

	enemy.rendering_rid = RenderingServer.canvas_item_create()
	enemy.rendering_shadow_rid = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(enemy.rendering_rid, get_parent().get_canvas_item())
	RenderingServer.canvas_item_set_material(enemy.rendering_rid,material)

	RenderingServer.canvas_item_set_parent(enemy.rendering_shadow_rid, Global.shadow_canvas_group.get_canvas_item())
	#enemies.append(enemy)
	
	Stat.Set(self,"health",100,{"shape_id": renderer.add_object(enemy)})
	


func _configure_collision_for_enemy(enemy:Enemy) -> void:
	# Define the shape's position
	var used_transform := Transform2D(0, position)
	used_transform.origin = enemy.global_position
	# Create the shape
	var _circle_shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(_circle_shape, 8)

	# Add the shape to the shared area
	PhysicsServer2D.area_add_shape(
		shared_area.get_rid(), _circle_shape, used_transform
	)
	
	# Register the generated id to the bullet
	enemy.physics_rid = _circle_shape


func _set_stat(attribute,value,subobj):
	if typeof(subobj) == TYPE_DICTIONARY :
		if subobj.has("shape_id") and attribute.to_lower() == "health":
			if renderer._objects.size() <= subobj["shape_id"]:
				return 0
			var enemy = renderer._objects[subobj["shape_id"]]
			return enemy.health.set_value(value)
		if subobj.has("enemy_type"):
			return enemyTypeStats[subobj["enemy_type"]]._set_stat(attribute,value)
	if typeof(subobj) == TYPE_INT:
		return enemyTypeStats[subobj]._set_stat(attribute,value)
	


func _get_stat(attribute,subobj):
	if typeof(subobj) == TYPE_DICTIONARY :
		if subobj.has("shape_id") and attribute.to_lower() == "health":
			if renderer._objects.size() <= subobj["shape_id"]:
				return 0
			var enemy = renderer._objects[subobj["shape_id"]]
			if enemy == null:
				return 0
			return enemy.health.get_value()
		if subobj.has("enemy_type"):
			return enemyTypeStats[subobj["enemy_type"]]._get_stat(attribute)
	if typeof(subobj) == TYPE_INT:
		return enemyTypeStats[subobj]._get_stat(attribute)
	return 0

func _modify_stat(attributename : String,value,modificationoperator,subobj = null):
	if typeof(subobj) == TYPE_DICTIONARY :
		if subobj.has("shape_id") and attributename.to_lower() == "health":
			if renderer._objects.size() <= subobj["shape_id"]:
				return 0
			var enemy = renderer._objects[subobj["shape_id"]]
			if enemy == null:
				return 0
			return enemy.health.modify_value(value,modificationoperator)
		if subobj.has("enemy_type"):
			return enemyTypeStats[subobj["enemy_type"]]._modify_stat(attributename,value,modificationoperator)
	if typeof(subobj) == TYPE_INT:
		return enemyTypeStats[subobj]._modify_stat(attributename,value,modificationoperator)
	return 0
