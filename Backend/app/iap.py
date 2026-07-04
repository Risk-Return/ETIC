"""App Store Server Notifications v2 接收端点。

Apple 在发生订阅/退款等事件时，POST JWT 签名体到此处。
App Store Connect → "App Store Server Notifications" 中填入本端点地址：
  - 生产环境：https://deepwitai.cn/app/etic/v1/iap/notification
  - 沙盒环境：https://deepwitai.cn/app/etic/v1/iap/notification?test=1（可在 App Store Connect 同处配置）

体格式（application/json）为 signedPayload JWT，需用 Apple 根证书验签后取出
notificationType + subtype + signedTransactionInfo 等字段。

本模块当前阶段：接收、日志、返回 200 确认。后续按需补验签与业务逻辑（更新订阅状态等）。
"""

from __future__ import annotations

import json
import logging

from fastapi import APIRouter, Request, Response

logger = logging.getLogger("etic.iap")

router = APIRouter(prefix="/v1/iap", tags=["IAP"])

# v2 通知类型命名空间
_NOTIFICATION_TYPES = {
    "SUBSCRIBED": "首次订阅",
    "DID_CHANGE_RENEWAL_PREF": "续期偏好变更",
    "DID_CHANGE_RENEWAL_STATUS": "自动续期状态变更",
    "OFFER_REDEEMED": "促销兑换",
    "DID_RENEW": "续期成功",
    "EXPIRED": "订阅过期",
    "DID_FAIL_TO_RENEW": "续期失败",
    "GRACE_PERIOD_EXPIRED": "宽限期到期",
    "PRICE_INCREASE": "涨价同意",
    "REFUND": "退款",
    "REFUND_DECLINED": "退款被拒",
    "RENEWAL_EXTENDED": "续期延长",
    "REVOKE": "撤销",
    "TEST": "测试通知",
}


@router.post("/notification")
async def receive_notification(request: Request) -> Response:
    """接收 App Store Server Notification v2（signedPayload JWT）。

    目前仅日志，不验签（生产上线前务必补上 JWT 验签逻辑）。
    始终返回 200 以确认收妥（非 200 会触发 Apple 重试）。
    """
    body = await request.body()
    content_type = request.headers.get("content-type", "")

    # v2 通知体为 application/json，内 {"signedPayload": "<JWT>"}
    payload: dict | None = None
    if "application/json" in content_type:
        try:
            data = json.loads(body)
            signed = data.get("signedPayload", "")
            # JWT 格式：header.payload.signature
            # 现阶段不解码，完整 log。生产环境需验签。
            truncated = signed[:80] + "…" if len(signed) > 80 else signed
            logger.info("IAP notification received | signedPayload preview: %s", truncated)
            payload = data
        except json.JSONDecodeError:
            logger.warning("IAP notification unparseable body | len=%d", len(body))
    else:
        logger.warning("IAP notification unexpected content-type: %s", content_type)

    # 直接返回 200 确认收妥；检测到测试环境时标记。
    test_mode = request.query_params.get("test") is not None
    if test_mode:
        logger.info("IAP notification test mode")

    return Response(status_code=200)
