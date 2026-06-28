cmake_minimum_required(VERSION 3.10)
include(ExternalProject)


function(get_catch2)

    message( STATUS "Fetching Catch2..." )

    set(CATCH2_LOCAL_DIR "${CMAKE_SOURCE_DIR}/third-party_src/Catch2-3.4.0")
    add_subdirectory(${CATCH2_LOCAL_DIR} ${CMAKE_BINARY_DIR}/third-party/json-build EXCLUDE_FROM_ALL)

    message( STATUS "Fetching Catch2 - Done" )

endfunction()


get_catch2()
