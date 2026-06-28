cmake_minimum_required(VERSION 3.10)

# Check if dotnet is available
find_program(DOTNET_EXECUTABLE dotnet)
if(NOT DOTNET_EXECUTABLE)
    message(FATAL_ERROR "dotnet not found. Please install .NET SDK.")
endif()

set(CSHARP_PROJECT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Intel.RealSense)
set(CSHARP_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/Intel.RealSense/bin/${CMAKE_BUILD_TYPE})

# Generate Intel.RealSense.csproj if it does not exist
if(NOT EXISTS ${CSHARP_PROJECT_DIR}/Intel.RealSense.csproj)
    file(WRITE ${CSHARP_PROJECT_DIR}/Intel.RealSense.csproj
        "<Project Sdk=\"Microsoft.NET.Sdk\">\n"
        "  <PropertyGroup>\n"
        "    <TargetFramework>netstandard2.0</TargetFramework>\n"
        "    <GenerateAssemblyInfo>false</GenerateAssemblyInfo>\n"
        "    <OutputType>Library</OutputType>\n"
        "  </PropertyGroup>\n"
        "  <ItemGroup>\n"
        "    <Compile Include=\"**/*.cs\" />\n"
        "    <Reference Include=\"System\" />\n"
        "  </ItemGroup>\n"
        "</Project>\n"
    )
endif()

# Build the C# wrapper using dotnet
add_custom_target(Intel.RealSense ALL
    COMMAND ${DOTNET_EXECUTABLE} build ${CSHARP_PROJECT_DIR}/Intel.RealSense.csproj
        --configuration ${CMAKE_BUILD_TYPE}
        --output ${CSHARP_OUTPUT_DIR}
        --no-dependencies
    WORKING_DIRECTORY ${CSHARP_PROJECT_DIR}
    COMMENT "Building C# wrapper with dotnet"
    VERBATIM
)

# Print the location of the built DLL (informational)
add_custom_command(TARGET Intel.RealSense POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "C# DLL built at: ${CSHARP_OUTPUT_DIR}/Intel.RealSense.dll"
    COMMENT "C# wrapper build complete"
)

# ------------------ Unity bindings section ------------------
if(BUILD_UNITY_BINDINGS)
    # Prefer user‑provided UNITY_PATH; otherwise try to find Unity automatically
    if(NOT UNITY_PATH)
        find_program(UNITY_PATH Unity\\Editor\\Unity.exe)
    endif()

    if(EXISTS "${UNITY_PATH}")
        message(STATUS "Found Unity at ${UNITY_PATH}")

        # Set up the Unity project and plugin directories (use CMake variables)
        set(UNITY_PROJECT_DIR "${CMAKE_BINARY_DIR}/wrappers/unity")
        set(UNITY_PLUGIN_DIR "${UNITY_PROJECT_DIR}/Assets/RealSenseSDK2.0/Plugins")
        file(MAKE_DIRECTORY "${UNITY_PLUGIN_DIR}")

        # Copy Intel.RealSense.dll to the Unity plugin folder
        add_custom_command(TARGET Intel.RealSense POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CSHARP_OUTPUT_DIR}/Intel.RealSense.dll"
                "${UNITY_PLUGIN_DIR}/"
            COMMENT "Copy Intel.RealSense.dll to Unity plugins"
        )

        # Copy realsense2.dll (the main library) to the same folder
        # Use a generator expression to get the full path of the realsense2 target
        add_custom_command(TARGET Intel.RealSense POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:realsense2>"
                "${UNITY_PLUGIN_DIR}/"
            COMMENT "Copy realsense2.dll to Unity plugins"
        )

        # Invoke Unity to export the .unitypackage
        string(REPLACE "/" "\\" UNITY_WIN_PATH "${UNITY_PATH}")   # Convert to Windows backslashes
        set(UNITY_LOG "${CMAKE_BINARY_DIR}/Unity.log")
        set(UNITY_PACKAGE "${CMAKE_BINARY_DIR}/realsense.unitypackage")

        add_custom_command(TARGET Intel.RealSense POST_BUILD
            COMMAND ${UNITY_WIN_PATH} -quit -batchmode
                -logFile "${UNITY_LOG}"
                -projectPath "${UNITY_PROJECT_DIR}"
                -exportPackage "Assets" "${UNITY_PACKAGE}"
                || ${CMAKE_COMMAND} -E echo "Unity export returned non‑zero, check ${UNITY_LOG}"
            COMMENT "Generating Unity package (may take a moment)"
            VERBATIM
        )
    else()
        message(WARNING "Unity executable not found at '${UNITY_PATH}'. Unity package will not be generated.")
    endif()
endif()