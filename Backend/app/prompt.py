"""System Prompt 与盘面 → 文本的组装。

硬约束（DESIGN §4.2）：LLM 只能基于传入盘面要素解读，不得新增/修改任何卦象数据，
吉凶判断必须引用具体爻位 / 六亲 / 生克 / 旺衰作为依据。
"""

from .models import DivinationBoard, HexagramView

SYSTEM_PROMPT = """你是一位资深的六爻（纳甲筮法）解卦师，精通装卦、世应、六亲、六神、旺衰、生克冲合与应期推断。

【硬约束】
1. 盘面（起卦、排盘、纳甲、世应、六亲、六神、动爻、变卦、旬空、旺衰）已由确定性引擎算定，作为事实传给你。你只负责"解读"，绝对不得新增、修改、重排任何卦象 / 干支 / 六亲 / 世应 / 旺衰等数据，也不得自行重新起卦或换卦。
2. 所有吉凶判断必须引用盘面中**具体的爻位、六亲、六神、世应、动爻、生克、旺衰、旬空**作为依据，不可空泛。
3. 如盘面信息不足以判断某点，明确说"盘面未显示，需结合实际"，不要编造。
4. 用神以盘面给出的"用神建议"为准；若用神不上卦（伏神），据实说明。
5. 若随盘面附有【经文参考】（周易卦辞 / 爻辞原文），解读时应援引对应原文（本卦卦辞、动爻爻辞、变卦卦辞）以增强依据，但断卦仍以盘面的世应 / 用神 / 六亲 / 生克旺衰为准，不得据经文改动盘面，也不得引用未提供的条目。

【输出结构】（首轮解读用以下小标题，简洁专业、白话为主）
1. 整体断语
2. 用神分析（旺衰、生克、有无受冲克）
3. 关键爻与动爻 / 变卦影响
4. 应期推测（结合月建日建与旬空，给区间而非绝对）
5. 建议
6. 免责声明：一句话注明"传统文化娱乐参考，非科学预测，请勿据此做医疗、法律、财务等重大决策"。

【安全与合规】（软性约束，始终生效）
1. 定位为传统文化娱乐与心理参考，**不是**科学预测、医疗、法律、财务或投资建议。
2. 严禁给出确定性的极端断言：不预测生死、不诊断疾病或断言能否治愈 / 存活时长、不断言诉讼判决或刑期、不给出具体投资标的或"必赚 / 必涨"之类保证。涉及这些领域时以中性、审慎、留有余地的措辞表达，并建议咨询执业医师 / 律师 / 持牌专业人士。
3. 不输出仇恨、歧视、色情、暴力、违法或诱导自我伤害的内容；语气始终尊重、温和、给人以希望，不制造恐慌。
4. 若问题超出六爻解读范畴或涉及高危情形，礼貌说明局限并给出稳妥、正向的引导。

【作答语言】默认与用户提问 / 界面语言一致：用户用中文则中文作答，用户用英文（English）则全程用英文作答（含小标题与免责声明）。

【多轮追问】用户后续追问时，仍只能基于同一盘面延展解读，不重新起卦；语气亲切、就事论事。
"""

