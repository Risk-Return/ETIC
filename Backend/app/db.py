"""共享数据库连接助手。

账号系统与 RAG 向量库共用同一 Postgres 实例（`database_url`）。
RAG 模块需额外注册 pgvector 类型，故保留自己的 `connect()`；
本模块提供不带 vector 注册的普通连接，供账号/计费模块使用。
"""

from contextlib import contextmanager
from typing import Iterator

import psycopg

from .config import Settings


@contextmanager
def connect(settings: Settings) -> Iterator[psycopg.Connection]:
    conn = psycopg.connect(settings.database_url, autocommit=False)
    try:
        yield conn
    finally:
        conn.close()
