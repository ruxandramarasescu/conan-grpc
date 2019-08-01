#.rst:
# FindGrpc
# ------------
#
# Locate and configure the gRPC library.
#
# The following variables can be set and are optional:
# ``GRPC_ROOT_DIR``
#   Hint on preferred installation prefix
#
#
# Defines the following variables:
#
# ``GRPC_FOUND``
#   Found the gRPC library
#   (libgrpc & header files)
# ``GRPC_VERSION``
#   Version of package found.
# ``GRPC_INCLUDE_DIRS``
#   Include directories for gRPC
# ``GRPC_LIBRARIES``
#   The gRPC libraries
# ``GRPCPP_UNSECURE_LIBRARIES``
#   The gRPC unsecure libraries
# ``GPR_LIBRARIES``
#   The gRPC gpr libraries
#
# The following :prop_tgt:`IMPORTED` targets are also defined:
#
# ``gRPC::grpc``
#   The grpc library.
# ``gRPC::grpc++_unsecure``
#   The gRPC unsecure library.
# ``gRPC::gpr``
#   The gRPC gpr library.
#
# The following cache variables are also available to set or use:
#
# ``GRPC_CPP_PLUGIN``
#   The grpc_cpp_plugin executable
# ``GRPC_LIBRARY``
#   The gRPC library
# ``GRPC_INCLUDE_DIR``
#   The include directory for gRPC
# ``GRPC_LIBRARY_DEBUG``
#   The gRPC library (debug)
# ``GRPCPP_UNSECURE_LIBRARY``
#   The gRPC unsecure library
# ``GRPCPP_UNSECURE_LIBRARY_DEBUG``
#   The gRPC unsecure library (debug)
# ``GRPC_GPR_LIBRARY``
#   The gRPC gpr library
# ``GRPC_GPR_LIBRARY_DEBUG``
#   The gRPC gpr library (debug)
#
# Example:
#
# .. code-block:: cmake
#
#   find_package(Protobuf REQUIRED)
#   find_package(Grpc REQUIRED)
#   grpc_generate_cpp(GRPC_SRCS GRPC_HDRS foo.proto)
#   add_executable(bar bar.cc ${GRPC_SRCS} ${GRPC_HDRS})
#   target_link_libraries(bar gRPC::grpc protobuf::libprotobuf)
#
# .. command:: grpc_generate_cpp
#
#   Add custom commands to process ``.proto`` files to C++::
#
#     grpc_generate_cpp (<SRCS> <HDRS> [<ARGN>...])
#
#   ``SRCS``
#     Variable to define with autogenerated source files
#   ``HDRS``
#     Variable to define with autogenerated header files
#   ``ARGN``
#     ``.proto`` files
#

include(CMakeFindDependencyMacro)
find_dependency(OpenSSL)
find_dependency(Protobuf)
find_dependency(ZLIB)

function(GRPC_GENERATE_CPP SRCS HDRS)
    cmake_parse_arguments(grpc "" "" "" ${ARGN})

    set(PROTO_FILES "${grpc_UNPARSED_ARGUMENTS}")
    if(NOT PROTO_FILES)
        message(SEND_ERROR "Error: GRPC_GENERATE_CPP() called without any proto files")
        return()
    endif()

    if(GRPC_GENERATE_CPP_APPEND_PATH)
        # Create an include path for each file specified
        foreach(FIL ${PROTO_FILES})
            get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
            get_filename_component(ABS_PATH ${ABS_FIL} PATH)
            list(FIND _grpc_include_path ${ABS_PATH} _contains_already)
            if(${_contains_already} EQUAL -1)
                list(APPEND _grpc_include_path -I ${ABS_PATH})
            endif()
        endforeach()
    else()
        set(_grpc_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
    endif()

    if(DEFINED GRPC_IMPORT_DIRS)
        foreach(DIR ${GRPC_IMPORT_DIRS})
            get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
            list(FIND _grpc_include_path ${ABS_PATH} _contains_already)
            if(${_contains_already} EQUAL -1)
                list(APPEND _grpc_include_path -I ${ABS_PATH})
            endif()
        endforeach()
    endif()

    set(${SRCS})
    set(${HDRS})
    foreach(FIL ${PROTO_FILES})
        get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
        get_filename_component(FIL_WE ${FIL} NAME_WE)
        if(NOT GRPC_GENERATE_CPP_APPEND_PATH)
            get_filename_component(FIL_DIR ${FIL} DIRECTORY)
            if(FIL_DIR)
                set(FIL_WE "${FIL_DIR}/${FIL_WE}")
            endif()
        endif()

        list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.cc")
        list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc")
        list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.h")
        list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h")

        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.cc"
                   "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.pb.h"
                   "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc"
                   "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h"
            COMMAND  ${Protobuf_PROTOC_EXECUTABLE}
            ARGS "--cpp_out=${CMAKE_CURRENT_BINARY_DIR}"
                 ${_grpc_include_path}
                 ${ABS_FIL}
            COMMAND ${Protobuf_PROTOC_EXECUTABLE}
            ARGS "--grpc_out=${CMAKE_CURRENT_BINARY_DIR}"
                 "--plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}"
                 ${_grpc_include_path}
                 ${ABS_FIL}
            DEPENDS ${ABS_FIL} ${Protobuf_PROTOC_EXECUTABLE} ${GRPC_CPP_PLUGIN}
            COMMENT "Running C++ protocol buffer compiler on ${FIL}"
            VERBATIM
        )
    endforeach()

    set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
    set(${SRCS} ${${SRCS}} PARENT_SCOPE)
    set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

