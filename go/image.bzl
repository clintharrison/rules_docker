# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""A rule for creating a Go container image.

The signature of this rule is compatible with go_binary.
"""

# It is expected that the Go rules have been properly
# initialized before loading this file to initialize
# go_image.
load("@io_bazel_rules_go//go:def.bzl", "go_binary")
load(
    "//container:container.bzl",
    "container_pull",
)
load(
    "//lang:image.bzl",
    "app_layer",
)
load(
    "//repositories:go_repositories.bzl",
    _go_deps = "go_deps",
)

# Load the resolved digests.
load(":go.bzl", "DIGESTS")

def repositories():
    """Import the dependencies of the go_image rule.

    Call the core "go_deps" function to reduce boilerplate. This is
    idempotent if folks call it themselves.
    """
    _go_deps()

    excludes = native.existing_rules().keys()
    if "go_image_base" not in excludes:
        container_pull(
            name = "go_image_base",
            registry = "gcr.io",
            repository = "distroless/base",
            digest = DIGESTS["latest"],
        )
    if "go_debug_image_base" not in excludes:
        container_pull(
            name = "go_debug_image_base",
            registry = "gcr.io",
            repository = "distroless/base",
            digest = DIGESTS["debug"],
        )

DEFAULT_BASE = select({
    "@io_bazel_rules_docker//:debug": "@go_debug_image_base//image",
    "@io_bazel_rules_docker//:fastbuild": "@go_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@go_image_base//image",
    "//conditions:default": "@go_image_base//image",
})

def go_image(name, base = None, deps = [], layers = [], binary = None, **kwargs):
    """Constructs a container image wrapping a go_binary target.

  Args:
    name: Name of the go_image target.
    base: Base image to use to build the go_image.
    deps: Dependencies of the go image target.
    binary: An alternative binary target to use instead of generating one.
    layers: Augments "deps" with dependencies that should be put into their own layers.
    **kwargs: See go_binary.
  """
    if layers:
        print("go_image does not benefit from layers=[], got: %s" % layers)

    if not binary:
        binary = name + ".binary"
        go_binary(name = binary, deps = deps + layers, **kwargs)
    elif deps:
        fail("kwarg does nothing when binary is specified", "deps")

    base = base or DEFAULT_BASE
    for index, dep in enumerate(layers):
        base = app_layer(name = "%s.%d" % (name, index), base = base, dep = dep)
        base = app_layer(name = "%s.%d-symlinks" % (name, index), base = base, dep = dep, binary = binary)

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    restricted_to = kwargs.get("restricted_to", None)
    compatible_with = kwargs.get("compatible_with", None)
    app_layer(
        name = name,
        base = base,
        binary = binary,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
        testonly = kwargs.get("testonly"),
        restricted_to = restricted_to,
        compatible_with = compatible_with,
    )
