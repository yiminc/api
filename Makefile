$(VERBOSE).SILENT:
############################# Main targets #############################
# Install everything, run all linters, and compile proto files.
install: grpc-install api-linter-install buf-install proto

# Run all linters and compile proto files.
proto: grpc
########################################################################

##### Variables ######
ifndef GOPATH
GOPATH := $(shell go env GOPATH)
endif

GOBIN := $(if $(shell go env GOBIN),$(shell go env GOBIN),$(GOPATH)/bin)
SHELL := PATH=$(GOBIN):$(PATH) /bin/sh

COLOR := "\e[1;36m%s\e[0m\n"

PROTO_ROOT := .
PROTO_FILES = $(shell find $(PROTO_ROOT) -name "*.proto")
PROTO_DIRS = $(sort $(dir $(PROTO_FILES)))
PROTO_OUT := .gen
PROTO_IMPORTS := -I=$(PROTO_ROOT) -I=$(GOPATH)/src/github.com/temporalio/gogo-protobuf/protobuf

$(PROTO_OUT):
	mkdir $(PROTO_OUT)

##### Compile proto files for go #####
grpc: buf-lint api-linter buf-breaking gogo-grpc fix-path

go-grpc: clean $(PROTO_OUT)
	printf $(COLOR) "Compile for go-gRPC..."
	$(foreach PROTO_DIR,$(PROTO_DIRS),protoc $(PROTO_IMPORTS) --go_out=plugins=grpc,paths=source_relative:$(PROTO_OUT) $(PROTO_DIR)*.proto;)

gogo-grpc: clean $(PROTO_OUT)
	printf $(COLOR) "Compile for gogo-gRPC..."
	$(foreach PROTO_DIR,$(PROTO_DIRS),protoc $(PROTO_IMPORTS) --gogoslick_out=Mgoogle/protobuf/wrappers.proto=github.com/gogo/protobuf/types,Mgoogle/protobuf/duration.proto=github.com/gogo/protobuf/types,Mgoogle/protobuf/descriptor.proto=github.com/golang/protobuf/protoc-gen-go/descriptor,Mgoogle/protobuf/timestamp.proto=github.com/gogo/protobuf/types,plugins=grpc,paths=source_relative:$(PROTO_OUT) $(PROTO_DIR)*.proto;)

fix-path:
	mv -f $(PROTO_OUT)/temporal/api/* $(PROTO_OUT) && rm -rf $(PROTO_OUT)/temporal

##### Plugins & tools #####
grpc-install: gogo-protobuf-install
	printf $(COLOR) "Install/update gRPC plugins..."
	GO111MODULE=on go get google.golang.org/grpc@v1.34.0

gogo-protobuf-install: go-protobuf-install
	go get github.com/temporalio/gogo-protobuf/protoc-gen-gogoslick

go-protobuf-install:
	GO111MODULE=on go get github.com/golang/protobuf/protoc-gen-go@v1.4.3

api-linter-install:
	printf $(COLOR) "Install/update api-linter..."
	GO111MODULE=on go get github.com/googleapis/api-linter/cmd/api-linter@v1.10.0

buf-install:
	printf $(COLOR) "Install/update buf..."
	GO111MODULE=on go get github.com/bufbuild/buf/cmd/buf@v0.43.2

##### Linters #####
api-linter:
	printf $(COLOR) "Run api-linter..."
	api-linter --set-exit-status $(PROTO_IMPORTS) --config $(PROTO_ROOT)/api-linter.yaml $(PROTO_FILES)

buf-lint:
	printf $(COLOR) "Run buf linter..."
	(cd $(PROTO_ROOT) && buf check lint)

buf-breaking:
	@printf $(COLOR) "Run buf breaking changes check against master branch..."
	buf --version
	@(cd $(PROTO_ROOT) && buf breaking --against '.git#branch=master')

##### Clean #####
clean:
	printf $(COLOR) "Delete generated go files..."
	rm -rf $(PROTO_OUT)
