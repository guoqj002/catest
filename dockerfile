# syntax=docker/dockerfile:1.4
# 请根据你的应用基础镜像替换（alpine 见文末说明）
FROM debian:bookworm-slim

# debian-slim 默认不带 ca-certificates，必须先装，否则没有 update-ca-certificates 命令
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ===== 核心两步：复制证书 → 刷新信任库 =====
# 1) 一次 RUN 挂载两个 BuildKit secret（源文件不会留在镜像层）
# 2) 复制到 /usr/local/share/ca-certificates/，文件名必须以 .crt 结尾
# 3) update-ca-certificates 把两个 CA 合并进 /etc/ssl/certs/ca-certificates.crt
RUN --mount=type=secret,id=corp_root \
    --mount=type=secret,id=local_ca01 \
    cp /run/secrets/corp_root /usr/local/share/ca-certificates/corp-root.crt \
 && cp /run/secrets/local_ca01 /usr/local/share/ca-certificates/local-CA01.crt \
 && update-ca-certificates \
 # 可选：如果你希望源文件也不留在最终镜像中，取消下面这行注释。
 # 注意：删除源文件不会影响信任，CA 数据已在 ca-certificates.crt 中。
 # && rm -f /usr/local/share/ca-certificates/*.crt \
 && echo "=== 信任目录 ===" \
 && ls -la /usr/local/share/ca-certificates/ \
 && echo "=== 验证符号链接 ===" \
 && for name in corp-root local-CA01; do \
        if find /etc/ssl/certs -maxdepth 1 -type l -lname "*${name}*" | grep -q .; then \
            echo "✅ ${name} 已进入信任库"; \
        else \
            echo "❌ ${name} 未进入信任库"; exit 1; \
        fi; \
    done \
 && echo "=== 信任库中证书总数 ===" \
 && grep -c "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt

# 以下是你的应用层，示例给一个最小入口
# 真实场景请把上面的 RUN 放在应用构建步骤之前即可
CMD ["bash", "-c", "echo '信任库就绪: /etc/ssl/certs/ca-certificates.crt'; exec sleep infinity"]