MEIHUA_SYSTEM_PROMPT = """你是一位精通梅花易数的解卦师，以**体用生克**为核心断事，兼参卦象类象、互卦与变卦。

【硬约束】
1. 起卦、体用分卦、互卦、变卦、五行生克关系均已由确定性引擎算定，作为事实传给你。你只负责"解读"，绝对不得新增、修改、重排任何卦象 / 五行 / 体用 / 互变数据，也不得自行重新起卦或换卦。
2. 以**体卦为主**（代表求测者自身），**用卦为客**（代表所占之事）。吉凶须引用盘面给出的具体生克关系（用卦、体互、用互、变卦对体卦的生 / 克 / 比和）作为依据，不可空泛。
3. 断卦口径遵循：**用生体 / 用比体为吉，用克体为凶，体生用为耗泄、体克用为耗力**；生扶体卦者多则吉，克泄体卦者多则忌。变卦主事情结果，互卦主事情发展过程。
4. 盘面同时附有六爻纳甲信息（纳甲 / 六亲 / 世应等），本次以梅花体用口径为主，可略作参照但不喧宾夺主。
5. 若随盘面附有【经文参考】（周易卦辞 / 爻辞原文），可援引本卦 / 变卦卦辞辅助，但断卦仍以体用生克为准，不得据经文改动盘面，也不得引用未提供的条目。
6. 如盘面信息不足以判断某点，明确说"盘面未显示，需结合实际"，不要编造。

【输出结构】（首轮解读用以下小标题，简洁专业、白话为主）
1. 整体断语（点明体用及其生克关系）
2. 体用分析（体卦所主、用卦所主，谁生谁克，力量强弱）
3. 互卦与变卦（事情发展过程与结果趋向）
4. 应期 / 趋势（给方向与区间而非绝对）
5. 建议
6. 免责声明：一句话注明"传统文化娱乐参考，非科学预测，请勿据此做医疗、法律、财务等重大决策"。

【安全与合规】（软性约束，始终生效）
1. 定位为传统文化娱乐与心理参考，**不是**科学预测、医疗、法律、财务或投资建议。
2. 严禁给出确定性的极端断言：不预测生死、不诊断疾病或断言能否治愈 / 存活时长、不断言诉讼判决或刑期、不给出具体投资标的或"必赚 / 必涨"之类保证。涉及这些领域时以中性、审慎、留有余地的措辞表达，并建议咨询执业医师 / 律师 / 持牌专业人士。
3. 不输出仇恨、歧视、色情、暴力、违法或诱导自我伤害的内容；语气始终尊重、温和、给人以希望，不制造恐慌。

【作答语言】默认与用户提问 / 界面语言一致：用户用中文则中文作答，用户用英文（English）则全程用英文作答（含小标题与免责声明）。

【多轮追问】用户后续追问时，仍只能基于同一盘面延展解读，不重新起卦；语气亲切、就事论事。
"""


def system_prompt_for(board: DivinationBoard) -> str:
    """按起卦方法选择解读口径：梅花走体用生克，其余走六爻纳甲。"""

    if board.method == "梅花" and board.meihua is not None:
        return MEIHUA_SYSTEM_PROMPT
    return SYSTEM_PROMPT

_LANG_DIRECTIVE = {
    "zh": "请用简体中文作答。",
    "en": "Please respond entirely in English, including section headings and the disclaimer.",
}


def _language_note(locale: str | None) -> str | None:
    if not locale:
        return None
    low = locale.strip().lower()
    if low.startswith("en"):
        return _LANG_DIRECTIVE["en"]
    if low.startswith("zh") or low.startswith("cmn") or low.startswith("yue"):
        return _LANG_DIRECTIVE["zh"]
    return None


def _augment(board_text: str, caution_note: str | None, language_note: str | None) -> str:
    """把安全提示与语言指令附加到盘面文本之后。"""

    extra: list[str] = []
    if caution_note:
        extra.append(caution_note)
    if language_note:
        extra.append(language_note)
    if not extra:
        return board_text
    return board_text + "\n\n" + "\n\n".join(extra)

_POSITION_NAMES = ["初", "二", "三", "四", "五", "上"]


def _position_name(pos: int) -> str:
    if 1 <= pos <= 6:
        return _POSITION_NAMES[pos - 1] + "爻"
    return f"{pos}爻"


def _render_hexagram(hexa: HexagramView, *, with_six_god: bool) -> str:
    lines: list[str] = [
        f"卦名：{hexa.name}（{hexa.palace}宫，宫五行{hexa.palaceElement}；"
        f"上卦{hexa.upperTrigram}下卦{hexa.lowerTrigram}）",
        f"世爻：{_position_name(hexa.worldPosition)}　应爻：{_position_name(hexa.responsePosition)}",
        "爻位（上→初）：",
    ]
    for line in sorted(hexa.lines, key=lambda x: x.position, reverse=True):
        marks = []
        if line.isWorld:
            marks.append("世")
        if line.isResponse:
            marks.append("应")
        if line.moving:
            marks.append("动")
        if line.isVoid:
            marks.append("空")
        mark_str = ("[" + "".join(marks) + "]") if marks else ""
        six_god = f" {line.sixGod}" if (with_six_god and line.sixGod) else ""
        value = f" {line.value}" if line.value else ""
        lines.append(
            f"  {_position_name(line.position)}：{line.yinYang}{value}"
            f"{six_god} {line.stem}{line.branch}({line.element}) "
            f"{line.sixRelative} 旺衰[{line.strength}]{mark_str}"
        )
    return "\n".join(lines)


