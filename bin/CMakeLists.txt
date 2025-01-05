toit_project(tim "${CMAKE_CURRENT_LIST_DIR}")

set(TED_SOURCE "${CMAKE_CURRENT_LIST_DIR}/ted.toit")
set(TED_EXE "${CMAKE_BINARY_DIR}/ted${CMAKE_EXECUTABLE_SUFFIX}")
set(TED_DEP "${CMAKE_CURRENT_BINARY_DIR}/ted.dep")

ADD_TOIT_EXE(
  ${TED_SOURCE}
  ${TED_EXE}
  ${TED_DEP}
  ""
)

add_custom_target(
  build_binaries
  DEPENDS ${TED_EXE}
)

add_dependencies(build build_binaries)
