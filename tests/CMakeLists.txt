# Tests where we compare with the Unix version of the tool.
file(GLOB ED_TESTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "ed/*.options")
# file(GLOB VI_TESTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "vi/*.options")
# Tests where we compare with gold files.
file(GLOB TED_TESTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "ted/*.options")
# file(GLOB TIM_TESTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "tim/*.options")

set(TEST_TIMEOUT 40 CACHE STRING "The maximal amount of time each test is allowed to run")

include(ProcessorCount)
ProcessorCount(NUM_CPU)

add_custom_target(
  check
  COMMAND ${CMAKE_CTEST_COMMAND} -j${NUM_CPU} -T test --output-on-failure
  USES_TERMINAL
)

set(TEST_PREFIX "")
set(FAILING_TESTS "")
# Tests that fail always.
include(fail.cmake OPTIONAL)

message("Failing tests: ${FAILING_TESTS}")
message("Skipped tests: ${SKIP_TESTS}")

function(add_gold_tests TESTS TOIT_NAME UNIX_NAME)
  foreach(file ${${TESTS}})
    set(test_name "/tests/${file}")
    if("${test_name}" IN_LIST SKIP_TESTS)
      continue()
    endif()

    add_test(
      NAME "${test_name}"
      COMMAND "bash" "tests/gold-test.sh" ${TOITRUN} "tests/${file}" ${TOIT_NAME} ${UNIX_NAME}
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )

    set_tests_properties(${test_name} PROPERTIES TIMEOUT ${TEST_TIMEOUT})

    if ("${test_name}" IN_LIST FAILING_TESTS)
      set_tests_properties("${test_name}" PROPERTIES WILL_FAIL TRUE)
    endif()

  endforeach()
endfunction()

function(add_unix_tests TESTS TOIT_NAME UNIX_NAME)
  foreach(file ${${TESTS}})
    set(test_name "/tests/${file}")
    if("${test_name}" IN_LIST SKIP_TESTS)
      continue()
    endif()

    add_test(
      NAME "${test_name}"
      COMMAND "bash" "tests/compare-unix.sh" ${TOITRUN} "tests/${file}" ${TOIT_NAME} ${UNIX_NAME}
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )

    set_tests_properties(${test_name} PROPERTIES TIMEOUT ${TEST_TIMEOUT})

    if ("${test_name}" IN_LIST FAILING_TESTS)
      set_tests_properties("${test_name}" PROPERTIES WILL_FAIL TRUE)
    endif()

  endforeach()
endfunction()

add_gold_tests(TED_TESTS ted ed)
add_unix_tests(ED_TESTS ted ed)

# add_gold_tests(TIM_TESTS tim vi)
# add_unix_tests(VI_TESTS tim vi)
