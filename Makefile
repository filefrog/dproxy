IMAGE ?= filefrog/dproxy

build:
	docker build -t $(IMAGE) .
	docker run --rm --entrypoint= filefrog/dproxy nginx -v
latest:
	docker pull nginx
push:
	docker push $(IMAGE)
