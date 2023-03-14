#!/usr/bin/env bats

TEST_HELPER_DIR="$BATS_TEST_DIRNAME/../test_helper"
export TEST_HELPER_DIR

load "$TEST_HELPER_DIR"/tools_check.bash
load "$TEST_HELPER_DIR"/fluvio_dev.bash
load "$TEST_HELPER_DIR"/bats-support/load.bash
load "$TEST_HELPER_DIR"/bats-assert/load.bash

# disabling compiling because it has no feedback
# this should be done before running test
setup_file() {
    # Compile the smartmodule examples
#    pushd "$BATS_TEST_DIRNAME/../../.." && make build_smartmodules && popd
    SMARTMODULE_BUILD_DIR="$BATS_TEST_DIRNAME/../../../smartmodule/examples/target/wasm32-unknown-unknown/release"
    export SMARTMODULE_BUILD_DIR

}

@test "invoke map smartmodule in producer by name" {
    # Load the smartmodule
    SMARTMODULE_NAME="uppercase"
    export SMARTMODULE_NAME
    run timeout 15s "$FLUVIO_BIN" smartmodule create $SMARTMODULE_NAME --wasm-file $SMARTMODULE_BUILD_DIR/fluvio_smartmodule_map.wasm
    # Print out cmd since we need complete trace of cmd not just failing
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_output "smartmodule \"$SMARTMODULE_NAME\" has been created."

    # Create topic
    TOPIC_NAME="$(random_string)"
    export TOPIC_NAME
    run timeout 15s "$FLUVIO_BIN" topic create "$TOPIC_NAME"
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_output "topic \"$TOPIC_NAME\" created"

    # Produce to topic
    TEST_MESSAGE="Banana"
    export TEST_MESSAGE
    run bash -c 'echo "$TEST_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" --smartmodule "$SMARTMODULE_NAME"'
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success

    EXPECTED_OUTPUT="BANANA"
    export EXPECTED_OUTPUT
    run timeout 15s "$FLUVIO_BIN" consume "$TOPIC_NAME" -B -d
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_output "$EXPECTED_OUTPUT"
    assert_success




    # Delete topic
    run timeout 15s "$FLUVIO_BIN" topic delete "$TOPIC_NAME"
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success

    # Delete smartmodule
    run timeout 15s "$FLUVIO_BIN" smartmodule delete "$SMARTMODULE_NAME"
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success
}

@test "invoke filter smartmodule in producer with params" {
    # Create topic
    TOPIC_NAME="$(random_string)"
    export TOPIC_NAME
    run timeout 15s "$FLUVIO_BIN" topic create "$TOPIC_NAME"
    assert_success

    # Produce a message that should be filtered out
    FILTERED_OUT_MESSAGE="aaaaa"
    export FILTERED_OUT_MESSAGE
    run bash -c 'echo "$FILTERED_OUT_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" \
        --smartmodule-path $SMARTMODULE_BUILD_DIR/fluvio_smartmodule_filter_param.wasm \
        --params key=z'
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success

    # Produce a message that should be retained
    RETAINED_MESSAGE="zzzzz"
    export RETAINED_MESSAGE
    run bash -c 'echo "$RETAINED_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" \
        --smartmodule-path $SMARTMODULE_BUILD_DIR/fluvio_smartmodule_filter_param.wasm \
        --params key=z'
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success

    # Consume from topic and verify we don't see the $FILTERED_OUT_MESSAGE
    EXPECTED_OUTPUT="${RETAINED_MESSAGE}"
    export EXPECTED_OUTPUT
    run timeout 15s "$FLUVIO_BIN" consume "$TOPIC_NAME" -B -d
    refute_line --partial "$FILTERED_OUT_MESSAGE"
    assert_output "$EXPECTED_OUTPUT"



    # Delete topic
    run timeout 15s "$FLUVIO_BIN" topic delete "$TOPIC_NAME"
    assert_success
}

@test "invoke map smartmodule in producer by path" {
    # Create topic
    TOPIC_NAME="$(random_string)"
    export TOPIC_NAME
    run timeout 15s "$FLUVIO_BIN" topic create "$TOPIC_NAME"
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_output "topic \"$TOPIC_NAME\" created"

    # Produce to topic with smartmodule path
    TEST_MESSAGE="Banana"
    export TEST_MESSAGE
    run bash -c 'echo "$TEST_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" \
        --smartmodule-path $SMARTMODULE_BUILD_DIR/fluvio_smartmodule_map.wasm'
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success

    EXPECTED_OUTPUT="BANANA"
    export EXPECTED_OUTPUT
    run timeout 15s "$FLUVIO_BIN" consume "$TOPIC_NAME" -B -d
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_output "$EXPECTED_OUTPUT"
    assert_success




    # Delete topic
    run timeout 15s "$FLUVIO_BIN" topic delete "$TOPIC_NAME"
    echo "cmd: $BATS_RUN_COMMAND" >&2
    assert_success
}

@test "invoke filter-map smartmodule in producer" {
    # Load the smartmodule
    SMARTMODULE_NAME="divide-even-by-2"
    export SMARTMODULE_NAME
    run timeout 15s "$FLUVIO_BIN" smartmodule create $SMARTMODULE_NAME \
        --wasm-file $SMARTMODULE_BUILD_DIR/fluvio_smartmodule_filter_map.wasm
    assert_success

    # Create topic
    TOPIC_NAME="$(random_string)"
    export TOPIC_NAME
    run timeout 15s "$FLUVIO_BIN" topic create "$TOPIC_NAME"
    assert_success

    # Produce to topic
    NEGATIVE_TEST_MESSAGE="37"
    export NEGATIVE_TEST_MESSAGE
    run bash -c 'echo "$NEGATIVE_TEST_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" \
        --smartmodule "$SMARTMODULE_NAME"'
    assert_success

    TEST_MESSAGE="100"
    export TEST_MESSAGE
    run bash -c 'echo "$TEST_MESSAGE" | timeout 15s "$FLUVIO_BIN" produce "$TOPIC_NAME" \
        --smartmodule "$SMARTMODULE_NAME"'
    assert_success

    # Consume from topic with smartmodule and verify we don't see the $NEGATIVE_TEST_MESSAGE
    EXPECTED_OUTPUT="${TEST_MESSAGE}"
    export EXPECTED_OUTPUT
    run timeout 15s "$FLUVIO_BIN" consume "$TOPIC_NAME" -B -d
    refute_line "$NEGATIVE_TEST_MESSAGE"
    assert_output "$((EXPECTED_OUTPUT/2))"



    # Delete topic
    run timeout 15s "$FLUVIO_BIN" topic delete "$TOPIC_NAME"
    assert_success

    # Delete smartmodule
    run timeout 15s "$FLUVIO_BIN" smartmodule delete "$SMARTMODULE_NAME"
    assert_success
}

