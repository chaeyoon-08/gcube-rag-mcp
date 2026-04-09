FROM python:3.11-slim

# Node.js 설치 (npx로 @modelcontextprotocol/server-filesystem 실행에 필요)
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends curl \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# mcpo: MCP stdio 서버를 OpenAPI HTTP 엔드포인트로 변환하는 프록시
RUN pip install --no-cache-dir mcpo uv

ENV NODE_ENV=production \
    LANG=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8

WORKDIR /app

COPY config.json /app/config/config.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