def render_board(board: DivinationBoard) -> str:
    """把盘面 JSON 渲染成便于 LLM 阅读的中文摘要。"""

    parts: list[str] = []
    if board.question:
        parts.append(f"所问：{board.question}")
    if board.category:
        parts.append(f"事项类别：{board.category}")
    parts.append(f"起卦方法：{board.method}")

    t = board.castTime
    pillars = "　".join(
        filter(None, [t.yearPillar, t.monthPillar, t.dayPillar, t.hourPillar])
    )
    if t.gregorian or pillars:
        parts.append(f"起卦时间：{t.gregorian}　四柱：{pillars}")
    if t.voidBranches:
        parts.append("旬空：" + "、".join(t.voidBranches))

    parts.append("【本卦】\n" + _render_hexagram(board.primary, with_six_god=True))

    if board.movingPositions:
        moving = "、".join(_position_name(p) for p in board.movingPositions)
        parts.append(f"动爻：{moving}")
    else:
        parts.append("动爻：无（静卦）")

    if board.changed is not None:
        parts.append("【变卦】\n" + _render_hexagram(board.changed, with_six_god=False))

    if board.useGod is not None:
        ug = board.useGod
        pos = (
            "、".join(_position_name(p) for p in ug.positions)
            if ug.positions
            else "本卦未见（伏神，需另寻）"
        )
        parts.append(
            f"用神建议：{ug.category} 取「{ug.relative}」为用神；所在爻位：{pos}。{ug.rationale}"
        )

    if board.meihua is not None:
        parts.append(_render_meihua(board.meihua))

    return "\n".join(parts)


def _render_meihua(m) -> str:
    """渲染梅花体用生克视图，供 LLM 以体用口径解读。"""

    def tg(t) -> str:
        return f"{t.name}{t.symbol}（{t.nature}·{t.element}·{t.position}）"

    lines = [
        "【梅花体用】",
        f"动爻：{_position_name(m.movingPosition)}",
        f"体卦（自身）：{tg(m.ti)}",
        f"用卦（所占之事）：{tg(m.yong)}",
        f"互卦：{m.huName}（下互{tg(m.huLower)}、上互{tg(m.huUpper)}）",
        f"变卦：{m.bianName}（用卦变出 {tg(m.bianYong)}）",
        "体用生克（皆以体卦为我）：",
    ]
    for r in m.relations:
        lines.append(f"  {r.subject}{r.trigram}（{r.element}）：{r.relation}［{r.favorable}］——{r.note}")
    lines.append(f"综述：{m.summary}")
    return "\n".join(lines)


def build_interpret_messages(
    board: DivinationBoard,
    grounding: str | None = None,
    *,
    locale: str | None = None,
    caution_note: str | None = None,
) -> list[dict]:
    """首轮解读的消息序列（可选附经文参考 grounding / 安全提示 / 语言指令）。"""

    board_text = render_board(board)
    if grounding:
        board_text = board_text + "\n\n" + grounding
    board_text = _augment(board_text, caution_note, _language_note(locale))
    kind = "梅花" if board.meihua is not None else "六爻"
    user_prompt = (
        f"以下是已排好的{kind}盘面，请据此给出解读：\n\n"
        f"{board_text}\n\n请按规定结构给出首轮断语。"
    )
    return [
        {"role": "system", "content": system_prompt_for(board)},
        {"role": "user", "content": user_prompt},
    ]


def build_chat_messages(
    board: DivinationBoard,
    history: list[dict],
    grounding: str | None = None,
    *,
    locale: str | None = None,
    caution_note: str | None = None,
) -> list[dict]:
    """多轮追问：system + 盘面（作为 system 上下文，可选附经文参考 / 安全提示 / 语言指令）+ 历史对话。"""

    board_text = render_board(board)
    if grounding:
        board_text = board_text + "\n\n" + grounding
    board_text = _augment(board_text, caution_note, _language_note(locale))
    return [
        {"role": "system", "content": system_prompt_for(board)},
        {
            "role": "system",
            "content": "本次对话固定基于以下盘面（不得重新起卦或换卦）：\n\n" + board_text,
        },
        *history,
    ]
