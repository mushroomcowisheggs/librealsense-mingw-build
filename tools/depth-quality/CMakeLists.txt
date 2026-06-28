# License: Apache 2.0. See LICENSE file in root directory.
# Copyright(c) 2019-2024 RealSense, Inc. All Rights Reserved.
cmake_minimum_required(VERSION 3.10)

project( rs-depth-quality )

if(WIN32)
    add_executable( ${PROJECT_NAME} WIN32 "" )
else()
    add_executable( ${PROJECT_NAME} "" )
endif()

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

include_directories(${CMAKE_BINARY_DIR})

include(../tools_common.cmake)

include(../../common/CMakeLists.txt)

if(MSVC)
    SET(DELAYED
        realsense2d.dll
        realsense2-gld.dll
        realsense2.dll
        realsense2-gl.dll
    )
elseif(MINGW)
    set(DELAYED realsense2.dll realsense2-gl.dll)
endif()

if(BUILD_GRAPHICAL_EXAMPLES)
    set(RS_QUALITY_TOOL_CPP
        ${COMMON_SRC}
        rs-depth-quality.cpp
        depth-quality-model.h
        depth-quality-model.cpp
        depth-metrics.h
        ../../common/realsense-ui-advanced-mode.h
        ${IMGUI_SOURCES}
        ../../third-party/glad/glad.c
        ../../third-party/tinyfiledialogs/tinyfiledialogs.c
        ../../third-party/tinyfiledialogs/tinyfiledialogs.h
        ../../third-party/rsutils/include/rsutils/type/eth-config.h
        ../../common/graph-model.h
        ../../common/graph-model.cpp
        ../../third-party/implot/implot.cpp
        ../../third-party/implot/implot.h
        ../../third-party/implot/implot_internal.h
        ../../third-party/implot/implot_items.cpp
        )

    if(WIN32)
        target_sources( ${PROJECT_NAME}
            PRIVATE
                ${RS_QUALITY_TOOL_CPP}
                ../../common/windows-app-bootstrap.cpp
            )

        source_group("Resources" FILES
                ${CMAKE_CURRENT_SOURCE_DIR}/res/resource.h
                ${CMAKE_CURRENT_SOURCE_DIR}/res/realsense-app.rc)

        source_group("3rd Party" FILES
            ../../third-party/tinyfiledialogs/tinyfiledialogs.c
            ../../third-party/tinyfiledialogs/tinyfiledialogs.h
            ../../third-party/imgui/imgui.cpp
            ../../third-party/imgui/imgui_draw.cpp
            ../../third-party/imgui/imgui_impl_glfw.cpp
            ../../third-party/imgui/imgui_impl_opengl3.cpp
            ../../third-party/imgui/imgui-fonts-karla.hpp
            ../../third-party/imgui/imgui-fonts-fontawesome.hpp)

        source_group("Utils" FILES
            depth-quality-model.h
            depth-quality-model.cpp
            depth-metrics.h
            ${COMMON_SRC})

        include_directories(../../common  ../../third-party
                            ../../third-party/imgui
                            ../../third-party/implot
                            ../../third-party/glad
                            ../../third-party/tinyfiledialogs
                            ${CMAKE_CURRENT_SOURCE_DIR}/res/)

        if(MSVC)
            #list(TRANSFORM DELAYED PREPEND " /DELAYLOAD:")
            PREPEND(DELAYED " /DELAYLOAD:" ${DELAYED})
            #infoValue(DELAYED)
            string(REPLACE ";" " " LD_FLAGS_STR "${DELAYED}")
        elseif(MINGW)
            string(REGEX REPLACE "/bin/[^/]+$" "" _msys_env "${CMAKE_C_COMPILER}")
            string(REGEX REPLACE "/[^/]+$" "" MSYS2_ROOT "${_msys_env}")
            set(SHELL_EXECUTABLE "${MSYS2_ROOT}/usr/bin/sh.exe")
            set(GREP_EXECUTABLE "${MSYS2_ROOT}/usr/bin/grep.exe")
            set(TR_EXECUTABLE "${MSYS2_ROOT}/usr/bin/tr.exe")
            set(CUT_EXECUTABLE "${MSYS2_ROOT}/usr/bin/cut.exe")
            if(NOT EXISTS "${SHELL_EXECUTABLE}")
                message(FATAL_ERROR "sh not found at ${SHELL_EXECUTABLE}")
            endif()

            set(LD_FLAGS_STR "")
            foreach(_dll IN LISTS DELAYED)
                string(REGEX REPLACE "\\.dll$" "" _dll_name ${_dll})
                if(TARGET ${_dll_name})
                    set(_imp_lib "$<TARGET_LINKER_FILE:${_dll_name}>")
                    set(_delay_lib "${CMAKE_CURRENT_BINARY_DIR}/lib${_dll_name}_delay.a")
                    add_custom_command(
                        OUTPUT ${_delay_lib}
                        COMMAND "${SHELL_EXECUTABLE}" -c "echo EXPORTS > \"${_delay_lib}.def\" && \"${CMAKE_NM}\" -g --defined-only \"${_imp_lib}\" | \"${GREP_EXECUTABLE}\" ' T ' | \"${TR_EXECUTABLE}\" -s ' ' | \"${CUT_EXECUTABLE}\" -d' ' -f3 >> \"${_delay_lib}.def\""
                        COMMAND "${CMAKE_DLLTOOL}" --input-def "${_delay_lib}.def" --output-delaylib "${_delay_lib}" --dllname ${_dll}
                        DEPENDS ${_imp_lib}
                        COMMENT "Creating delay-load import library for ${_dll_name}"
                        VERBATIM
                    )
                    add_custom_target(generate_${PROJECT_NAME}_${_dll_name}_delaylib DEPENDS ${_delay_lib})
                    add_dependencies(${PROJECT_NAME} generate_${PROJECT_NAME}_${_dll_name}_delaylib)
                    target_link_libraries(${PROJECT_NAME} ${_delay_lib})
                    add_dependencies(${PROJECT_NAME} ${_dll_name})
                else()
                    message(WARNING "Target ${_dll_name} not defined, delay-load will be skipped")
                endif()
            endforeach()
            target_link_libraries(${PROJECT_NAME} -ldelayimp)
        endif()

    else()
        target_sources( ${PROJECT_NAME}
            PRIVATE
                ${RS_QUALITY_TOOL_CPP}
            )

        include_directories(../../common  ../../third-party
                            ../../third-party/imgui
                            ../../third-party/implot
                            ../../third-party/glad
                            ../../third-party/tinyfiledialogs )
    endif()

    source_group("SW-Update" FILES ${SW_UPDATE_FILES})

    if(MINGW)
        # The delayed loading library has been added via target_link_libraries in the MinGW branch; 
        # the original import library is no longer included here to ensure the exe does not have a static dependency on realsense2-gl.
        # rsutils and easyloggingpp are essential libraries for graphical tools.
        set(RS_VIEWER_LIBS ${GTK3_LIBRARIES} Threads::Threads rsutils)
        target_sources(${PROJECT_NAME} PRIVATE "${REPO_ROOT}/third-party/easyloggingpp/src/easylogging++.cc")
    else()
        set(RS_VIEWER_LIBS ${GTK3_LIBRARIES} Threads::Threads realsense2-gl)
    endif()
    
    if(MINGW)
        list(REMOVE_ITEM DEPENDENCIES realsense2 realsense2-gl)
        target_include_directories(
            ${PROJECT_NAME} PRIVATE
            $<TARGET_PROPERTY:realsense2,INTERFACE_INCLUDE_DIRECTORIES>
        )
    endif()
    
    tools_target_config(${PROJECT_NAME})

    if(MINGW)
        set_target_properties(${PROJECT_NAME} PROPERTIES CXX_STANDARD 14)
    endif()

    install(
        TARGETS

        ${PROJECT_NAME}

        RUNTIME DESTINATION
        ${CMAKE_INSTALL_BINDIR}
    )
endif()
