APP             := miniflux
DOCKER_IMAGE    := miniflux/miniflux
VERSION         := $(shell git describe --tags --abbrev=0 2>/dev/null)
COMMIT          := $(shell git rev-parse --short HEAD 2>/dev/null)
BUILD_DATE      := `date +%FT%T%z`
LD_FLAGS        := "-s -w -X 'miniflux.app/v2/internal/version.Version=$(VERSION)' -X 'miniflux.app/v2/internal/version.Commit=$(COMMIT)' -X 'miniflux.app/v2/internal/version.BuildDate=$(BUILD_DATE)'"
PKG_LIST        := $(shell go list ./... | grep -v /vendor/)
DB_URL          := postgres://postgres:postgres@localhost/miniflux_test?sslmode=disable
DOCKER_PLATFORM := amd64

export PGPASSWORD := postgres

.PHONY: \
	miniflux \
	miniflux-no-pie \
	linux-amd64 \
	linux-arm64 \
	linux-armv7 \
	linux-armv6 \
	linux-armv5 \
	linux-x86 \
	darwin-amd64 \
	darwin-arm64 \
	freebsd-amd64 \
	openbsd-amd64 \
	netbsd-amd64 \
	build \
	run \
	clean \
	add-string \
	test \
	lint \
	integration-test \
	clean-integration-test \
	docker-image \
	docker-image-distroless \
	docker-images \
	rpm \
	debian \
	debian-packages

miniflux:
	@ go build -buildmode=pie -ldflags=$(LD_FLAGS) -o $(APP) main.go

miniflux-no-pie:
	@ go build -ldflags=$(LD_FLAGS) -o $(APP) main.go

linux-amd64:
	@ CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

linux-arm64:
	@ CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

linux-armv7:
	@ CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

linux-armv6:
	@ CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=6 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

linux-armv5:
	@ CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

darwin-amd64:
	@ GOOS=darwin GOARCH=amd64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

darwin-arm64:
	@ GOOS=darwin GOARCH=arm64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

freebsd-amd64:
	@ CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

openbsd-amd64:
	@ GOOS=openbsd GOARCH=amd64 go build -ldflags=$(LD_FLAGS) -o $(APP)-$@ main.go
	@ sha256sum $(APP)-$@ > $(APP)-$@.sha256

build: linux-amd64 linux-arm64 linux-armv7 linux-armv6 linux-armv5 darwin-amd64 darwin-arm64 freebsd-amd64 openbsd-amd64

run:
	@ LOG_DATE_TIME=1 LOG_LEVEL=debug RUN_MIGRATIONS=1 CREATE_ADMIN=1 ADMIN_USERNAME=admin ADMIN_PASSWORD=test123 go run main.go

clean:
	@ rm -f $(APP)-* $(APP) $(APP)*.rpm $(APP)*.deb $(APP)*.exe $(APP)*.sha256

add-string:
	cd internal/locale/translations && \
	for file in *.json; do \
		jq --indent 4 --arg key "$(KEY)" --arg val "$(VAL)" \
		   '. + {($$key): $$val} | to_entries | sort_by(.key) | from_entries' "$$file" > tmp && \
		mv tmp "$$file"; \
	done

test:
	go test -cover -race -count=1 ./...

lint:
	go vet ./...
	staticcheck ./...
	golangci-lint run --disable errcheck --enable sqlclosecheck --enable misspell --enable gofmt --enable goimports --enable whitespace

integration-test:
	psql -U postgres -c 'drop database if exists miniflux_test;'
	psql -U postgres -c 'create database miniflux_test;'
	go build -o miniflux-test main.go

	DATABASE_URL=$(DB_URL) \
	ADMIN_USERNAME=admin \
	ADMIN_PASSWORD=test123 \
	CREATE_ADMIN=1 \
	RUN_MIGRATIONS=1 \
	LOG_LEVEL=debug \
	./miniflux-test >/tmp/miniflux.log 2>&1 & echo "$$!" > "/tmp/miniflux.pid"

	while ! nc -z localhost 8080; do sleep 1; done

	TEST_MINIFLUX_BASE_URL=http://127.0.0.1:8080 \
	TEST_MINIFLUX_ADMIN_USERNAME=admin \
	TEST_MINIFLUX_ADMIN_PASSWORD=test123 \
	go test -v -count=1 ./internal/api

clean-integration-test:
	@ kill -9 `cat /tmp/miniflux.pid`
	@ rm -f /tmp/miniflux.pid /tmp/miniflux.log
	@ rm miniflux-test
	@ psql -U postgres -c 'drop database if exists miniflux_test;'

docker-image:
	docker build --pull -t $(DOCKER_IMAGE):$(VERSION) -f packaging/docker/alpine/Dockerfile .

docker-image-distroless:
	docker build -t $(DOCKER_IMAGE):$(VERSION) -f packaging/docker/distroless/Dockerfile .

docker-images:
	docker buildx build \
		--platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 \
		--file packaging/docker/alpine/Dockerfile \
		--tag $(DOCKER_IMAGE):$(VERSION) \
		--push .

rpm: clean
	@ docker build \
		-t miniflux-rpm-builder \
		-f packaging/rpm/Dockerfile \
		.
	@ docker run --rm \
		-v ${PWD}:/root/rpmbuild/RPMS/x86_64 miniflux-rpm-builder \
		rpmbuild -bb --define "_miniflux_version $(VERSION)" /root/rpmbuild/SPECS/miniflux.spec

debian:
	@ docker buildx build --load \
		--platform linux/$(DOCKER_PLATFORM) \
		-t miniflux-deb-builder \
		-f packaging/debian/Dockerfile \
		.
	@ docker run --rm --platform linux/$(DOCKER_PLATFORM) \
		-v ${PWD}:/pkg miniflux-deb-builder

debian-packages: clean
	$(MAKE) debian DOCKER_PLATFORM=amd64
	$(MAKE) debian DOCKER_PLATFORM=arm64
	$(MAKE) debian DOCKER_PLATFORM=arm/v7
