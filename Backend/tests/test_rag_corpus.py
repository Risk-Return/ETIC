from app.rag.corpus import build_documents, corpus_by_name, load_corpus


def test_corpus_has_64_hexagrams_and_384_lines():
    corpus = load_corpus()
    assert len(corpus) == 64
    assert len({h["name"] for h in corpus}) == 64
    assert sum(len(h["lines"]) for h in corpus) == 384
    for h in corpus:
        assert set(h["lines"].keys()) == {str(i) for i in range(1, 7)}
        assert h["judgment"]


def test_corpus_keyed_by_engine_hexagram_names():
    by_name = corpus_by_name()
    # 引擎卦名（上卦+下卦命名）应可直接命中。
    assert by_name["山火贲"]["short"] == "贲"
    assert by_name["火山旅"]["short"] == "旅"
    assert by_name["乾为天"]["short"] == "乾"


def test_build_documents_judgment_and_lines():
    docs = build_documents(include_tuan=False)
    # 每卦 1 卦辞 + 6 爻辞。
    assert len(docs) == 64 * 7
    ben = [d for d in docs if d.hexagram_name == "山火贲"]
    assert len(ben) == 7
    judgment = [d for d in ben if d.doc_type == "judgment"][0]
    assert judgment.ref == "《山火贲》卦辞"
    line4 = [d for d in ben if d.doc_type == "line" and d.line_position == 4][0]
    assert line4.ref == "《山火贲》四爻"


def test_build_documents_with_tuan():
    docs = build_documents(include_tuan=True)
    assert any(d.doc_type == "tuan" for d in docs)
