SHELL := /bin/sh
TAG ?= dev
ENV ?= dev

.PHONY: install migrate seed api runtime web test test-unit test-e2e lint typecheck build image deploy smoke

install:
	cd backend && pip install -e .[dev]
	cd frontend && npm ci

migrate:
	cd backend && alembic upgrade head

seed:
	cd backend && python -m app.scripts.seed

api:
	cd backend && uvicorn app.main:app --reload --port 8000

runtime:
	cd agent-runtime && uvicorn app.main:app --reload --port 8100

web:
	cd frontend && npm run dev

test:
	cd backend && pytest -q
	cd frontend && npm test -- --run

test-unit:
	cd backend && pytest -q -m unit
	cd frontend && npm test -- --run

test-e2e:
	cd frontend && npx playwright test

lint:
	cd backend && ruff check . && mypy app
	cd frontend && npm run lint

typecheck:
	cd backend && mypy app
	cd frontend && npm run typecheck

build:
	cd frontend && npm run build

image:
	docker build -t cloud-agent/api:$(TAG) backend
	docker build -t cloud-agent/runtime:$(TAG) agent-runtime
	docker build -t cloud-agent/web:$(TAG) frontend

deploy:
	helm upgrade --install cloud-agent deploy/helm -f deploy/helm/values-$(ENV).yaml --set image.tag=$(TAG)

smoke:
	curl -fsS http://localhost:8000/health.json
	curl -fsS http://localhost:8100/health.json
