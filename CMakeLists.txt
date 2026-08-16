cmake_minimum_required(VERSION 3.16)
project(appstrap LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

add_executable(appstrap
    src/main.cpp
    src/distro.cpp
    src/config.cpp
    src/runner.cpp
    src/installer.cpp
    src/display.cpp
)

target_include_directories(appstrap PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS appstrap RUNTIME DESTINATION bin)
