FROM python:3.11-slim

# mcpo: MCP-to-OpenAPI 프록시 (HTTP 기반 MCP 서버 래퍼)
RUN pip install --no-cache-dir mcpo uv

ENV NODE_ENV=production \
    LANG=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8

WORKDIR /app

# config.json은 런타임에 볼륨 마운트로 제공
# 기본 설정 파일은 config/config.json.example 참고
EXPOSE 8000

CMD ["uvx", "mcpo", "--host", "0.0.0.0", "--port", "8000", "--config", "/app/config/config.json"]
