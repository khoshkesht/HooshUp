extends Node

# Single source of truth for the campaign map and mission captions.
const STAGES := [
	{"title": "میهمان تازه", "progress_title": "AI چه کارهایی می‌کند؟", "missions": ["مهمان جدید", "میتونی کمکم کنی؟", "از کجا جواب می‌آورد؟", "ابزار درست", "اولین همکاری"]},
	{"title": "استاد پرامپت", "missions": ["چی ازش بخوام؟", "واضح‌تر بگو", "جزئیات مهم‌اند", "یک کلمه، یک تفاوت", "پرامپت نهایی"]},
	{"title": "پرونده ناقص", "missions": ["اطلاعات کم", "سرنخ‌های گمشده", "چی لازمه بدونه؟", "برداشت اشتباه", "تصویر کامل"]},
	{"title": "ارتقای جواب", "missions": ["جواب اول", "بهترش کن", "دقیق‌ترش کن", "هنوز یه چیزی کمه", "نسخه نهایی"]},
	{"title": "مدرسه هوشمند", "missions": ["یه درس سخت", "جور دیگه توضیح بده", "مثال بزن", "جواب آماده؟", "خودم فهمیدم"]},
	{"title": "استودیوی خلاقیت", "missions": ["صفحه سفید", "بارش ایده‌ها", "انتخاب بهترین‌ها", "شبیه بقیه نباش", "ساخته‌ی من"]},
	{"title": "AI اشتباه کرد", "missions": ["همه‌چی درست به نظر میاد", "یه جای کار می‌لنگه", "اشتباه رو پیدا کن", "مطمئن حرف می‌زنه!", "اعتماد، اما نه کورکورانه"]},
	{"title": "حقیقت‌یاب", "missions": ["خبر رسیده", "منبع کجاست؟", "دو روایت", "مدرک کافی نیست", "حقیقت را پیدا کن"]},
	{"title": "منطقه ممنوعه", "missions": ["اینو می‌تونم بفرستم؟", "اطلاعات شخصی", "ردپای دیجیتال", "درخواست مشکوک", "خط قرمز"]},
	{"title": "فرمانده AI", "missions": ["انتخاب ابزار", "خودت یا AI؟", "کنترل دست توئه", "تصمیم سخت", "مأموریت نهایی"]}
]

func get_stage(stage_number: int) -> Dictionary:
	if stage_number < 1 or stage_number > STAGES.size():
		return {}
	return STAGES[stage_number - 1]

func get_mission_title(stage_number: int, mission_number: int) -> String:
	var stage := get_stage(stage_number)
	var missions: Array = stage.get("missions", [])
	if mission_number < 1 or mission_number > missions.size():
		return ""
	return str(missions[mission_number - 1])
