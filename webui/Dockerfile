ARG BASE_VERSION=v0.6.5
FROM ghcr.io/open-webui/open-webui:${BASE_VERSION}

# 한국어 로케일 및 폰트 설치
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends locales fonts-nanum \
 && echo 'ko_KR.UTF-8 UTF-8' > /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8 \
    PYTHONIOENCODING=utf-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
