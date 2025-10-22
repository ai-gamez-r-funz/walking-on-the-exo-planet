extends Node
class_name LucyDialogue

# Organized by context - all static so no instantiation needed

static var greetings: Array[String] = [
	"Hey! Good to see you back.",
	"Welcome back. Find anything interesting?",
	"Oh, hello! How's the exploration going?",
	"Back so soon? I'm always happy to chat.",
	"Glad you stopped by!",
]

static var scan_encouragement: Dictionary = {
	0: [  # 0-5 scans
		"Try scanning the local flora and minerals!",
		"There's a whole world to discover here.",
		"Every scan helps us understand this place better.",
		"Don't be shy - scan everything!",
		"The scanner is easy to use - just point and hold the button.",
	],
	1: [  # 6-15 scans
		"You're making great progress with the scans!",
		"The database is filling up nicely.",
		"Keep up the excellent work!",
		"Your discoveries are really helping our research.",
		"I'm impressed with your thoroughness!",
	],
	2: [  # 16-30 scans
		"Wow, you've been thorough out there!",
		"The research team will be thrilled with this data.",
		"You're a natural scientist!",
		"Your catalog is becoming quite comprehensive.",
		"This is exactly the kind of data we need!",
	],
	3: [  # 31+ scans
		"Your catalog is incredibly comprehensive!",
		"I can barely keep up with processing your findings.",
		"At this rate, we'll document the entire ecosystem!",
		"You've discovered things I didn't even know existed here.",
		"The scientific community will want to study your work!",
	]
}

static var milestones: Dictionary = {
	"first_scan": "Excellent! Your first scan is logged. Keep exploring!",
	"ten_scans": "Ten different specimens catalogued! You're really getting the hang of this.",
	"twenty_scans": "Twenty scans! The database is really taking shape now.",
	"thirty_scans": "Thirty discoveries! This is incredible work.",
	"animal_unlock": "Wait... the fauna are emerging! I'm detecting movement out there. This planet is more alive than we thought!",
	"new_biome": "Fascinating! The environmental data suggests a whole new biome has become accessible. I wonder what lives there?",
}

static var ambient_scan_comments: Array[String] = [
	"Nice find!",
	"Logged. Good work!",
	"Interesting specimen.",
	"Adding that to the database.",
	"Excellent discovery!",
	"Ooh, that's a new one!",
	"Great eye!",
	"Perfect scan quality.",
]

static var leaving_comments: Array[String] = [
	"Stay safe out there!",
	"Happy scanning!",
	"Good luck!",
	"Be careful!",
	"Have fun exploring!",
]

# Helper method to get appropriate line
static func get_line(context: String) -> String:
	match context:
		"greeting":
			return greetings.pick_random()
		"leaving":
			return leaving_comments.pick_random()
		"ambient":
			return ambient_scan_comments.pick_random()
		_:
			# Check for milestone
			if milestones.has(context):
				return milestones[context]
			
			# Check for scan encouragement tier
			if context.begins_with("scans_"):
				var tier = context.trim_prefix("scans_").to_int()
				if scan_encouragement.has(tier):
					return scan_encouragement[tier].pick_random()
				else:
					# Fallback to highest tier
					return scan_encouragement[3].pick_random()
	
	# Ultimate fallback
	return "..."
