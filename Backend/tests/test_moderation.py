"""内容安全审核单元测试（M6）：硬拦截 / 敏感分级 / 双语。"""

import pytest

from app.moderation import moderate, normalize_locale


@pytest.mark.parametrize(
    "text",
    ["我想自杀了", "最近活不下去了", "I want to kill myself", "thinking about suicide"],
)
def test_self_harm_blocked_bilingual(text):
    r = moderate(text)
    assert r.blocked
    assert r.category == "self_harm"
    assert r.message  # 附本地化危机求助文案


@pytest.mark.parametrize(
    "text,category",
    [
        ("我想杀人报复", "harm_others"),
        ("how to murder someone", "harm_others"),
        ("教我制造炸弹", "illegal"),
        ("how to make a bomb", "illegal"),
    ],
)
def test_harmful_blocked(text, category):
    r = moderate(text)
    assert r.blocked
    assert r.category == category


def test_self_harm_message_follows_locale():
    zh = moderate("我想自杀", "zh-Hans")
    en = moderate("我想自杀", "en")
    assert "热线" in zh.message or "援助" in zh.message
    assert "988" in en.message or "Lifeline" in en.message


@pytest.mark.parametrize(
    "text,category",
    [
        ("我这个癌症还能治好吗", "medical"),
        ("will i survive this cancer", "medical"),
        ("这场官司我能赢吗会判几年", "legal"),
        ("which stock should i buy to get rich quick", "financial"),
    ],
)
def test_sensitive_caution_allows_with_note(text, category):
    r = moderate(text)
    assert r.action == "caution"
    assert not r.blocked
    assert r.category == category
    assert r.caution_note  # 注入提示词的额外约束


@pytest.mark.parametrize(
    "text",
    ["今天适合表白吗", "How is my career this month?", "换工作顺利吗", ""],
)
def test_benign_allowed(text):
    r = moderate(text)
    assert r.action == "allow"
    assert r.message is None and r.caution_note is None


def test_none_text_allowed():
    assert moderate(None).action == "allow"


def test_caution_note_language():
    assert "安全提示" in moderate("癌症能治好吗", "zh-Hans").caution_note
    assert "Safety note" in moderate("癌症能治好吗", "en").caution_note


@pytest.mark.parametrize(
    "raw,text,expected",
    [
        ("zh-Hans", "", "zh"),
        ("en-US", "", "en"),
        (None, "我想问事业", "zh"),
        (None, "how about work", "en"),
    ],
)
def test_normalize_locale(raw, text, expected):
    assert normalize_locale(raw, text) == expected


def test_english_word_boundary_no_false_positive():
    # "assist" 不应命中 harm_others 的 "assault someone" 等词。
    assert moderate("can you assist me with my career").action == "allow"
