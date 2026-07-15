"""内容安全审核（M6）：硬性拦截 + 敏感分级。

分层原则：审核只作用于**用户输入的自然语言文本**（起卦问题 / 追问），
不触碰盘面数据、不参与术数计算，也不改写 LLM 输出（软性约束见 prompt.py）。

三级处置：
- ``block``   高危类（自伤轻生、伤害他人 / 暴力、违法制毒制爆等）→ 直接拒绝，
              不调用 LLM，返回本地化安全提示（自伤类附危机求助信息）。
- ``caution`` 敏感类（重病绝症、诉讼判决、投资必涨等）→ 放行，但向提示词注入
              更强的免责与"去绝对化"约束。
- ``allow``   其余正常放行。

中英双语：关键词表与文案均分中 / 英；未显式传入语言时按文本是否含 CJK 自动判定。
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Literal, Optional

Action = Literal["allow", "caution", "block"]
Locale = Literal["zh", "en"]

# 中日韩统一表意文字区间，用于自动语言判定。
_CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def normalize_locale(raw: Optional[str], text: str = "") -> Locale:
    """把客户端传入的 locale（如 ``zh-Hans`` / ``en-US``）或文本归一到 zh / en。"""

    if raw:
        low = raw.strip().lower()
        if low.startswith("zh") or low.startswith("cmn") or low.startswith("yue"):
            return "zh"
        if low.startswith("en"):
            return "en"
    return "zh" if _CJK_RE.search(text) else "en"


@dataclass(frozen=True)
class _Category:
    key: str
    action: Action
    zh_terms: tuple[str, ...]
    en_terms: tuple[str, ...] = field(default_factory=tuple)

    def matches(self, zh_text: str, en_text: str) -> bool:
        for t in self.zh_terms:
            if t in zh_text:
                return True
        for t in self.en_terms:
            # 英文按单词边界匹配，避免 "assist" 命中 "sis" 之类误伤。
            if re.search(r"(?<![a-z])" + re.escape(t) + r"(?![a-z])", en_text):
                return True
        return False


# 顺序即优先级：越靠前越严重，命中即返回。
_CATEGORIES: tuple[_Category, ...] = (
    _Category(
        key="self_harm",
        action="block",
        zh_terms=(
            "自杀", "轻生", "自尽", "自缢", "想死", "不想活", "活不下去",
            "结束生命", "结束自己", "了结自己", "自残", "自伤", "割腕", "跳楼",
        ),
        en_terms=(
            "suicide", "kill myself", "killing myself", "end my life",
            "end it all", "self-harm", "self harm", "harm myself", "hurt myself",
            "cut myself", "want to die", "wanna die", "take my own life",
        ),
    ),
    _Category(
        key="harm_others",
        action="block",
        zh_terms=(
            "杀人", "杀死", "弄死", "害死", "报复社会", "伤害他人", "伤害别人",
            "打死", "捅死", "投毒", "下毒", "绑架", "拐卖", "强奸", "施暴",
        ),
        en_terms=(
            "kill him", "kill her", "kill them", "kill someone", "murder",
            "hurt someone", "poison someone", "kidnap", "assault someone", "rape",
        ),
    ),
    _Category(
        key="illegal",
        action="block",
        zh_terms=(
            "制造炸弹", "做炸弹", "制毒", "制造毒品", "贩毒", "制枪", "造枪",
            "买枪", "洗钱", "诈骗别人", "怎么偷", "如何偷", "越狱逃跑",
        ),
        en_terms=(
            "make a bomb", "build a bomb", "make meth", "make drugs",
            "sell drugs", "buy a gun illegally", "launder money", "how to steal",
        ),
    ),
    _Category(
        key="minor_sexual",
        action="block",
        zh_terms=("未成年", "幼女", "萝莉", "儿童色情"),
        en_terms=("child porn", "underage sex", "minor sex"),
    ),
    _Category(
        key="medical",
        action="caution",
        zh_terms=(
            "癌", "绝症", "肿瘤", "能不能治好", "能治好吗", "还能活多久",
            "能活多久", "确诊", "诊断", "病能好", "手术能成功", "白血病", "尿毒症",
        ),
        en_terms=(
            "cancer", "terminal illness", "tumor", "how long to live",
            "will i survive", "diagnos", "leukemia", "cure my disease",
        ),
    ),
    _Category(
        key="legal",
        action="caution",
        zh_terms=("官司", "诉讼", "打官司", "判几年", "会不会坐牢", "会被判", "会不会输官司"),
        en_terms=("lawsuit", "will i win the case", "go to jail", "prison sentence", "court case"),
    ),
    _Category(
        key="financial",
        action="caution",
        zh_terms=(
            "买哪只股票", "哪只股票", "会不会涨", "一定涨", "梭哈", "全仓",
            "买彩票", "中奖号码", "买什么币", "会不会暴富", "投资一定赚",
        ),
        en_terms=(
            "which stock", "will it go up", "lottery number", "get rich quick",
            "should i go all in", "which coin to buy", "guaranteed profit",
        ),
    ),
)


@dataclass(frozen=True)
class ModerationResult:
    action: Action
    category: Optional[str] = None
    # block 时的本地化拒绝文案；caution / allow 时为 None。
    message: Optional[str] = None
    # caution 时注入提示词的额外安全约束；block / allow 时为 None。
    caution_note: Optional[str] = None

    @property
    def blocked(self) -> bool:
        return self.action == "block"


# ---- 本地化文案 ----

_BLOCK_MESSAGES: dict[str, dict[Locale, str]] = {
    "self_harm": {
        "zh": (
            "很抱歉，本应用无法就自我伤害或轻生相关的问题提供占卜解读。"
            "你的感受很重要，你并不孤单。如果你正处于痛苦或危险中，请立即联系专业帮助："
            "全国心理援助热线 12356；北京心理危机研究与干预中心 010-82951332；"
            "或拨打当地紧急电话。愿意的话，也请和信任的人聊一聊。"
        ),
        "en": (
            "I'm sorry, but this app can't provide a divination reading for questions "
            "involving self-harm or suicide. Your feelings matter and you are not alone. "
            "If you're in distress or danger, please reach out for help right now — in the "
            "US call or text 988 (Suicide & Crisis Lifeline), or contact your local "
            "emergency services. Please consider talking to someone you trust."
        ),
    },
    "harm_others": {
        "zh": "本应用无法就伤害他人、暴力或违法犯罪相关的问题提供解读。如遇危险，请联系当地警方或紧急服务。",
        "en": (
            "This app can't provide a reading for questions involving harming others, "
            "violence, or criminal activity. If someone is in danger, please contact your "
            "local police or emergency services."
        ),
    },
    "illegal": {
        "zh": "本应用无法就违法或危险行为相关的问题提供解读。请遵守当地法律法规。",
        "en": (
            "This app can't provide a reading for questions involving illegal or dangerous "
            "activities. Please comply with your local laws and regulations."
        ),
    },
    "minor_sexual": {
        "zh": "本应用严禁涉及未成年人的不当内容，无法就此提供任何解读。",
        "en": (
            "This app strictly prohibits any content sexualizing minors and cannot provide "
            "any reading on this topic."
        ),
    },
}

_CAUTION_NOTES: dict[str, dict[Locale, str]] = {
    "medical": {
        "zh": (
            "【安全提示】本次所问涉及健康 / 疾病。解读只能作为传统文化层面的心理参考，"
            "严禁给出任何医学诊断、病情判断、预后或治疗建议，也不得断言生死、能否治愈或存活时长。"
            "必须明确建议：请及时就医、遵从执业医师的专业诊断与治疗。"
        ),
        "en": (
            "[Safety note] This question involves health / illness. The reading may only "
            "serve as cultural, psychological reference. Do NOT give any medical diagnosis, "
            "prognosis, or treatment advice, and never assert life, death, curability, or "
            "survival time. You MUST advise seeing a licensed physician promptly."
        ),
    },
    "legal": {
        "zh": (
            "【安全提示】本次所问涉及法律 / 诉讼。严禁断言判决结果、刑期或胜诉败诉，"
            "不得替代律师意见。必须建议咨询执业律师并以司法机关裁决为准。"
        ),
        "en": (
            "[Safety note] This question involves legal / litigation matters. Do NOT assert "
            "verdicts, sentences, or who will win. This is no substitute for a lawyer. You "
            "MUST advise consulting a licensed attorney and deferring to the courts."
        ),
    },
    "financial": {
        "zh": (
            "【安全提示】本次所问涉及投资 / 财务。严禁给出任何具体投资、买卖、标的建议，"
            "或必赚、必涨、稳赚之类的确定性判断，不得诱导下注或加仓。必须提示投资有风险、"
            "决策需自行谨慎判断并咨询持牌专业人士。"
        ),
        "en": (
            "[Safety note] This question involves investing / finance. Do NOT give any "
            "specific investment, trading, or asset picks, nor any 'guaranteed gain/rise' "
            "claims, and do not encourage betting or increasing positions. You MUST warn "
            "that investing carries risk and advise consulting a licensed professional."
        ),
    },
}


def moderate(text: Optional[str], locale: Optional[str] = None) -> ModerationResult:
    """审核一段用户输入文本，返回处置结果。

    ``text`` 为空 / None 时视为放行（例如未填问题的起卦仍可解读盘面）。
    """

    if not text or not text.strip():
        return ModerationResult(action="allow")

    loc = normalize_locale(locale, text)
    zh_text = text
    en_text = text.lower()

    for cat in _CATEGORIES:
        if cat.matches(zh_text, en_text):
            if cat.action == "block":
                msg = _BLOCK_MESSAGES.get(cat.key, {}).get(loc)
                return ModerationResult(action="block", category=cat.key, message=msg)
            if cat.action == "caution":
                note = _CAUTION_NOTES.get(cat.key, {}).get(loc)
                return ModerationResult(
                    action="caution", category=cat.key, caution_note=note
                )

    return ModerationResult(action="allow")
