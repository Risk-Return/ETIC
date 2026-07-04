"""pgvector 向量库：建表、灌库、检索。

仅存储公有领域经文片段及其向量；不含用户数据。检索同时支持：
- 精确按卦名 / 爻位定位（六爻最相关的本卦卦辞、动爻爻辞、变卦卦辞）；
- 向量相似度召回（按问题语义补充）。
"""

from contextlib import contextmanager
from typing import Iterator, Sequence

import psycopg
from pgvector.psycopg import register_vector

from ..config import Settings
from .corpus import Document

_TABLE = "rag_documents"


@contextmanager
def connect(settings: Settings) -> Iterator[psycopg.Connection]:
    conn = psycopg.connect(settings.database_url)
    try:
        # vector 类型须先存在才能注册到连接上。
        conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
        conn.commit()
        register_vector(conn)
        yield conn
    finally:
        conn.close()


def ensure_schema(conn: psycopg.Connection, dim: int) -> None:
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
        # 维度变更需重建表（向量列维度固定）。pgvector 的 atttypmod = dim + 4。
        cur.execute(
            "SELECT a.atttypmod FROM pg_attribute a "
            "JOIN pg_class c ON c.oid = a.attrelid "
            "WHERE c.relname = %s AND a.attname = 'embedding'",
            (_TABLE,),
        )
        row = cur.fetchone()
        if row is not None and row[0] != dim + 4:
            cur.execute(f"DROP TABLE {_TABLE}")
        cur.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {_TABLE} (
                id            SERIAL PRIMARY KEY,
                hexagram_name TEXT NOT NULL,
                hexagram_short TEXT NOT NULL,
                doc_type      TEXT NOT NULL,
                line_position INT,
                content       TEXT NOT NULL,
                embedding     vector({dim}) NOT NULL
            )
            """
        )
        cur.execute(
            f"CREATE INDEX IF NOT EXISTS {_TABLE}_name_idx "
            f"ON {_TABLE} (hexagram_name, doc_type, line_position)"
        )
        cur.execute(
            f"CREATE INDEX IF NOT EXISTS {_TABLE}_vec_idx "
            f"ON {_TABLE} USING hnsw (embedding vector_cosine_ops)"
        )
    conn.commit()


def ingest(
    conn: psycopg.Connection,
    documents: Sequence[Document],
    vectors: Sequence[Sequence[float]],
) -> int:
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE {_TABLE} RESTART IDENTITY")
        with cur.copy(
            f"COPY {_TABLE} "
            "(hexagram_name, hexagram_short, doc_type, line_position, content, embedding) "
            "FROM STDIN WITH (FORMAT BINARY)"
        ) as copy:
            copy.set_types(["text", "text", "text", "int4", "text", "vector"])
            for doc, vec in zip(documents, vectors):
                copy.write_row(
                    (
                        doc.hexagram_name,
                        doc.hexagram_short,
                        doc.doc_type,
                        doc.line_position,
                        doc.content,
                        list(vec),
                    )
                )
    conn.commit()
    with conn.cursor() as cur:
        cur.execute(f"SELECT count(*) FROM {_TABLE}")
        return int(cur.fetchone()[0])


def _decode(v):
    return v.decode() if isinstance(v, bytes) else v


def _row_to_doc(row: tuple) -> Document:
    name, short, doc_type, pos, content = row
    return Document(_decode(name), _decode(short), _decode(doc_type), pos, _decode(content))


def _exclude_key(row: tuple) -> tuple:
    name = _decode(row[0])
    doc_type = _decode(row[2])
    return (name, doc_type, row[3])


def fetch_exact(
    conn: psycopg.Connection, keys: Sequence[tuple[str, str, int | None]]
) -> list[Document]:
    """按 (卦名, doc_type, 爻位) 精确取片段，保持传入顺序、去重。"""

    out: list[Document] = []
    seen: set[tuple] = set()
    with conn.cursor() as cur:
        for name, doc_type, pos in keys:
            if pos is None:
                cur.execute(
                    f"SELECT hexagram_name, hexagram_short, doc_type, line_position, content "
                    f"FROM {_TABLE} WHERE hexagram_name=%s AND doc_type=%s AND line_position IS NULL",
                    (name, doc_type),
                )
            else:
                cur.execute(
                    f"SELECT hexagram_name, hexagram_short, doc_type, line_position, content "
                    f"FROM {_TABLE} WHERE hexagram_name=%s AND doc_type=%s AND line_position=%s",
                    (name, doc_type, pos),
                )
            for row in cur.fetchall():
                key = _exclude_key(row)
                if key not in seen:
                    seen.add(key)
                    out.append(_row_to_doc(row))
    return out


def search(
    conn: psycopg.Connection,
    query_vec: Sequence[float],
    top_k: int,
    exclude: Sequence[tuple[str, str, int | None]] = (),
) -> list[tuple[Document, float]]:
    """向量相似度召回 top_k（余弦距离升序）。"""

    with conn.cursor() as cur:
        cur.execute(
            f"SELECT hexagram_name, hexagram_short, doc_type, line_position, content, "
            f"embedding <=> %s::vector AS dist FROM {_TABLE} ORDER BY dist ASC LIMIT %s",
            (list(query_vec), top_k + len(exclude)),
        )
        rows = cur.fetchall()
    exclude_set = set(exclude)
    out: list[tuple[Document, float]] = []
    for row in rows:
        if _exclude_key(row) in exclude_set:
            continue
        out.append((_row_to_doc(row[:5]), float(row[5])))
        if len(out) >= top_k:
            break
    return out
