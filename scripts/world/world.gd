# world.gd
# With enhanced distance fog to hide chunk generation pop-in

extends Node3D

# Scene references
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_generator: Node3D = $WorldGenerator
@onready var scene_camera: Camera3D = $SceneCamera

# Player management
var player: Node3D = null
var player_scene: PackedScene = preload("res://scenes/player/snaut.tscn")  # Update this path!

# Environment
var world_env: WorldEnvironment
var env: Environment

# Sky shader properties
var exoplanet_sky_material: ShaderMaterial
var cloud_noise_texture: Texture2D
var time_of_day: float = 0.3
var day_duration: float = 600.0

var is_planet_nearby: bool = false
var is_high_end_device: bool = true

func _ready() -> void:
	print("World scene ready.")
	
	# Verify world generator
	if not world_generator:
		push_error("World: WorldGenerator node not found! Terrain will not generate.")
		return
	
	# Activate scene camera for loading
	if scene_camera:
		scene_camera.make_current()
		print("World: Scene camera active for loading.")
	
	# Setup environment and visuals
	create_environment()
	setup_sky_shader()
	apply_environment_settings()
	setup_advanced_effects()
	
	print("Environment applied: ", env.background_mode == Environment.BG_SKY)
	print("Sky material applied: ", env.sky and env.sky.sky_material == exoplanet_sky_material)
	
	# Remove holding area if it exists
	_remove_holding_area()
	
	# Wait for initial chunk generation, then spawn player
	print("World: Waiting for terrain generation...")
	await get_tree().create_timer(1.5).timeout
	_spawn_player()

func _spawn_player() -> void:
	print("World: Spawning player...")
	
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 5, 0)
	
	await get_tree().process_frame
	
	# Notify world generator about player
	if world_generator:
		world_generator.set_player(player)
		print("World: Player reference sent to WorldGenerator.")
	
	# Clean up scene camera
	if scene_camera:
		scene_camera.queue_free()
		scene_camera = null
	
	call_deferred("_enter_playing_state")

func _enter_playing_state() -> void:
	print("World: Entering playing state...")
#	GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("World: Ready for gameplay!")

func _process(delta: float) -> void:
	# Update time of day
	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	# Update sky and environment
	update_sky(time_of_day)
	update_environment(time_of_day)

func create_environment() -> void:
	world_env = $WorldEnvironment
	env = Environment.new()
	
	if world_env:
		world_env.environment = env
		print("Applied new environment to existing WorldEnvironment node")
	else:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		world_env.environment = env
		add_child(world_env)
		print("Created new WorldEnvironment node")
	
	env.background_mode = Environment.BG_SKY
	print("New environment created successfully")