function(GRPC_GENERATE_PYTHON SRCS)
    find_dependency(PythonInterp 3)

    cmake_parse_arguments(grpc "" "" "" ${ARGN})

    set(PROTO_FILES "${grpc_UNPARSED_ARGUMENTS}")
    if(NOT PROTO_FILES)
        message(SEND_ERROR "Error: GRPC_GENERATE_PYTHON() called without any proto files")
        return()
    endif()

    if(GRPC_GENERATE_CPP_APPEND_PATH)
        # Create an include path for each file specified
        foreach(FIL ${PROTO_FILES})
        get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
        get_filename_component(ABS_PATH ${ABS_FIL} PATH)
        list(FIND _grpc_include_path ${ABS_PATH} _contains_already)
        if(${_contains_already} EQUAL -1)
            list(APPEND _grpc_include_path -I ${ABS_PATH})
        endif()
        endforeach()
    else()
        set(_grpc_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
    endif()

    if(DEFINED GRPC_IMPORT_DIRS)
        foreach(DIR ${GRPC_IMPORT_DIRS})
        get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
        list(FIND _grpc_include_path ${ABS_PATH} _contains_already)
        if(${_contains_already} EQUAL -1)
            list(APPEND _grpc_include_path -I ${ABS_PATH})
        endif()
        endforeach()
    endif()

    set(${SRCS})
    foreach(FIL ${PROTO_FILES})
        get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
        get_filename_component(FIL_WE ${FIL} NAME_WE)
        if(NOT GRPC_GENERATE_CPP_APPEND_PATH)
        get_filename_component(FIL_DIR ${FIL} DIRECTORY)
        if(FIL_DIR)
            set(FIL_WE "${FIL_DIR}/${FIL_WE}")
        endif()
        endif()

        list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}_pb2.py")

        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}_pb2_grpc.py"
                   "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}_pb2.py"
            COMMAND ${PYTHON_EXECUTABLE}
            ARGS "-m" "grpc_tools.protoc"
                 ${_grpc_include_path}
                 "--python_out=${CMAKE_CURRENT_BINARY_DIR}"
                 "--grpc_python_out=${CMAKE_CURRENT_BINARY_DIR}"
                 ${ABS_FIL}
            DEPENDS ${ABS_FIL} ${PYTHON_EXECUTABLE}
            COMMENT "Running Python protocol buffer and grpc compiler on ${FIL}"
            VERBATIM
        )
    endforeach()

    set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
    set(${SRCS} ${${SRCS}} PARENT_SCOPE)
endfunction()

include(SelectLibraryConfigurations)

function(_grpc_find_libraries name filename)
  if(${name}_LIBRARIES)
    # Use result recorded by a previous call.
    return()
  elseif(${name}_LIBRARY)
    # Honor cache entry used by CMake 3.5 and lower.
    set(${name}_LIBRARIES "${${name}_LIBRARY}" PARENT_SCOPE)
  else()
    find_library(${name}_LIBRARY_RELEASE
        NAMES ${filename}
        HINTS ${GRPC_ROOT_DIR}
        PATH_SUFFIXES lib
    )
    mark_as_advanced(${name}_LIBRARY_RELEASE)

    find_library(${name}_LIBRARY_DEBUG
        NAMES ${filename}d ${filename}
        HINTS ${GRPC_ROOT_DIR}
        PATH_SUFFIXES lib
    )
    mark_as_advanced(${name}_LIBRARY_DEBUG)

    select_library_configurations(${name})
    set(${name}_LIBRARY "${${name}_LIBRARY}" PARENT_SCOPE)
    set(${name}_LIBRARIES "${${name}_LIBRARIES}" PARENT_SCOPE)
  endif()
