import Foundation

// MARK: - 内置题库（固定 UUID，确保持久化后不重复添加）
enum BuiltInQuestions {
    static let bankID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static let bank = QuestionBank(
        id: bankID,
        name: "内置题库",
        version: "1.0",
        description: "涵盖地理、科学、历史、数学、艺术、体育六大分类，共 36 道题",
        questions: all,
        isBuiltIn: true,
        isEnabled: true
    )

    static let all: [Question] = geography + science + history + math + art + sports

    // MARK: 地理
    static let geography: [Question] = [
        Question(category: "地理", text: "中国的首都是哪里？",
                 options: ["上海", "北京", "广州", "成都"], correctIndex: 1),
        Question(category: "地理", text: "世界上面积最大的国家是？",
                 options: ["中国", "美国", "俄罗斯", "加拿大"], correctIndex: 2),
        Question(category: "地理", text: "尼罗河流经哪个大洲？",
                 options: ["亚洲", "欧洲", "非洲", "南美洲"], correctIndex: 2),
        Question(category: "地理", text: "世界上最高的山峰是？",
                 options: ["K2", "珠穆朗玛峰", "乔戈里峰", "洛子峰"], correctIndex: 1),
        Question(category: "地理", text: "澳大利亚的首都是？",
                 options: ["悉尼", "墨尔本", "布里斯班", "堪培拉"], correctIndex: 3),
        Question(category: "地理", text: "以下哪个国家不属于东南亚？",
                 options: ["泰国", "越南", "印度", "马来西亚"], correctIndex: 2),
    ]

    // MARK: 科学
    static let science: [Question] = [
        Question(category: "科学", text: "图中所示是哪个天体？",
                 image: QuestionImageData(type: .url, value: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/The_Earth_seen_from_Apollo_17.jpg/600px-The_Earth_seen_from_Apollo_17.jpg"),
                 options: ["火星", "金星", "地球", "木星"], correctIndex: 2),
        Question(category: "科学", text: "地球距离太阳大约多少公里？",
                 options: ["约 1.5 亿公里", "约 3.8 亿公里", "约 5.0 亿公里", "约 1.0 亿公里"], correctIndex: 0),
        Question(category: "科学", text: "水的化学式是？",
                 options: ["CO₂", "H₂O", "O₂", "NaCl"], correctIndex: 1),
        Question(category: "科学", text: "光在真空中的速度约为？",
                 options: ["30 万 km/s", "3 万 km/s", "300 万 km/s", "3000 km/s"], correctIndex: 0),
        Question(category: "科学", text: "DNA 的全称是？",
                 options: ["脱氧核糖核酸", "核糖核酸", "氨基酸", "腺嘌呤"], correctIndex: 0),
        Question(category: "科学", text: "以下哪种元素是金属？",
                 options: ["氧", "氮", "氢", "铁"], correctIndex: 3),
    ]

    // MARK: 历史
    static let history: [Question] = [
        Question(category: "历史", text: "中国四大发明不包括以下哪项？",
                 options: ["造纸术", "指南针", "望远镜", "印刷术"], correctIndex: 2),
        Question(category: "历史", text: "第一次世界大战爆发于哪一年？",
                 options: ["1904", "1914", "1918", "1939"], correctIndex: 1),
        Question(category: "历史", text: "秦始皇统一六国是在公元前哪一年？",
                 options: ["公元前 256 年", "公元前 221 年", "公元前 206 年", "公元前 180 年"], correctIndex: 1),
        Question(category: "历史", text: "文艺复兴运动最早发源于哪个国家？",
                 options: ["法国", "英国", "意大利", "德国"], correctIndex: 2),
        Question(category: "历史", text: "以下哪位人物与美国独立战争直接相关？",
                 options: ["拿破仑", "乔治·华盛顿", "俾斯麦", "克伦威尔"], correctIndex: 1),
        Question(category: "历史", text: "中国哪个朝代修建了长城的主体部分？",
                 options: ["汉朝", "唐朝", "明朝", "清朝"], correctIndex: 2),
    ]

    // MARK: 数学
    static let math: [Question] = [
        Question(category: "数学", text: "π（圆周率）约等于多少？",
                 options: ["3.1216", "3.1416", "3.1516", "3.1616"], correctIndex: 1),
        Question(category: "数学", text: "2 的 10 次方等于？",
                 options: ["512", "1024", "2048", "256"], correctIndex: 1),
        Question(category: "数学", text: "直角三角形中，斜边的平方等于？",
                 options: ["两直角边之积", "两直角边之和", "两直角边平方之和", "两直角边平方之差"], correctIndex: 2),
        Question(category: "数学", text: "以下哪个数是质数？",
                 options: ["9", "15", "21", "29"], correctIndex: 3),
        Question(category: "数学", text: "一个正六边形的内角和是多少度？",
                 options: ["360°", "540°", "720°", "900°"], correctIndex: 2),
        Question(category: "数学", text: "下列哪个是无理数？",
                 options: ["0.5", "√2", "1/3", "0.333..."], correctIndex: 1),
    ]

    // MARK: 艺术
    static let art: [Question] = [
        Question(category: "艺术", text: "以下哪幅是梵高的作品《星夜》？",
                 image: QuestionImageData(type: .url, value: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/600px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg"),
                 options: ["蒙娜丽莎", "星夜", "呐喊", "睡莲"], correctIndex: 1),
        Question(category: "艺术", text: "《蒙娜丽莎》是哪位艺术家的作品？",
                 options: ["米开朗基罗", "拉斐尔", "达芬奇", "波提切利"], correctIndex: 2),
        Question(category: "艺术", text: "贝多芬的第几号交响曲又称《命运》？",
                 options: ["第五号", "第六号", "第七号", "第九号"], correctIndex: 0),
        Question(category: "艺术", text: "中国传统绘画中文人画最注重的是？",
                 options: ["色彩浓烈", "写实造型", "意境与笔墨", "透视准确"], correctIndex: 2),
        Question(category: "艺术", text: "以下哪位是印象派代表画家？",
                 options: ["毕加索", "莫奈", "达利", "安迪·沃霍尔"], correctIndex: 1),
        Question(category: "艺术", text: "芭蕾舞起源于哪个国家？",
                 options: ["俄罗斯", "法国", "意大利", "西班牙"], correctIndex: 2),
    ]

    // MARK: 体育
    static let sports: [Question] = [
        Question(category: "体育", text: "FIFA 世界杯多少年举办一次？",
                 options: ["2 年", "3 年", "4 年", "5 年"], correctIndex: 2),
        Question(category: "体育", text: "奥运会五环旗的颜色不包括？",
                 options: ["红色", "紫色", "蓝色", "黑色"], correctIndex: 1),
        Question(category: "体育", text: "标准马拉松比赛的距离约为？",
                 options: ["21 公里", "42.195 公里", "50 公里", "38 公里"], correctIndex: 1),
        Question(category: "体育", text: "篮球比赛中，三分线外投篮得几分？",
                 options: ["1 分", "2 分", "3 分", "4 分"], correctIndex: 2),
        Question(category: "体育", text: "网球大满贯不包括以下哪个赛事？",
                 options: ["温布尔登", "法国公开赛", "美国公开赛", "世界杯"], correctIndex: 3),
        Question(category: "体育", text: "乒乓球是哪个国家的国球？",
                 options: ["日本", "韩国", "中国", "德国"], correctIndex: 2),
    ]
}
