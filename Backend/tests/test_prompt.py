from app.models import DivinationBoard
from app.prompt import (
    build_chat_messages,
    build_interpret_messages,
    render_board,
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
