IMAGE ?= filefrog/dproxy

build:
	docker build -t $(IMAGE) .
push:
	docker push $(IMAGE)
