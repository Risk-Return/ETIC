"""请求/响应模型。

盘面模型镜像 `DivinationEngine` 冻结的 `DivinationBoard` 契约（schema 1.0.0）。
后端只读消费盘面，**不做任何术数计算、不修改盘面数据**。
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field


class CastTimeInfo(BaseModel):
    gregorian: str = ""
    yearPillar: str = ""
    monthPillar: str = ""
    dayPillar: str = ""
    hourPillar: str = ""
    voidBranches: list[str] = Field(default_factory=list)


class LineView(BaseModel):
    position: int
    yinYang: str
    value: Optional[str] = None
    moving: bool = False
    stem: str = ""
    branch: str = ""
    element: str = ""
    sixRelative: str = ""
    sixGod: Optional[str] = None
    isWorld: bool = False
    isResponse: bool = False
    isVoid: bool = False
    strength: str = ""


class HexagramView(BaseModel):
    name: str
    code: int = 0
    upperTrigram: str = ""
    lowerTrigram: str = ""
    palace: str = ""
    palaceElement: str = ""
    worldPosition: int = 0
    responsePosition: int = 0
    lines: list[LineView] = Field(default_factory=list)


class UseGodSuggestion(BaseModel):
    category: str = ""
    relative: str = ""
    rationale: str = ""
    positions: list[int] = Field(default_factory=list)


class DivinationBoard(BaseModel):
    version: str = "1.0.0"
    method: str = ""
    question: Optional[str] = None
    category: Optional[str] = None
    castTime: CastTimeInfo = Field(default_factory=CastTimeInfo)
    movingPositions: list[int] = Field(default_factory=list)
    primary: HexagramView
    changed: Optional[HexagramView] = None
    useGod: Optional[UseGodSuggestion] = None


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class InterpretRequest(BaseModel):
    """首轮解读：仅盘面（+ 盘面里自带的问题/类别）。"""

    board: DivinationBoard
    # 客户端界面语言（如 zh-Hans / en）。用于内容审核拒绝文案与解读作答语言；
    # 缺省时后端按文本是否含中日韩文字自动判定。
    locale: Optional[str] = None


class ChatRequest(BaseModel):
    """多轮追问：同一盘面上下文 + 历史对话。"""

    board: DivinationBoard
    messages: list[ChatMessage] = Field(default_factory=list)
    # 同 InterpretRequest.locale。
    locale: Optional[str] = None


class GroundingRequest(BaseModel):
    """经文检索：仅盘面（供客户端展示「经文参考」，与解读流分离）。"""

    board: DivinationBoard


class GroundingItem(BaseModel):
    """一条可展示的经文片段。与 rag.corpus.Document 对齐，供 iOS 渲染卡片。"""

    ref: str                        # 出处，如「《山火贲》卦辞」
    hexagramName: str               # 引擎卦名
    hexagramShort: str              # 通行短卦名
    docType: str                    # judgment | line | tuan
    linePosition: Optional[int] = None  # docType=line 时为 1..6
    content: str


class GroundingResponse(BaseModel):
    """经文检索结果。rag 关闭或库不可达时 items 为空（优雅退化）。"""

    enabled: bool = False
    items: list[GroundingItem] = Field(default_factory=list)
