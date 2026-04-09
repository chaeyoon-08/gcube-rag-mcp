FROM qdrant/qdrant:v1.17.1

# curl 설치 (스냅샷 스크립트에서 Qdrant REST API 호출에 사용)
USER root
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

COPY snapshot.sh /snapshot.sh
RUN chmod +x /snapshot.sh

# 스냅샷 저장 경로 (Dropbox 마운트 경로)
ENV QDRANT__STORAGE__SNAPSHOTS_PATH=/qdrant/snapshots

ENTRYPOINT ["/snapshot.sh"]
