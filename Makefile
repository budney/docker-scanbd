BASENAME=scanbd
BUILDNAME=$(BASENAME)-buildx

.PHONY: all builder prune delete clean distclean

all: builder
	docker buildx build --push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 --tag $(LOGNAME)/$(BASENAME):latest .

clean: delete prune

builder:
	docker buildx create --use --name=$(BUILDNAME)

prune:
	docker buildx prune -f 

delete:
	docker buildx rm $(BUILDNAME)
