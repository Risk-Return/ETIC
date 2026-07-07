# ETIC 站点 URL 与脚本路径对照

> 部署服务器：`deepwitai.cn`（IP: 8.166.131.144）
> Nginx 配置：`/etc/nginx/conf.d/aibi.conf`
> 静态文件根目录：`/root/projects/AIBI/frontend`

---

## 一、App Store 审核页面（静态 HTML）

| URL | 用途 | 文件路径 |
|-----|------|---------|
| `https://deepwitai.cn/etic/` | 营销主页（中/英双语） | `/root/projects/AIBI/frontend/pages/etic/index.html` |
| `https://deepwitai.cn/etic/privacy` | 隐私政策（中/英双语） | `/root/projects/AIBI/frontend/pages/etic/privacy.html` |
| `https://deepwitai.cn/etic/terms` | 服务条款（中/英双语） | `/root/projects/AIBI/frontend/pages/etic/terms.html` |

Nginx 路由规则（HTTP + HTTPS 双段相同）：

```nginx
location = /etic {
    return 301 /etic/;
}
location /etic/ {
    root /root/projects/AIBI/frontend/pages;
    index index.html;
    try_files $uri $uri.html $uri/ /etic/index.html;
}
```

注意：`/etic/` 静态页路由必须在 `/app/etic/`（后端代理）之前声明，否则 nginx 最长前缀匹配可能错误代理。

---

## 二、解读后端 API（FastAPI + SSE）

服务进程：`/root/projects/ETIC/Backend/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 18000`

| URL | 用途 | 处理模块 |
|-----|------|---------|
| `https://deepwitai.cn/app/etic/healthz` | 健康检查 | `main.py` |
| `https://deepwitai.cn/app/etic/v1/interpret` | 首轮解读（SSE 流式） | `main.py` |
| `https://deepwitai.cn/app/etic/v1/chat` | 多轮追问（SSE 流式） | `main.py` |
| `https://deepwitai.cn/app/etic/v1/grounding` | 周易经文检索 | `main.py` |
| `https://deepwitai.cn/app/etic/v1/auth/apple` | Apple Sign In 登录 | `account.py` |
| `https://deepwitai.cn/app/etic/v1/auth/test` | 测试登录（dev_mode=true） | `account.py` |
| `https://deepwitai.cn/app/etic/v1/account/me` | 账号状态查询 | `account.py` |
| `https://deepwitai.cn/app/etic/v1/iap/verify` | StoreKit 交易验证 | `account.py` |
| `https://deepwitai.cn/app/etic/v1/iap/notification` | App Store Server Notifications v2 接收 | `iap.py` |

Nginx 代理规则：

```nginx
location /app/etic/ {
    proxy_pass http://127.0.0.1:18000/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    proxy_buffering off;
    proxy_cache off;
}
```

---

## 三、后端源码关键文件

| 文件 | 职责 |
|------|------|
| `Backend/app/main.py` | FastAPI 应用入口、路由注册 |
| `Backend/app/config.py` | 配置（Settings，环境变量 `ETIC_` 前缀） |
| `Backend/app/models.py` | 请求/响应 Pydantic 模型 |
| `Backend/app/llm.py` | LLM 流式客户端（OpenAI 兼容 + mock） |
| `Backend/app/prompt.py` | System Prompt 组装 |
| `Backend/app/auth.py` | Apple Sign In 验签 + 会话 JWT |
| `Backend/app/account.py` | 账号/计费路由 |
| `Backend/app/account_db.py` | 账号 DB 建表与 CRUD |
| `Backend/app/account_models.py` | 账号相关 Pydantic 模型 |
| `Backend/app/iap.py` | App Store Server Notifications 接收 + 验签 |
| `Backend/app/db.py` | 通用 DB 连接（无 pgvector） |
| `Backend/app/rag/` | RAG 模块（corpus, embeddings, retrieval, store） |
| `Backend/scripts/ingest.py` | 周易经文灌库脚本 |
| `Backend/.env.example` | 环境变量模板 |
| `Backend/.env` | 生产环境变量（gitignored） |
| `Backend/keys/` | Apple 私钥目录（gitignored） |
| `Backend/app/apple_root_ca.pem` | Apple Root CA G3 证书 |

---

## 四、Apple 密钥文件

| 文件 | 用途 |
|------|------|
| `Backend/keys/logo-in/AuthKey_L42755A2C3.p8` | Sign in with Apple 私钥（Key ID: L42755A2C3） |
| `Backend/keys/notification/production/AuthKey_KRAL2SFAXJ.p8` | APNs 生产环境私钥（Key ID: KRAL2SFAXJ） |
| `Backend/keys/notification/sandbox/AuthKey_SQKM8TVF57.p8` | APNs 沙盒环境私钥（Key ID: SQKM8TVF57） |

---

## 五、运行命令

### 后端服务

```bash
# 安装依赖（如首次）
cd /root/projects/ETIC/Backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt -i https://mirrors.ustc.edu.cn/pypi/web/simple/

# 灌库 RAG
python scripts/ingest.py

# 启动服务（生产）
nohup .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 18000 &>/tmp/etic-backend.log &
disown

# 运行测试
pytest -v
```

### Nginx 重载

```bash
nginx -t && kill -HUP $(pgrep -f "nginx: master")
```

---

## 六、App Store Connect 配置

| 字段 | 值 |
|------|-----|
| 技术支持 URL | `https://deepwitai.cn/etic/#support` |
| 营销 URL | `https://deepwitai.cn/etic/` |
| 隐私政策 URL | `https://deepwitai.cn/etic/privacy` |
| App Store Server Notifications (生产) | `https://deepwitai.cn/app/etic/v1/iap/notification` |
| App Store Server Notifications (沙盒) | `https://deepwitai.cn/app/etic/v1/iap/notification?test=1` |
