reset-psql: stop-psql start-psql

start-psql:
	docker run --name some-postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d postgres

stop-psql:
	docker kill some-postgres || echo not running
	docker rm some-postgres || echo no image

db-create:
	mix ecto.create

db-migrate:
	mix ecto.migrate

db-rollback:
	mix ecto.rollback

run:
	iex -S mix phx.server

seed:
	mix run priv/repo/seeds.exs

.PHONY: deps
deps:
	mix deps.get

npm-install:
	npm install --prefix assets
