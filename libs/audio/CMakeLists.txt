cmake_minimum_required(VERSION 3.20)
project(GnarlaxxAudio LANGUAGES C)
if(NOT APPLE)
    message(FATAL_ERROR "The audio output build currently targets macOS.")
endif()
add_library(gnarlaxx_audio STATIC gna_audio.c gna_device.c gna_decoders.c)
target_compile_features(gnarlaxx_audio PUBLIC c_std_11)
target_include_directories(gnarlaxx_audio PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(gnarlaxx_audio SYSTEM PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/sokol"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/dr_libs")
target_compile_options(gnarlaxx_audio PRIVATE -Wall -Wextra -Wpedantic)
target_link_libraries(gnarlaxx_audio PUBLIC "-framework AudioToolbox")