endfunction()

# Main

if(NOT DEFINED GRPC_GENERATE_CPP_APPEND_PATH)
  set(GRPC_GENERATE_CPP_APPEND_PATH TRUE)
endif()

find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin
    HINTS ${GRPC_ROOT_DIR} /usr/local
    PATH_SUFFIXES bin
)

_grpc_find_libraries(GPR gpr)
_grpc_find_libraries(GRPC grpc)
_grpc_find_libraries(GRPCPP grpc++)
_grpc_find_libraries(GRPCPP_CRONET grpc++_cronet)
_grpc_find_libraries(GRPCPP_ERROR_DETAILS grpc++_error_details)
_grpc_find_libraries(GRPCPP_REFLECTION grpc++_reflection)
_grpc_find_libraries(GRPCPP_UNSECURE grpc++_unsecure)
_grpc_find_libraries(GRPC_CRONET grpc_cronet)
_grpc_find_libraries(GRPC_UNSECURE grpc_unsecure)


find_path(GRPC_INCLUDE_DIR
    grpc/grpc.h
    HINTS ${GRPC_ROOT_DIR}
    PATH_SUFFIXES include
)
mark_as_advanced(GRPC_INCLUDE_DIR)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(gRPC DEFAULT_MSG
    GRPC_LIBRARIES
    GRPCPP_UNSECURE_LIBRARIES
    GPR_LIBRARIES
    GRPC_INCLUDE_DIR
)

if(UNIX AND NOT APPLE)
  set(_gRPC_ALLTARGETS_LIBRARIES "dl" "rt" "m" "Threads::Threads")
endif()

if(WIN32 AND MSVC)
  set(_gRPC_BASELIB_LIBRARIES wsock32 ws2_32)
endif()

