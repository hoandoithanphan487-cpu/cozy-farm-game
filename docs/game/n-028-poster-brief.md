# Studio task: N-028《溪谷新芽》温馨游戏海报

Player outcome:
- 玩家在第一眼感受到《溪谷新芽》温暖、可亲、可以慢慢经营生活的气质，并能清楚识别游戏名称。

Current context:
- Product Owner 提供一张竖版独立游戏海报作为设计语言参考。
- 项目已经验收角色、建筑与运行时美术，可作为世界观和视觉身份依据。

Assumptions:
- 本次交付为项目营销/展示用单张竖版位图海报，不直接接入游戏运行时。
- 参考图只提供复古印刷质感、信息层级、立体可爱场景与海报构图启发，不复制其角色、地图、标题字体、口号或品牌元素。

Department:
- 🎭 World & Content

Department quality owner:
- 🎭 `content`

Specialist owner:
- 🎨 `art`

Consulted:
- 🎬 `director`、✨ `ux`

Downstream reviewer:
- 🛡️ `quality`（跨部门，防止自我批准）

In scope:
- 生成一张竖版《溪谷新芽》游戏海报。
- 使用复古米色纸张、暖色日光、分层小型溪谷农场、木构建筑、溪流/水渠、作物与亲切角色群像。
- 标题必须准确出现一次：`溪谷新芽`。
- 突出温馨氛围与“耕种、建造、结识伙伴、让溪谷重新生长”的游戏想象。
- 画面必须纳入 N-009 已验收的全部 8 名主要人物：玩家、水工学徒、种源管理员、溪岸巡护员、涧麦婶、石灯、青砚、絮宁。
- 8 人均按主角规格清晰呈现；玩家位于视觉中心，人物之间有递种子、共同浇水、分享收获、讨论水渠或相互招呼等温暖互动，不做僵硬排队合影。

Out of scope:
- 不复制参考图的 `INDIE GAMES`、英文口号、角色队形、漂浮岛地图或任何品牌元素。
- 不修改 Swift、运行时 Assets、玩法、对白、存档、经济或地图拓扑。
- 不宣称正式发行物、商标定稿或平台认证。

Inputs and dependencies:
- Product Owner 当前会话请求与参考图：`/var/folders/23/f49kbv111135xh7bjzm26p140000gn/T/codex-clipboard-83a989a0-3bb8-457f-8fd6-92759cb754b2.png`
- N-003、N-009、N-013、N-014、N-015 均须为 `accepted / APPROVED`。
- 视觉资料：`docs/game/art-style-master-doc.md`、N-009 角色总览、N-013 建筑总览、N-014 猫店总览、N-019 真实 App 截图（仅作项目身份参考）。

Deliverables:
- `artifacts/marketing/n-028-poster/creek-sprout-cozy-poster-v01.png`
- `artifacts/marketing/n-028-poster/creek-sprout-cozy-poster-v02.png`（Product Owner 群像修订版，最终候选）
- 最终生成提示词与审核记录。

Acceptance criteria:
- Given 已批准的项目视觉身份，When 查看海报，Then 能识别木蜜/苔绿/雾蓝/铜橙色系、溪谷水工与农场生活元素。
- Given 参考图仅作设计语言参考，When 对照成品，Then 不出现其专有文字、角色、品牌、地图或可混淆复制的构图表达。
- Given 海报用于展示，When 以竖版整图查看，Then `溪谷新芽` 标题清晰、只出现一次，主体层级完整且无水印。
- Given Product Owner 要求温馨，When 查看人物表情、光线与场景，Then 氛围应友善、明亮、舒缓，不以战斗或冒险武器为视觉中心。
- Given 8 名主要人物均为主角，When 查看海报，Then 8 人全部出现、身份可辨、人物尺度接近，玩家位于构图中心且至少形成三组自然互动。

Required evidence:
- 最终 PNG 的尺寸/格式检查。
- 🎭 content 原创性、世界一致性与温馨氛围审查。
- 🛡️ quality 独立检查标题、构图、可读性、水印与文件完整性。

Required gates:
- 🎭 content department gate。
- 🛡️ quality downstream gate。
- Product Owner 视觉终审；在此之前任务保持 `active / PENDING`。

Originality check:
- 熟悉的目的：复古独立游戏海报的信息层级、中央场景与角色群像。
- 原创表达：仅使用《溪谷新芽》的名称、角色身份、木构水工溪谷、作物、猫店与暖湿生态语言重新设计。

Risks or open choices:
- 图像生成可能出现中文标题错字；若发生，只对标题准确性进行定点迭代。
- 海报仅获得部门门禁后交 Product Owner 终审，不自动登记为 `accepted`。
