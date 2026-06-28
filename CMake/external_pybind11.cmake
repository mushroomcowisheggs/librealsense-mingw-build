cmake_minimum_required(VERSION 3.10)
include(ExternalProject)



function(get_pybind11)

    message( STATUS #CHECK_START
        "Fetching pybind11..." )

    set(PYBIND11_LOCAL_DIR "${CMAKE_SOURCE_DIR}/third-party_src/pybind11-2.13.6")
    if(NOT EXISTS ${PYBIND11_LOCAL_DIR}/CMakeLists.txt)
        message(FATAL_ERROR "Local pybind11 source not found at ${PYBIND11_LOCAL_DIR}")
    endif()
    add_subdirectory(${PYBIND11_LOCAL_DIR} ${CMAKE_BINARY_DIR}/third-party/json-build EXCLUDE_FROM_ALL)

    message( STATUS #CHECK_PASS
        "Fetching pybind11 - Done" )

endfunction()


# We also want a json-compatible pybind interface:
function(get_pybind11_json)

    message( STATUS #CHECK_START
        "Fetching pybind11_json..." )

    set(PYBIND11_JSON_LOCAL_DIR "${CMAKE_SOURCE_DIR}/third-party_src/pybind11_json-0.2.15")
    if(NOT EXISTS ${PYBIND11_JSON_LOCAL_DIR}/include/pybind11_json/pybind11_json.hpp)
        message(FATAL_ERROR "Local pybind11_json source not found at ${PYBIND11_JSON_LOCAL_DIR}")
    endif()
    set(PYBIND11_JSON_SOURCE_DIR ${PYBIND11_JSON_LOCAL_DIR} PARENT_SCOPE)

    message( STATUS #CHECK_PASS
        "Fetching pybind11_json - Done" )

endfunction()

# Trigger the build
get_pybind11()
get_pybind11_json()

# This function overrides "pybind11_add_module" function,  arguments is same as "pybind11_add_module" arguments
# pybind11_add_module(<name> SHARED [file, file2, ...] )
# Must be declared after pybind11 configuration above
function( pybind11_add_module project_name library_type ...)

    # message( STATUS "adding python module --> ${project_name}" 
    
    # "_pybind11_add_module" is calling the origin pybind11 function    
    _pybind11_add_module( ${ARGV})

    # Force Pybind11 not to share pyrealsense2 resources with other pybind modules.
    # With this definition we force the ABI version to be unique and not risk crashes on different modules.
    # (workaround for RS5-10582; see also https://github.com/pybind/pybind11/issues/2898)
    # NOTE: this workaround seems to be needed for debug compilations only
    target_compile_definitions( ${project_name} PRIVATE -DPYBIND11_COMPILER_TYPE=\"_${project_name}_abi\" )

    target_include_directories( ${project_name} PRIVATE "${CMAKE_BINARY_DIR}/third-party/pybind11-json/include" )

endfunction()
