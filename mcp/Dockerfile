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

# MCP 서버 설정 파일 복사
COPY config.json /app/config/config.json

EXPOSE 8000

CMD ["uvx", "mcpo", "--host", "0.0.0.0", "--port", "8000", "--config", "/app/config/config.json"]
