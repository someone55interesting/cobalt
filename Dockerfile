FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

FROM base AS build
WORKDIR /app
COPY . /app

RUN corepack enable
# python3, alpine-sdk и git нужны для компиляции и создания фейкового .git
RUN apk add --no-cache python3 alpine-sdk git

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile

# Если Render сделал shallow-клон (без .git) – создаём минимальный репозиторий,
# чтобы дальнейшие шаги (pnpm deploy, запуск) не падали.
RUN if [ ! -d .git ]; then \
      git init . && \
      git add -A && \
      git commit -m "dummy"; \
    fi

RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

FROM base AS api
WORKDIR /app

# В финальном образе тоже нужен git, чтобы cobalt мог выполнять git rev-parse
RUN apk add --no-cache git

COPY --from=build --chown=node:node /prod/api /app
# Копируем гарантированно существующий .git из стадии сборки
COPY --from=build --chown=node:node /app/.git /app/.git

USER node

EXPOSE 9000
CMD [ "node", "src/cobalt" ]
