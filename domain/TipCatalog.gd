class_name TipCatalog
extends RefCounted

const OFFLINE_GARDEN_ID: String = "offline_garden"
const OFFLINE_FOCUS_ID: String = "offline_focus"
const OFFLINE_SHOP_ID: String = "offline_shop"
const OFFLINE_SYNERGY_ID: String = "offline_synergy"
const OFFLINE_TASKS_ID: String = "offline_tasks"
const OFFLINE_WEATHER_ID: String = "offline_weather"


static func build_offline_fallback() -> Array[GameTip]:
	var tips: Array[GameTip] = []
	
	tips.append(GameTip.new(
		OFFLINE_GARDEN_ID,
		"Chăm Sóc Vườn",
		"Sử dụng các công cụ trong túi để gieo hạt, tưới nước (+20 XP), bón phân (+50 XP) hoặc diệt sâu bọ (+50 XP) cho hoa. " +
		"Mỗi hành động chăm sóc có thời gian hồi chiêu (cooldown) riêng biệt cho từng cây. " +
		"Khi hoa đạt Level 7 (Trưởng thành), bạn có thể tiến hành thu hoạch để nhận lượng lớn XP nâng cấp cho nhân vật.",
		10
	))
	
	tips.append(GameTip.new(
		OFFLINE_FOCUS_ID,
		"Chế Độ Tập Trung",
		"Di chuyển nhân vật của bạn đến khu vực trường học (thiết kế phỏng theo Đại học FPT) và bước vào lớp học để kích hoạt Chế độ tập trung (Hẹn giờ Pomodoro). " +
		"Gieo 'Cây Tri Thức' và thiết lập thời gian học tập. Trong thời gian này, nếu bạn thoát game hoặc mở ứng dụng khác quá số lần quy định, cây sẽ bị héo hoặc giảm kinh nghiệm. " +
		"Hoàn thành buổi học để nhận Vitality và các phần quà giá trị!",
		20
	))
	
	tips.append(GameTip.new(
		OFFLINE_SHOP_ID,
		"Cửa Hàng & Túi Đồ",
		"Dùng tiền xu tích lũy được từ các nhiệm vụ và việc đổi Vitality để mua các loại Hạt giống hoa mới, Phân bón tăng tốc hoặc đồ trang trí (Decor) trong Cửa Hàng (Shop). " +
		"Túi đồ (Inventory) chứa toàn bộ hạt giống và vật phẩm bạn đã mua, cho phép kéo thả sử dụng trực tiếp để trang trí hoặc trồng trong khu vườn.",
		30
	))
	
	tips.append(GameTip.new(
		OFFLINE_SYNERGY_ID,
		"Hệ Sinh Thái (Synergy)",
		"Khu vườn được chia thành nhiều khu vực (Zone). Khi bạn trồng từ 2 cây hoa trở lên cùng nhóm Synergy trong một Zone, hệ sinh thái sẽ được kích hoạt (có hiệu ứng lấp lánh). " +
		"Lúc này, mọi hành động chăm sóc như tưới nước hay bón phân trong Zone đó đều được cộng thêm điểm kinh nghiệm và năng lượng Vitality. " +
		"Hãy trồng hoa theo nhóm để tối đa hóa hiệu quả!",
		40
	))
	
	tips.append(GameTip.new(
		OFFLINE_TASKS_ID,
		"Nhiệm Vụ Hàng Ngày",
		"Hoàn thành các nhiệm vụ hàng ngày như Điểm danh để nhận các lượt Tăng tốc (tưới nước/bón phân miễn phí không cần thời gian chờ). " +
		"Ngoài ra còn có các nhiệm vụ ngày (ví dụ: tưới nước 3 lần) và nhiệm vụ hệ thống (sở hữu hoa hướng dương đạt cấp nhất định) giúp bạn nhận thêm nhiều tài nguyên nâng cấp vườn hoa.",
		50
	))
	
	tips.append(GameTip.new(
		OFFLINE_WEATHER_ID,
		"Thời Tiết Thực Tế",
		"Thế giới trong game được đồng bộ hóa với thời tiết và thời gian thực tế ngoài đời. " +
		"Nắng quá gắt có thể làm đất khô cằn và hoa bị héo, trong khi mưa quá lớn có thể khiến cây bị úng nước. " +
		"Hãy chú ý theo dõi các thông báo cảnh báo thời tiết để chăm sóc và bảo vệ vườn hoa của mình một cách kịp thời nhé!",
		60
	))
	
	return tips
