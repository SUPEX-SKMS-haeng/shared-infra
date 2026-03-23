## Gateway

- traefik이라는 프록시 서버 사용
- https://doc.traefik.io/traefik/
  ![traefik](https://doc.traefik.io/traefik/assets/img/traefik-architecture.png)

**모니터링**

- 로깅
  - 액세스 로그 - 파일로 떨굼
  - 시스템 로그 - 도커 로그로 설정함 (default)

**traefik config**

- traefik.yml: static config
  - 변경 사항 있을 경우 컨테이너 재기동 해야함
  - traefik이 기본 제공하는 기능에 대한 설정
- traefik_dynamic_conf.yml: dynamic config
  - 변경사항 실시간 반영
  - 상기 변동 가능성 있는 router, middleware, service 등에 대한 설정

**사용 방법**

```sh
docker compose up -d
```


## image
```
아키텍처별 다이제스트 (Docker Hub에서 확인)

# AMD64 (x86_64) - 일반 서버/클라우드용
docker pull --platform linux/amd64 traefik:3.1 && \
docker tag traefik:3.1 workforce2.azurecr.io/playground/traefik:3.1-amd64

# ARM64/v8 - Apple Silicon (M1/M2), 최신 ARM 서버
docker pull --platform linux/arm64/v8 traefik:3.1 && \
docker tag traefik:3.1 workforce2.azurecr.io/playground/traefik:3.1-arm64


# ARM/v6 - Raspberry Pi Zero, 구형 ARM
docker pull --platform linux/arm/v6 traefik:3.1 && \
docker tag traefik:3.1 workforce2.azurecr.io/playground/traefik:3.1-armv6


docker push workforce2.azurecr.io/playground/traefik:3.1-amd64
docker push workforce2.azurecr.io/playground/traefik:3.1-arm64
docker push workforce2.azurecr.io/playground/traefik:3.1-armv6
```