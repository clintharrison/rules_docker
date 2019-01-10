def transition_impl(settings, attr):
    if attr.legacy_transition_behavior:
        return settings
    return {
        "//command_line_option:platforms": "@io_bazel_rules_docker//platform:linux_x86_64"
    }

docker_platform_transition = transition(
    implementation = transition_impl,
    inputs = [
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:platforms",
    ],
)