if(gRPC_FOUND)
    set(GRPC_INCLUDE_DIRS ${GRPC_INCLUDE_DIR})

    if(NOT TARGET gRPC::gpr)
        add_library(gRPC::gpr UNKNOWN IMPORTED)
        set_target_properties(gRPC::gpr PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GPR_LIBRARY}")
            set_target_properties(gRPC::gpr PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GPR_LIBRARY}")
        endif()
        if(EXISTS "${GPR_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::gpr APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::gpr PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GPR_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GPR_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::gpr APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::gpr PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GPR_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_ALLTARGETS_LIBRARIES}"
        )
        set_target_properties(gRPC::gpr PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::gpr)

    if(NOT TARGET gRPC::grpc)
        add_library(gRPC::grpc UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPC_LIBRARY}")
            set_target_properties(gRPC::grpc PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPC_LIBRARY}")
        endif()
        if(EXISTS "${GRPC_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPC_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPC_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPC_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "OpenSSL::SSL"
            "${ZLIB_LIBRARIES}"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::gpr"
        )
        set_target_properties(gRPC::grpc PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc)

    if(NOT TARGET gRPC::grpc++)
        add_library(gRPC::grpc++ UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc++ PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPCPP_LIBRARY}")
            set_target_properties(gRPC::grpc++ PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPCPP_LIBRARY}")
        endif()
        if(EXISTS "${GRPCPP_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc++ APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc++ PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPCPP_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPCPP_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc++ APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc++ PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPCPP_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "OpenSSL::SSL"
            "protobuf::libprotobuf"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::grpc"
            "gRPC::gpr"
        )
        set_target_properties(gRPC::grpc++ PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc++)

    if(NOT TARGET gRPC::grpc++_cronet)
        add_library(gRPC::grpc++_cronet UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc++_cronet PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPCPP_CRONET_LIBRARY}")
            set_target_properties(gRPC::grpc++_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPCPP_CRONET_LIBRARY}")
        endif()
        if(EXISTS "${GRPCPP_CRONET_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc++_cronet APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc++_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPCPP_CRONET_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPCPP_CRONET_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc++_cronet APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc++_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPCPP_CRONET_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "OpenSSL::SSL"
            "protobuf::libprotobuf"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::gpr"
            "gRPC::grpc_cronet"
            "gRPC::grpc"
        )
        set_target_properties(gRPC::grpc++_cronet PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc++_cronet)

    if(NOT TARGET gRPC::grpc++_error_details)
        add_library(gRPC::grpc++_error_details UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc++_error_details PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPCPP_ERROR_DETAILS_LIBRARY}")
            set_target_properties(gRPC::grpc++_error_details PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPCPP_ERROR_DETAILS_LIBRARY}")
        endif()
        if(EXISTS "${GRPCPP_ERROR_DETAILS_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc++_error_details APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc++_error_details PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPCPP_ERROR_DETAILS_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPCPP_ERROR_DETAILS_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc++_error_details APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc++_error_details PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPCPP_ERROR_DETAILS_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "protobuf::libprotobuf"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::grpc++"
        )
        set_target_properties(gRPC::grpc++_error_details PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc++_error_details)

    if(NOT TARGET gRPC::grpc++_reflection)
        add_library(gRPC::grpc++_reflection UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc++_reflection PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPCPP_REFLECTION_LIBRARY}")
            set_target_properties(gRPC::grpc++_reflection PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPCPP_LIBRARY}")
        endif()
        if(EXISTS "${GRPCPP_REFLECTION_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc++_reflection APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc++_reflection PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPCPP_REFLECTION_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPCPP_REFLECTION_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc++_reflection APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc++_reflection PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPCPP_REFLECTION_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "protobuf::libprotobuf"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::grpc++"
            "gRPC::grpc"
        )
        set_target_properties(gRPC::grpc++_reflection PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc++_reflection)

    if(NOT TARGET gRPC::grpc++_unsecure)
        add_library(gRPC::grpc++_unsecure UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc++_unsecure PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPCPP_UNSECURE_LIBRARY}")
            set_target_properties(gRPC::grpc++_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPCPP_UNSECURE_LIBRARY}")
        endif()
        if(EXISTS "${GRPCPP_UNSECURE_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc++_unsecure APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc++_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPCPP_UNSECURE_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPCPP_UNSECURE_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc++_unsecure APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc++_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPCPP_UNSECURE_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "protobuf::libprotobuf"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::gpr"
            "gRPC::grpc_unsecure"
        )
        set_target_properties(gRPC::grpc++_unsecure PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc++_unsecure)

    if(NOT TARGET gRPC::grpc_cronet)
        add_library(gRPC::grpc_cronet UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc_cronet PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPC_CRONET_LIBRARY}")
            set_target_properties(gRPC::grpc_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPC_CRONET_LIBRARY}")
        endif()
        if(EXISTS "${GRPC_CRONET_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc_cronet APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPC_CRONET_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPC_CRONET_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc_cronet APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc_cronet PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPC_CRONET_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "OpenSSL::SSL"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::gpr"
        )
        set_target_properties(gRPC::grpc_cronet PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc_cronet)

    if(NOT TARGET gRPC::grpc_unsecure)
        add_library(gRPC::grpc_unsecure UNKNOWN IMPORTED)
        set_target_properties(gRPC::grpc_unsecure PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")
        if(EXISTS "${GRPC_UNSECURE_LIBRARY}")
            set_target_properties(gRPC::grpc_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
                IMPORTED_LOCATION "${GRPC_UNSECURE_LIBRARY}")
        endif()
        if(EXISTS "${GRPC_UNSECURE_LIBRARY_DEBUG}")
            set_property(TARGET gRPC::grpc_unsecure APPEND PROPERTY
                IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(gRPC::grpc_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                IMPORTED_LOCATION_DEBUG "${GRPC_UNSECURE_LIBRARY_DEBUG}")
        endif()
        if(EXISTS "${GRPC_UNSECURE_LIBRARY_RELEASE}")
            set_property(TARGET gRPC::grpc_unsecure APPEND PROPERTY
                IMPORTED_CONFIGURATIONS RELEASE)
            set_target_properties(gRPC::grpc_unsecure PROPERTIES
                IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
                IMPORTED_LOCATION_RELEASE "${GRPC_UNSECURE_LIBRARY_RELEASE}")
        endif()

        unset(_deps)
        list(APPEND _deps
            "${_gRPC_BASELIB_LIBRARIES}"
            "${ZLIB_LIBRARIES}"
            "${_gRPC_ALLTARGETS_LIBRARIES}"
            "gRPC::gpr"
        )
        set_target_properties(gRPC::grpc_unsecure PROPERTIES
                              INTERFACE_LINK_LIBRARIES "${_deps}")
    endif(NOT TARGET gRPC::grpc_unsecure)
endif()