func setup_sky_shader() -> void:
	var sky = Sky.new()
	exoplanet_sky_material = ShaderMaterial.new()
	
	var shader = load("res://shaders/exoplanet_sky.gdshader")
	if not shader:
		push_error("Failed to load exoplanet sky shader!")
		return
		
	exoplanet_sky_material.shader = shader
	
	cloud_noise_texture = load("res://shaders/cloud_noise.tres")
	if not cloud_noise_texture:
		push_warning("Cloud noise texture not found!")
	else:
		exoplanet_sky_material.set_shader_parameter("cloud_noise_texture", cloud_noise_texture)
	
	# Set shader parameters
	exoplanet_sky_material.set_shader_parameter("sky_top_color", Color(0.1, 0.25, 0.4))
	exoplanet_sky_material.set_shader_parameter("sky_horizon_color", Color(0.5, 0.7, 0.65))
	exoplanet_sky_material.set_shader_parameter("sky_bottom_color", Color(0.2, 0.3, 0.5))
	exoplanet_sky_material.set_shader_parameter("sky_horizon_blend", 0.1)
	exoplanet_sky_material.set_shader_parameter("sky_curve", 1.5)
	exoplanet_sky_material.set_shader_parameter("sun_color", Color(1.5, 1.2, 0.8))
	exoplanet_sky_material.set_shader_parameter("second_sun_color", Color(1.0, 0.5, 0.3))
	exoplanet_sky_material.set_shader_parameter("sun_size", 0.2)
	exoplanet_sky_material.set_shader_parameter("sun_blur", 0.5)
	exoplanet_sky_material.set_shader_parameter("second_sun_size", 0.1)
	exoplanet_sky_material.set_shader_parameter("cloud_coverage", 0.6)
	exoplanet_sky_material.set_shader_parameter("cloud_thickness", 2.2)
	exoplanet_sky_material.set_shader_parameter("cloud_color1", Color(0.95, 1.0, 0.98))
	exoplanet_sky_material.set_shader_parameter("cloud_color2", Color(0.8, 0.85, 0.9))
	exoplanet_sky_material.set_shader_parameter("cloud_speed", 0.003)
	exoplanet_sky_material.set_shader_parameter("enable_aurora", true)
	exoplanet_sky_material.set_shader_parameter("aurora_color1", Color(0.1, 0.8, 0.3))
	exoplanet_sky_material.set_shader_parameter("aurora_color2", Color(0.3, 0.3, 0.8))
	exoplanet_sky_material.set_shader_parameter("aurora_intensity", 1.0)
	exoplanet_sky_material.set_shader_parameter("aurora_speed", 0.5)
	exoplanet_sky_material.set_shader_parameter("enable_stars", true)
	exoplanet_sky_material.set_shader_parameter("star_intensity", 0.3)
	
	update_sun_direction(time_of_day)
	
	sky.sky_material = exoplanet_sky_material
	env.sky = sky
	
	print("Exoplanet sky shader set up successfully.")

func update_environment(time: float) -> void:
	if not env:
		return
		
	var day_factor = sin(time * TAU)
	
	# Adjust ambient light based on time of day
	var ambient_energy = remap(day_factor, -1.0, 1.0, 0.2, 0.8)
	env.ambient_light_energy = ambient_energy
	env.ambient_light_sky_contribution = remap(day_factor, -1.0, 1.0, 0.3, 0.7)
	env.tonemap_exposure = remap(day_factor, -1.0, 1.0, 1.2, 0.9)
	env.glow_intensity = remap(day_factor, -1.0, 1.0, 0.8, 0.5)
	
	# Adjust fog based on time of day
	if day_factor > 0:
		# Day - lighter fog
		env.fog_density = 0.008
		env.fog_light_color = Color(0.7, 0.75, 0.8)
	else:
		# Night - denser fog for mystery
		env.fog_density = 0.005
		env.fog_light_color = Color(0.3, 0.35, 0.45)
	
	# Volumetric fog
	var fog_density = remap(day_factor, -1.0, 1.0, 0.025, 0.015)
	env.volumetric_fog_density = fog_density
	
	if day_factor > 0:
		env.volumetric_fog_albedo = Color(0.12, 0.13, 0.17)
	else:
		env.volumetric_fog_albedo = Color(0.08, 0.08, 0.18)
	
	env.ssao_intensity = remap(day_factor, -1.0, 1.0, 2.5, 1.8)

func update_sky(time: float) -> void:
	if not exoplanet_sky_material:
		return
		
	update_sun_direction(time)
	
	var day_factor = sin(time * TAU)
	
	if day_factor > 0:
		var top_color = Color(0.1, 0.2, 0.4)
		var horizon_color = Color(0.5, 0.7, 0.8)
		exoplanet_sky_material.set_shader_parameter("sky_top_color", top_color)
		exoplanet_sky_material.set_shader_parameter("sky_horizon_color", horizon_color)
		exoplanet_sky_material.set_shader_parameter("star_intensity", 0.05)
	else:
		var top_color = Color(0.02, 0.05, 0.1)
		var horizon_color = Color(0.1, 0.12, 0.15)
		exoplanet_sky_material.set_shader_parameter("sky_top_color", top_color)
		exoplanet_sky_material.set_shader_parameter("sky_horizon_color", horizon_color)
		exoplanet_sky_material.set_shader_parameter("star_intensity", 0.3)
	
	exoplanet_sky_material.set_shader_parameter("enable_aurora", day_factor < 0)

