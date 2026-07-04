"""周易经文语料（公有领域）的加载与文档化。

`data/zhouyi.json` 由 `scripts/build_corpus.py` 生成并入库，是检索语料的权威来源，
以排盘引擎的卦名（如「山火贲」）为主键。本模块只读取、不做术数计算。
"""

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

_DATA = Path(__file__).parent / "data" / "zhouyi.json"

_POSITION_NAMES = ["初", "二", "三", "四", "五", "上"]


@dataclass(frozen=True)
class Document:
    """一条可检索的经文片段。"""

    hexagram_name: str          # 引擎卦名（检索主键），如「山火贲」
    hexagram_short: str         # 通行短卦名，如「贲」
    doc_type: str               # judgment | line | tuan
    line_position: int | None   # doc_type=line 时为 1..6
    content: str

    @property
    def ref(self) -> str:
        name = self.hexagram_name.decode() if isinstance(self.hexagram_name, bytes) else self.hexagram_name
        doc = self.doc_type.decode() if isinstance(self.doc_type, bytes) else self.doc_type
        if doc == "judgment":
            return f"《{name}》卦辞"
        if doc == "tuan":
            return f"《{name}》彖传"
        if self.line_position is not None:
            pos = int(self.line_position) - 1
            return f"《{name}》{_POSITION_NAMES[pos]}爻"
        return f"《{name}》{doc}"


@lru_cache
def load_corpus() -> list[dict]:
    return json.loads(_DATA.read_text(encoding="utf-8"))


@lru_cache
def corpus_by_name() -> dict[str, dict]:
    return {h["name"]: h for h in load_corpus()}


def build_documents(include_tuan: bool = True) -> list[Document]:
    """把语料展开成检索文档：每卦 1 卦辞 + 6 爻辞（+ 可选彖辞）。"""

    docs: list[Document] = []
    for h in load_corpus():
        name, short = h["name"], h["short"]
        docs.append(
            Document(name, short, "judgment", None, f"《{name}》卦辞：{h['judgment']}")
        )
        for pos in range(1, 7):
            text = h["lines"][str(pos)]
            docs.append(Document(name, short, "line", pos, f"《{name}》{text}"))
        if include_tuan and h.get("tuan"):
            docs.append(Document(name, short, "tuan", None, f"《{name}》{h['tuan']}"))
    return docs
