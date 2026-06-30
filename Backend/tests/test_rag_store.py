from app.rag import store
from app.rag.corpus import build_documents


def test_fetch_exact_returns_requested_fragments(rag_db):
    with store.connect(rag_db) as conn:
        docs = store.fetch_exact(
            conn,
            [
                ("山火贲", "judgment", None),
                ("山火贲", "line", 4),
            ],
        )
    refs = [d.ref for d in docs]
    assert refs == ["《山火贲》卦辞", "《山火贲》四爻"]
    assert "白马翰如" in docs[1].content


def test_search_returns_top_k(rag_db):
    from app.rag.embeddings import _mock_embed_one

    query = _mock_embed_one("《山火贲》卦辞：亨。 小利有所往。", rag_db.embed_dim)
    with store.connect(rag_db) as conn:
        hits = store.search(conn, query, top_k=3)
    assert len(hits) == 3
    # 与查询同文的片段应排在最前（距离最小）。
    assert hits[0][0].hexagram_name == "山火贲"
    assert hits[0][1] <= hits[1][1] <= hits[2][1]


def test_ingest_count_matches_documents(rag_db):
    with store.connect(rag_db) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM rag_documents")
            count = cur.fetchone()[0]
    assert count == len(build_documents(include_tuan=False))
