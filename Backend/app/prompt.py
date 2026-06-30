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

【多轮追问】用户后续追问时，仍只能基于同一盘面延展解读，不重新起卦；语气亲切、就事论事。
"""

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

    return "\n".join(parts)


def build_interpret_messages(
    board: DivinationBoard, grounding: str | None = None
) -> list[dict]:
    """首轮解读的消息序列（可选附经文参考 grounding）。"""

    board_text = render_board(board)
    if grounding:
        board_text = board_text + "\n\n" + grounding
    user_prompt = (
        "以下是已排好的六爻盘面，请据此给出解读：\n\n"
        f"{board_text}\n\n请按规定结构给出首轮断语。"
    )
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ]


def build_chat_messages(
    board: DivinationBoard, history: list[dict], grounding: str | None = None
) -> list[dict]:
    """多轮追问：system + 盘面（作为 system 上下文，可选附经文参考）+ 历史对话。"""

    board_text = render_board(board)
    if grounding:
        board_text = board_text + "\n\n" + grounding
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "system",
            "content": "本次对话固定基于以下盘面（不得重新起卦或换卦）：\n\n" + board_text,
        },
        *history,
    ]