func update_sun_direction(time: float) -> void:
	if not exoplanet_sky_material or not sun:
		return
		
	var sun_angle = time * TAU
	var sun_dir = Vector3(sin(sun_angle), sin(sun_angle * 2.0) * 0.3 + 0.4, -cos(sun_angle)).normalized()
	
	exoplanet_sky_material.set_shader_parameter("sun_direction", sun_dir)
	
	var second_sun_dir = Vector3(sun_dir.x * 0.8, sun_dir.y * 0.5, sun_dir.z * 0.7).normalized()
	exoplanet_sky_material.set_shader_parameter("second_sun_direction", second_sun_dir)
	
	sun.rotation = Vector3(-sun_dir.y, -sun_dir.x, sun_dir.z).normalized()
	
	var sun_height = sun_dir.y
	sun.light_energy = max(0.0, sun_height) * 1.5
	
	if sun_height > 0:
		if sun_height < 0.2:
			sun.light_color = Color(1.0, 0.6, 0.3)
		else:
			sun.light_color = Color(1.0, 0.98, 0.88)
	else:
		sun.light_energy = 0.2
		sun.light_color = Color(0.6, 0.6, 0.8)

func apply_environment_settings() -> void:
	# Enhanced distance fog to hide chunk generation
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.8)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.1
	env.fog_density = 0.007  # Adjust this to control fog thickness
	env.fog_aerial_perspective = 0.5  # Adds depth perception
	env.fog_sky_affect = 0.3
	env.fog_height = -5.0  # Ground-level fog
	env.fog_height_density = 0.4
	
	# Volumetric fog for atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.009
	env.volumetric_fog_albedo = Color(0.12, 0.13, 0.17)
	env.volumetric_fog_emission_energy = 0.1
	env.volumetric_fog_gi_inject = 1.0
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_sky_affect = 0.3
	env.volumetric_fog_length = 180.0  # Fog extends to camera far plane
	
	# Ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.8
	
	# Shadow settings
	if sun:
		sun.shadow_enabled = true
		sun.shadow_bias = 0.03
		sun.directional_shadow_max_distance = 300.0
	
	# SSAO
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.0
	env.ssao_power = 1.8
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.08
	env.ssao_sharpness = 0.98
	
	# Tonemap
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 1.0
	
	# Glow
	env.glow_enabled = true
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.3)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.5)
	env.set_glow_level(4, 0.2)
	env.set_glow_level(5, 0.0)
	env.set_glow_level(6, 0.0)
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	print("Enhanced environment with distance fog applied.")

func setup_advanced_effects() -> void:
	if is_planet_nearby:
		env.fog_density = 0.005  # More fog near planet
		env.volumetric_fog_density = 0.025
		
		if exoplanet_sky_material:
			exoplanet_sky_material.set_shader_parameter("aurora_intensity", 1.5)
	else:
		if exoplanet_sky_material:
			exoplanet_sky_material.set_shader_parameter("aurora_intensity", 0.8)

	if not is_high_end_device:
		env.ssao_enabled = false
		env.glow_enabled = false
		print("Low-end device: Disabling SSAO and glow.")
	else:
		print("High-end device: Applying full effects.")

	print("Advanced effects applied.")

func _remove_holding_area() -> void:
	var holding_area = get_node_or_null("holdingArea")
	if holding_area:
		holding_area.queue_free()
		print("World: Holding area removed.")

func remap(value: float, from_low: float, from_high: float, to_low: float, to_high: float) -> float:
	return (value - from_low) / (from_high - from_low) * (to_high - to_low) + to_low
