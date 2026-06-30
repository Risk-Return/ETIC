"""生成 RAG 语料：周易六十四卦 卦辞 + 爻辞 + 彖辞（公有领域古籍原文）。

经文（卦辞 / 爻辞 / 彖传）属公有领域《周易》。本脚本将其与排盘引擎
`DivinationEngine` 使用的卦名（上卦+下卦命名，如「山火贲」）对齐，输出
`Backend/app/rag/data/zhouyi.json`，以引擎卦名为检索主键。

数据来源：公有领域《周易》经文，经文条目取自开源整理本
  https://raw.githubusercontent.com/Coaixy/ichingshifa/master/src/data/descriptions.ts
（仅取其中的公有领域经文 GUA_DESCRIPTIONS：0=卦辞，1-6=爻辞，7=彖辞；
 不含任何受版权保护的注解 / 断例）。

用法：python scripts/build_corpus.py
生成的 `app/rag/data/zhouyi.json` 已提交入库，是检索语料的权威来源；
本脚本仅用于复现 / 更新该文件。
"""
import json
import os
import re
import urllib.request

SOURCE_URL = (
    "https://raw.githubusercontent.com/Coaixy/ichingshifa/master/"
    "src/data/descriptions.ts"
)

# 引擎卦名（上卦×下卦）-> 王弼本通行短卦名（与经文条目对齐）。
# full 名取自 DivinationEngine/Data/HexagramTables.swift 的 nameTable。
FULL_TO_SHORT = {
    "乾为天": "乾", "天泽履": "履", "天火同人": "同人", "天雷无妄": "无妄",
    "天风姤": "姤", "天水讼": "讼", "天山遁": "遯", "天地否": "否",
    "泽天夬": "夬", "兑为泽": "兑", "泽火革": "革", "泽雷随": "随",
    "泽风大过": "大过", "泽水困": "困", "泽山咸": "咸", "泽地萃": "萃",
    "火天大有": "大有", "火泽睽": "睽", "离为火": "离", "火雷噬嗑": "噬嗑",
    "火风鼎": "鼎", "火水未济": "未济", "火山旅": "旅", "火地晋": "晋",
    "雷天大壮": "大壮", "雷泽归妹": "归妹", "雷火丰": "丰", "震为雷": "震",
    "雷风恒": "恒", "雷水解": "解", "雷山小过": "小过", "雷地豫": "豫",
    "风天小畜": "小畜", "风泽中孚": "中孚", "风火家人": "家人", "风雷益": "益",
    "巽为风": "巽", "风水涣": "涣", "风山渐": "渐", "风地观": "观",
    "水天需": "需", "水泽节": "节", "水火既济": "既济", "水雷屯": "屯",
    "水风井": "井", "坎为水": "坎", "水山蹇": "蹇", "水地比": "比",
    "山天大畜": "大畜", "山泽损": "损", "山火贲": "贲", "山雷颐": "颐",
    "山风蛊": "蛊", "山水蒙": "蒙", "艮为山": "艮", "山地剥": "剥",
    "地天泰": "泰", "地泽临": "临", "地火明夷": "明夷", "地雷复": "复",
    "地风升": "升", "地水师": "师", "地山谦": "谦", "坤为地": "坤",
}

# 个别条目源文本含整理痕迹，规整为通行经文。
JUDGMENT_FIX = {
    "乾": "元，亨，利，贞。 用九：见群龙无首，吉。",
}


def fetch_descriptions() -> dict:
    with urllib.request.urlopen(SOURCE_URL, timeout=30) as resp:
        src = resp.read().decode("utf-8")
    entries: dict[str, dict[str, str]] = {}
    for m in re.finditer(r'"([^"]+)": \{(.*?)\n  \}', src, re.S):
        key, body = m.group(1), m.group(2)
        fields = dict(re.findall(r'"(\d)": "((?:[^"\\]|\\.)*)"', body))
        entries[key] = {k: v.replace('\\"', '"') for k, v in fields.items()}
    return entries


def main() -> None:
    desc = fetch_descriptions()
    missing = [s for s in FULL_TO_SHORT.values() if s not in desc]
    assert not missing, f"经文缺少卦：{missing}"
    assert len(FULL_TO_SHORT) == 64
    assert len(set(FULL_TO_SHORT.values())) == 64

    corpus = []
    for full, short in FULL_TO_SHORT.items():
        d = desc[short]
        assert all(str(i) in d for i in range(7)), f"{short} 经文不完整"
        corpus.append(
            {
                "name": full,
                "short": short,
                "judgment": JUDGMENT_FIX.get(short, d["0"]),
                "lines": {str(i): d[str(i)] for i in range(1, 7)},
                "tuan": d.get("7", ""),
            }
        )

    out = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "app", "rag", "data", "zhouyi.json")
    )
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(corpus, f, ensure_ascii=False, indent=2)
    nlines = sum(len(c["lines"]) for c in corpus)
    print(f"wrote {out}: {len(corpus)} 卦, {nlines} 爻辞")


if __name__ == "__main__":
    main()
