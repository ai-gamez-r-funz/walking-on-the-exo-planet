extends Node
class_name ChadDialogue

# Chad is more casual and goofy

static var greetings: Array[String] = [
	"Yo! What's up?",
	"Hey, space buddy!",
	"Oh hey, it's you!",
	"Sup?",
	"Dude! Perfect timing!",
]

static var observations: Array[String] = [
	"I found this rock earlier. Pretty cool rock.",
	"Do you think there are aliens here? I mean... besides us?",
	"This planet's sky is weird, right? Or is it just me?",
	"I'm supposed to be collecting samples, but... I got distracted.",
	"Have you seen my other glove? I swear I had two.",
	"You ever wonder if we're the aliens?",
	"I named that rock over there Steve. Don't judge me.",
	"The scanner makes cool noises. You noticed?",
	"Sometimes I forget which way is up. Space is weird.",
	"I tried to scan myself once. Didn't work. Disappointing.",
	"Do you think plants can hear us? What if they're listening right now?",
	"I saw something move earlier. Probably just wind. Probably.",
]

static var scan_reactions: Array[String] = [
	"Whoa, you scanned something!",
	"Nice! What'd you find?",
	"Cool beans!",
	"Another one for the collection, nice!",
	"Sick!",
	"That's rad!",
	"You're like a scanning machine!",
]

static var leaving_comments: Array[String] = [
	"Later!",
	"Catch you on the flip side!",
	"See ya!",
	"Peace out!",
	"Don't do anything I wouldn't do!",
	"Try not to get eaten!",
]

static func get_line(context: String) -> String:
	match context:
		"greeting":
			return greetings.pick_random()
		"observation":
			return observations.pick_random()
		"scan_reaction":
			return scan_reactions.pick_random()
		"leaving":
			return leaving_comments.pick_random()
	
	# Fallback
	return "Uh... what?"
