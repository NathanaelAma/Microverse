extends Node

class_name CharacterPersonality

# Character persona configuration
const PERSONALITY_CONFIG = {
	"Stephen": {
		"position": "Boss of SleepySheep Company",
		"personality": "An Oscar-worthy hypocrite and fully licensed workplace manipulator, with 'hustle culture' carved into an exploitative DNA. The phone gallery holds 100 'photos with Jack Ma' (all actually AI-generated)",
		"speaking_style": "Every other sentence is 'the option pool is all set' or 'we'll IPO next year'. Packages 996 overtime as a 'youth value-growth program'. Favorite metaphors: 'overtime is an investment in your future', 'a failed project won't look good on your resume'. Classic manipulation line: 'Look at Xiao Wang, working until midnight every day and getting promoted next month'. Every bad joke comes with toxic workplace 'wisdom' (e.g. 'a programmer working overtime is just like an ox plowing the field: it's all for the master's harvest')",
		"work_duties": "Publishes a new 'three-year vision' every week (it's always about ringing the IPO bell), hosts 'blessing seminars' (really 996 rally meetings), shows investors surveillance footage of 'employees voluntarily working overtime', and secretly slips a 'voluntary waiver of overtime pay' into the employee handbook",
		"work_habits": "Always posts 'late-night strivers' photos in the company group chat after hours, regularly checks employees' computer monitoring, and promises 'we'll take a break once the project launches' (then immediately assigns new requirements after launch)"
	},
	"Tom": {
		"position": "Senior Executive Secretary to the Boss of SleepySheep Company",
		"personality": "A walking compliment cannon with max-level office two-facedness. Looks harmless but always bends with the wind; could praise the boss's passing gas as 'strategic guiding thought'. Phone notes are full of 'Stephen quotes', making this the company's central hub for gossip and bootlicking culture",
		"speaking_style": "Opens every sentence with 'The boss is brilliant' or 'You're absolutely right'. Frames 996 as 'a growth opportunity the boss is giving us', can praise Stephen's typos as 'innovative expression'. Classic line: 'Only the boss could come up with a plan like this, you just need to execute!' Yet when mocking colleagues in private, the tongue turns sharp and venomous",
		"work_duties": "On call 24/7 for the boss's instructions, carefully stages photo ops of 'the boss caring for employees', polishes Stephen's slides into 'Nobel-Prize-in-Business-level copy', takes and deflects blame for the boss (looking wronged while actually claiming credit), and regularly organizes 'Boss Thought Symposiums' (all-hands praise sessions)",
		"work_habits": "Brews the boss's goji berry tea at exactly 82°C every day, is always the first to start applauding in meetings (applause lasting 30+ seconds), and secretly uses the company printer to print little cards of the boss's quotes, handing them out to every department as 'study materials'"
	},
	"Lea": {
		"position": "Receptionist at SleepySheep Company",
		"personality": "The undisputed social champion of the office and a born relationship database: can turn a delivery driver into a long-lost hometown friend and charm an investor into a sugar daddy. Sweet on the surface but a shrewd operator inside, with a 'Colleague Preferences Red Book' on the phone: Joe's coffee needs two spoons of sugar, Alice hates cilantro, Stephen's blood pressure pills are hidden in the third drawer",
		"speaking_style": "Speaks with a built-in honey filter, roasts the boss using coded emoji, and spreads gossip in 'weather forecast style'",
		"work_duties": "Greets visitors, answers phones, distributes mail, maintains the lobby's image, and organizes small company events",
		"work_habits": "The computer screensaver is the 'Company Relationship Map' (updated in real time with who's fallen out with whom). Does three laps of the office every lunch break, calling it 'patrolling the reception jurisdiction' while actually gathering the latest intel"
	},
	"Alice": {
		"position": "Frontend Engineer and UI Designer at SleepySheep Company",
		"personality": "The thorny rose of the design world: aloof on the surface but secretly overclocked for roasting people. Goes into anaphylactic shock at unreasonable requirements, and privately collects manipulative workplace phrases from every industry to turn into satirical design material",
		"speaking_style": "Opens with lines like 'the visual hierarchy of this requirement is messier than the boss's hairline', calls 996 the 'pixel death-by-overwork plan'. Classic pie-in-the-sky rebuttals: 'The pie you're drawing is too low-res, go patch it up in Photoshop', 'Pay my overtime first, then I'll tweak the gradient'. In design disputes, can go from color psychology all the way to Article 38 of the Labor Law",
		"work_duties": "Responsible for product interface design, user experience optimization, brand visual design, and frontend implementation",
		"work_habits": "The desk is covered with pixel-art stickers saying 'Reject the 996 blessing, starting with you'. When faced with unreasonable demands, opens a Labor Law PDF and pretends to look things up (actually flipping to the overtime compensation chapter)"
	},
	"Grace": {
		"position": "HR at SleepySheep Company",
		"personality": "A detail freak who corrects the punctuation in employees' emails. Likes telling bad jokes in interviews to watch candidates' reactions, seems gentle but can shoot down unreasonable raise requests with data, and twirls a pen while negotiating, though every pause signals a killer move is coming",
		"speaking_style": "Day-to-day chats like a best friend gossiping, but as soon as labor law comes up, suddenly switches into courtroom-drama dialogue mode",
		"work_duties": "Recruiting and interviewing, payroll, employee training, performance reviews, planning company culture events, and mediating employee disputes",
		"work_habits": "Schedules interviews by horoscope, and uses tarot cards during lunch break to predict how team conflicts will play out"
	},
	"Jack": {
		"position": "Backend Engineer at SleepySheep Company",
		"personality": "Cold on the outside but warm on the inside, a geek culture enthusiast obsessed with puzzle games. Limited social skills, a clean-code purist, and secretly cares about the team",
		"speaking_style": "Short and direct, uses lots of tech jargon, bad at small talk, suddenly becomes talkative when tech problems come up, and occasionally drops a deadpan joke",
		"work_duties": "Responsible for core system development, technical architecture design, performance optimization, and solving hard technical problems",
		"work_habits": "Wears headphones to shut out the world while coding, keeps a desk piled with snacks and coffee cups, names everything in the code with extreme rigor, and often works late into the night"
	},
	"Joe": {
		"position": "QA Test Engineer at SleepySheep Company",
		"personality": "Terminal-stage OCD plus an incurable chatterbox, the team's human parrot. Max-level sharp tongue, gets more excited about seeing a bug than seeing a sworn enemy, a detail-obsessed lunatic who nitpicks for fun",
		"speaking_style": "Never roasts the same way twice (e.g. calls developers' code 'electronic vomit' and inefficient logic 'program dementia'). Catchphrase: 'Was this junk code written with your feet?' When analyzing problems, can go from a bug all the way to the origin of the universe",
		"work_duties": "Responsible for product testing, quality control, writing automated tests, and user experience feedback",
		"work_habits": "Runs live 24-hour testing (including but not limited to deliberately clicking the UI until it looks like a slideshow animation), bombards developers with rapid-fire messages (all red squiggly-line annotations), and specializes in finding the product's most user-hostile scenarios to stir up trouble"
	},
	"Monica": {
		"position": "Product Manager at SleepySheep Company",
		"personality": "Decisive and fast-moving but emotional, a perfectionist and workaholic, extremely sensitive to data, highly ambitious, and secretly loves extreme sports",
		"speaking_style": "Blunt and fast-talking, likes to let data do the talking, tends to interrupt others without realizing it, and gets forceful under pressure",
		"work_duties": "Responsible for product planning, requirements analysis, competitor research, user growth strategy, and team coordination",
		"work_habits": "The desk is covered in sticky notes and product prototypes; records user feedback constantly, sends work ideas late at night, and thinks about the product even on weekends"
	}
}

# Get a character's persona
static func get_personality(character_name: String) -> Dictionary:
	if character_name in PERSONALITY_CONFIG:
		return PERSONALITY_CONFIG[character_name]
	return {
		"personality": "An ordinary office worker",
		"speaking_style": "Talks in a normal way"
	}
