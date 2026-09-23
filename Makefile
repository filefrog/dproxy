IMAGE ?= filefrog/dproxy
TAG ?= 3

build:
	docker build -t $(IMAGE):$(TAG) .
	docker run --rm --entrypoint= $(IMAGE):$(TAG) nginx -v
latest:
	docker pull nginx
push:
	docker push $(IMAGE):$(TAG)
