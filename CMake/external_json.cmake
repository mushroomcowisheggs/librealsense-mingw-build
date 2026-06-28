cmake_minimum_required(VERSION 3.10)
include(ExternalProject)



function(get_nlohmann_json)
    message(STATUS "Fetching nlohmann/json... using local source")
    set(JSON_LOCAL_DIR "${CMAKE_SOURCE_DIR}/third-party_src/json-3.12.0")
    add_subdirectory(${JSON_LOCAL_DIR} ${CMAKE_BINARY_DIR}/third-party/json-build EXCLUDE_FROM_ALL)
    message(STATUS "Fetching nlohmann/json - Done")
endfunction()

# Trigger the build
get_nlohmann_json()
