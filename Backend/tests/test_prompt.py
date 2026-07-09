from app.models import DivinationBoard
from app.prompt import (
    build_chat_messages,
    build_interpret_messages,
    render_board,
    system_prompt_for,
    MEIHUA_SYSTEM_PROMPT,
    SYSTEM_PROMPT,
)


def test_board_parses_from_engine_fixture(board_json):
    board = DivinationBoard.model_validate(board_json)
    assert board.primary.name == "山火贲"
    assert board.changed is not None
    assert board.movingPositions == [1, 4]


def test_render_board_includes_key_facts(board_json):
    board = DivinationBoard.model_validate(board_json)
    text = render_board(board)
    # 本卦 / 变卦 / 动爻 / 用神 / 旬空 等关键事实都应出现。
    assert "山火贲" in text
    assert "火山旅" in text
    assert "动爻：初爻、四爻" in text
    assert "用神" in text
    assert "旬空" in text
    # 六神仅本卦展示。
    assert "朱雀" in text


def test_interpret_messages_shape(board_json):
    board = DivinationBoard.model_validate(board_json)
    msgs = build_interpret_messages(board)
    assert msgs[0]["role"] == "system"
    assert msgs[0]["content"] == SYSTEM_PROMPT
    assert msgs[-1]["role"] == "user"
    assert "山火贲" in msgs[-1]["content"]


def test_chat_messages_carry_board_and_history(board_json):
    board = DivinationBoard.model_validate(board_json)
    history = [
        {"role": "user", "content": "大概什么时候应？"},
    ]
    msgs = build_chat_messages(board, history)
    assert msgs[0]["role"] == "system"
    assert msgs[1]["role"] == "system"
    assert "不得重新起卦" in msgs[1]["content"]
    assert msgs[-1] == history[-1]


def test_interpret_messages_inject_grounding(board_json):
    board = DivinationBoard.model_validate(board_json)
    grounding = "【经文参考】（仅供引用，不得改动盘面）\n- 《山火贲》卦辞：亨。"
    msgs = build_interpret_messages(board, grounding)
    assert "经文参考" in msgs[-1]["content"]
    assert "《山火贲》卦辞" in msgs[-1]["content"]
    # 不传 grounding 时不应出现经文段落。
    plain = build_interpret_messages(board)
    assert "经文参考" not in plain[-1]["content"]


def test_chat_messages_inject_grounding(board_json):
    board = DivinationBoard.model_validate(board_json)
    grounding = "【经文参考】\n- 《火山旅》卦辞：小亨，旅贞吉。"
    msgs = build_chat_messages(board, [{"role": "user", "content": "问"}], grounding)
    assert "经文参考" in msgs[1]["content"]


def test_system_prompt_has_safety_soft_constraints():
    # 软性约束：安全合规 + 语言指令始终写入 system。
    assert "安全与合规" in SYSTEM_PROMPT
    assert "作答语言" in SYSTEM_PROMPT


def test_interpret_injects_caution_and_language(board_json):
    board = DivinationBoard.model_validate(board_json)
    msgs = build_interpret_messages(
        board, locale="en", caution_note="[Safety note] medical caution"
    )
    content = msgs[-1]["content"]
    assert "[Safety note] medical caution" in content
    assert "respond entirely in English" in content


def test_chat_injects_caution_and_language(board_json):
    board = DivinationBoard.model_validate(board_json)
    msgs = build_chat_messages(
        board,
        [{"role": "user", "content": "问"}],
        locale="zh-Hans",
        caution_note="【安全提示】就医",
    )
    assert "【安全提示】就医" in msgs[1]["content"]
    assert "简体中文" in msgs[1]["content"]


# --- 梅花易数（体用生克）---

def test_meihua_board_parses_and_carries_view(board_meihua_json):
    board = DivinationBoard.model_validate(board_meihua_json)
    assert board.version == "1.1.0"
    assert board.method == "梅花"
    assert board.meihua is not None
    assert len(board.meihua.relations) == 4
    # 六爻字段仍照常存在（兼容）。
    assert board.primary.lines and board.primary.lines[0].sixRelative


def test_render_board_includes_meihua_section(board_meihua_json):
    board = DivinationBoard.model_validate(board_meihua_json)
    text = render_board(board)
    assert "【梅花体用】" in text
    assert "体卦" in text and "用卦" in text
    assert "互卦" in text
    # 生克关系逐条渲染。
    assert "生体" in text or "克体" in text or "比和" in text


def test_meihua_switches_system_prompt(board_meihua_json, board_json):
    meihua = DivinationBoard.model_validate(board_meihua_json)
    liuyao = DivinationBoard.model_validate(board_json)
    assert system_prompt_for(meihua) == MEIHUA_SYSTEM_PROMPT
    assert system_prompt_for(liuyao) == SYSTEM_PROMPT
    # 首轮解读消息按 method 选择体用口径。
    msgs = build_interpret_messages(meihua)
    assert msgs[0]["content"] == MEIHUA_SYSTEM_PROMPT
    assert "体用" in msgs[0]["content"]
    assert "梅花盘面" in msgs[-1]["content"]


def test_meihua_system_prompt_has_safety():
    assert "安全与合规" in MEIHUA_SYSTEM_PROMPT
    assert "作答语言" in MEIHUA_SYSTEM_PROMPT
