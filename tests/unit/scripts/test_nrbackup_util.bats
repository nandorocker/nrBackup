test "nrbackup utility function test" {
    run ./path_to_nrbackup_util_function
    [ "$status" -eq 0 ]
    [ "$output" = "expected_output" ]
}