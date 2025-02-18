# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

set(TEST_SRC_DIR ${ONNXRUNTIME_ROOT}/test)
set(TEST_INC_DIR ${ONNXRUNTIME_ROOT})
if (onnxruntime_USE_TVM)
  list(APPEND TEST_INC_DIR ${TVM_INCLUDES})
endif()

if (onnxruntime_USE_OPENVINO)
    list(APPEND TEST_INC_DIR ${OPENVINO_INCLUDE_DIR})
endif()

set(disabled_warnings)
function(AddTest)
  cmake_parse_arguments(_UT "DYN" "TARGET" "LIBS;SOURCES;DEPENDS" ${ARGN})
  if(_UT_LIBS)
    list(REMOVE_DUPLICATES _UT_LIBS)
  endif()
  list(REMOVE_DUPLICATES _UT_SOURCES)

  if (_UT_DEPENDS)
    list(REMOVE_DUPLICATES _UT_DEPENDS)
  endif(_UT_DEPENDS)

  add_executable(${_UT_TARGET} ${_UT_SOURCES})
  if (MSVC AND NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    #TODO: fix the warnings, they are dangerous
    target_compile_options(${_UT_TARGET} PRIVATE "/wd4244")
  endif()
  source_group(TREE ${TEST_SRC_DIR} FILES ${_UT_SOURCES})
  set_target_properties(${_UT_TARGET} PROPERTIES FOLDER "ONNXRuntimeTest")

  if (_UT_DEPENDS)
    add_dependencies(${_UT_TARGET} ${_UT_DEPENDS})
  endif(_UT_DEPENDS)
  if(_UT_DYN)
    target_link_libraries(${_UT_TARGET} PRIVATE ${_UT_LIBS} GTest::gtest GTest::gmock onnxruntime ${CMAKE_DL_LIBS} Threads::Threads)
    target_compile_definitions(${_UT_TARGET} PRIVATE -DUSE_ONNXRUNTIME_DLL)
  else()
    target_link_libraries(${_UT_TARGET} PRIVATE ${_UT_LIBS} GTest::gtest GTest::gmock ${onnxruntime_EXTERNAL_LIBRARIES})
  endif()
  onnxruntime_add_include_to_target(${_UT_TARGET} date_interface safeint_interface)
  target_include_directories(${_UT_TARGET} PRIVATE ${TEST_INC_DIR})
  if (onnxruntime_USE_CUDA)
    target_include_directories(${_UT_TARGET} PRIVATE ${CUDA_INCLUDE_DIRS} ${onnxruntime_CUDNN_HOME}/include)
  endif()
  if (onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS AND onnxruntime_ENABLE_PYTHON)
    target_compile_definitions(${_UT_TARGET} PRIVATE ENABLE_LANGUAGE_INTEROP_OPS)
  endif()
  if(MSVC)
    target_compile_options(${_UT_TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
  endif()
  if (WIN32)
    if (onnxruntime_USE_CUDA)
      # disable a warning from the CUDA headers about unreferenced local functions
      if (MSVC)
        target_compile_options(${_UT_TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler /wd4505>"
                "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/wd4505>")
      endif()
    endif()
    target_compile_options(${_UT_TARGET} PRIVATE ${disabled_warnings})
  else()
    target_compile_options(${_UT_TARGET} PRIVATE ${DISABLED_WARNINGS_FOR_TVM})
    target_compile_options(${_UT_TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:-Xcompiler -Wno-error=sign-compare>"
            "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:-Wno-error=sign-compare>")
  endif()

  set(TEST_ARGS)
  if (onnxruntime_GENERATE_TEST_REPORTS)
    # generate a report file next to the test program
    list(APPEND TEST_ARGS
      "--gtest_output=xml:$<SHELL_PATH:$<TARGET_FILE:${_UT_TARGET}>.$<CONFIG>.results.xml>")
  endif(onnxruntime_GENERATE_TEST_REPORTS)

  add_test(NAME ${_UT_TARGET}
    COMMAND ${_UT_TARGET} ${TEST_ARGS}
    WORKING_DIRECTORY $<TARGET_FILE_DIR:${_UT_TARGET}>
  )
endfunction(AddTest)

#Do not add '${TEST_SRC_DIR}/util/include' to your include directories directly
#Use onnxruntime_add_include_to_target or target_link_libraries, so that compile definitions
#can propagate correctly.

file(GLOB onnxruntime_test_utils_src CONFIGURE_DEPENDS
  "${TEST_SRC_DIR}/util/include/*.h"
  "${TEST_SRC_DIR}/util/*.cc"
)

file(GLOB onnxruntime_test_common_src CONFIGURE_DEPENDS
  "${TEST_SRC_DIR}/common/*.cc"
  "${TEST_SRC_DIR}/common/*.h"
  "${TEST_SRC_DIR}/common/logging/*.cc"
  "${TEST_SRC_DIR}/common/logging/*.h"
  )

file(GLOB onnxruntime_test_ir_src CONFIGURE_DEPENDS
  "${TEST_SRC_DIR}/ir/*.cc"
  "${TEST_SRC_DIR}/ir/*.h"
  )

file(GLOB onnxruntime_test_optimizer_src CONFIGURE_DEPENDS
  "${TEST_SRC_DIR}/optimizer/*.cc"
  "${TEST_SRC_DIR}/optimizer/*.h"
  )

set(onnxruntime_test_framework_src_patterns
  "${TEST_SRC_DIR}/framework/*.cc"
  "${TEST_SRC_DIR}/framework/*.h"
  "${TEST_SRC_DIR}/platform/*.cc"
  )

if(WIN32)
  list(APPEND onnxruntime_test_framework_src_patterns
    "${TEST_SRC_DIR}/platform/windows/*.cc"
    "${TEST_SRC_DIR}/platform/windows/logging/*.cc" )
endif()

if(onnxruntime_USE_CUDA)
  list(APPEND onnxruntime_test_framework_src_patterns  ${TEST_SRC_DIR}/framework/cuda/*)
endif()

set(onnxruntime_test_providers_src_patterns
  "${TEST_SRC_DIR}/providers/*.h"
  "${TEST_SRC_DIR}/providers/*.cc"
  "${TEST_SRC_DIR}/opaque_api/test_opaque_api.cc"
  "${TEST_SRC_DIR}/framework/TestAllocatorManager.cc"
  "${TEST_SRC_DIR}/framework/TestAllocatorManager.h"
  "${TEST_SRC_DIR}/framework/test_utils.cc"
  "${TEST_SRC_DIR}/framework/test_utils.h"
  )
if(NOT onnxruntime_DISABLE_CONTRIB_OPS)
  list(APPEND onnxruntime_test_providers_src_patterns
    "${TEST_SRC_DIR}/contrib_ops/*.h"
    "${TEST_SRC_DIR}/contrib_ops/*.cc")
endif()

if(onnxruntime_USE_FEATURIZERS)
  list(APPEND onnxruntime_test_providers_src_patterns
    "${TEST_SRC_DIR}/featurizers_ops/*.h"
    "${TEST_SRC_DIR}/featurizers_ops/*.cc")
endif()

file(GLOB onnxruntime_test_providers_src CONFIGURE_DEPENDS
  ${onnxruntime_test_providers_src_patterns})
file(GLOB_RECURSE onnxruntime_test_providers_cpu_src CONFIGURE_DEPENDS
  "${TEST_SRC_DIR}/providers/cpu/*"
  )
list(APPEND onnxruntime_test_providers_src ${onnxruntime_test_providers_cpu_src})

if (onnxruntime_USE_NGRAPH)
  file(GLOB_RECURSE onnxruntime_test_providers_ngraph_src CONFIGURE_DEPENDS
    "${TEST_SRC_DIR}/providers/ngraph/*"
    )
  list(APPEND onnxruntime_test_providers_src ${onnxruntime_test_providers_ngraph_src})
endif()

if (onnxruntime_USE_NNAPI)
  file(GLOB_RECURSE onnxruntime_test_providers_nnapi_src CONFIGURE_DEPENDS
    "${TEST_SRC_DIR}/providers/nnapi/*"
    )
  list(APPEND onnxruntime_test_providers_src ${onnxruntime_test_providers_nnapi_src})
endif()

set (ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR "${ONNXRUNTIME_ROOT}/test/shared_lib")


set (onnxruntime_shared_lib_test_SRC
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_fixture.h
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_inference.cc
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_session_options.cc
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_run_options.cc
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_allocator.cc
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_nontensor_types.cc
          ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_model_loading.cc)
if(onnxruntime_RUN_ONNX_TESTS)
  list(APPEND onnxruntime_shared_lib_test_SRC ${ONNXRUNTIME_SHARED_LIB_TEST_SRC_DIR}/test_io_types.cc)
endif() 

# tests from lowest level library up.
# the order of libraries should be maintained, with higher libraries being added first in the list

set(onnxruntime_test_common_libs
  onnxruntime_test_utils
  onnxruntime_common
)

set(onnxruntime_test_ir_libs
  onnxruntime_test_utils
  onnxruntime_graph
  onnxruntime_common
)

set(onnxruntime_test_optimizer_libs
  onnxruntime_test_utils
  onnxruntime_framework
  onnxruntime_util
  onnxruntime_graph
  onnxruntime_common
)

set(onnxruntime_test_framework_libs
  onnxruntime_test_utils
  onnxruntime_framework
  onnxruntime_util
  onnxruntime_graph
  onnxruntime_common
  onnxruntime_mlas
  )

set(onnxruntime_test_server_libs
  onnxruntime_test_utils
  onnxruntime_test_utils_for_server
)

if(WIN32)
    list(APPEND onnxruntime_test_framework_libs Advapi32)
endif()

set (onnxruntime_test_providers_dependencies ${onnxruntime_EXTERNAL_DEPENDENCIES})

if(onnxruntime_USE_CUDA)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_cuda)
endif()

if(onnxruntime_USE_DNNL)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_dnnl)
endif()

if(onnxruntime_USE_NGRAPH)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_ngraph)
endif()

if(onnxruntime_USE_OPENVINO)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_openvino)
endif()

if(onnxruntime_USE_NNAPI)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_nnapi)
endif()

if(onnxruntime_USE_FEATURIZERS)
   list(APPEND onnxruntime_test_providers_dependencies onnxruntime_featurizers onnxruntime_featurizers_comp)
endif()

if(onnxruntime_USE_DML)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_dml)
endif()

file(GLOB_RECURSE onnxruntime_test_tvm_src CONFIGURE_DEPENDS
  "${ONNXRUNTIME_ROOT}/test/tvm/*.h"
  "${ONNXRUNTIME_ROOT}/test/tvm/*.cc"
  )

file(GLOB_RECURSE onnxruntime_test_openvino_src
  "${ONNXRUNTIME_ROOT}/test/openvino/*.h"
  "${ONNXRUNTIME_ROOT}/test/openvino/*.cc"
 )

if(onnxruntime_USE_NUPHAR)
  list(APPEND onnxruntime_test_framework_src_patterns  ${TEST_SRC_DIR}/framework/nuphar/*)
  list(APPEND onnxruntime_test_framework_libs onnxruntime_providers_nuphar)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_nuphar)
  list(APPEND onnxruntime_test_providers_libs onnxruntime_providers_nuphar)
endif()

if(onnxruntime_USE_ACL)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_acl)
endif()

if (onnxruntime_ENABLE_MICROSOFT_INTERNAL)
  include(onnxruntime_unittests_internal.cmake)
endif()

if (onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS)
  set(ONNXRUNTIME_INTEROP_TEST_LIBS PRIVATE onnxruntime_language_interop onnxruntime_pyop)
endif()

set(ONNXRUNTIME_TEST_LIBS
    onnxruntime_session
    ${ONNXRUNTIME_INTEROP_TEST_LIBS}
    ${onnxruntime_libs}
    ${PROVIDERS_CUDA}
    ${PROVIDERS_DNNL}
    ${PROVIDERS_TENSORRT}
    ${PROVIDERS_NGRAPH}
    ${PROVIDERS_OPENVINO}
    ${PROVIDERS_NUPHAR}
    ${PROVIDERS_NNAPI}
    ${PROVIDERS_DML}
    ${PROVIDERS_ACL}
    onnxruntime_optimizer
    onnxruntime_providers
    onnxruntime_util
    ${onnxruntime_tvm_libs}
    onnxruntime_framework
    onnxruntime_util
    onnxruntime_graph
    onnxruntime_common
    onnxruntime_mlas
)

set(onnxruntime_test_providers_libs
    onnxruntime_test_utils
    ${ONNXRUNTIME_TEST_LIBS}
  )

if(onnxruntime_USE_TENSORRT)
  list(APPEND onnxruntime_test_framework_src_patterns  ${TEST_SRC_DIR}/providers/tensorrt/*)
  list(APPEND onnxruntime_test_framework_libs onnxruntime_providers_tensorrt)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_tensorrt)
  list(APPEND onnxruntime_test_providers_libs onnxruntime_providers_tensorrt)
endif()

if(onnxruntime_USE_NNAPI)
  list(APPEND onnxruntime_test_framework_src_patterns  ${TEST_SRC_DIR}/providers/nnapi/*)
  list(APPEND onnxruntime_test_framework_libs onnxruntime_providers_nnapi)
  list(APPEND onnxruntime_test_providers_dependencies onnxruntime_providers_nnapi)
  list(APPEND onnxruntime_test_providers_libs onnxruntime_providers_nnapi)
endif()

if(WIN32)
  if (onnxruntime_USE_TVM)
    list(APPEND disabled_warnings ${DISABLED_WARNINGS_FOR_TVM})
  endif()
endif()

file(GLOB onnxruntime_test_framework_src CONFIGURE_DEPENDS
  ${onnxruntime_test_framework_src_patterns}
  )

#without auto initialize onnxruntime
add_library(onnxruntime_test_utils ${onnxruntime_test_utils_src})
if(MSVC)
  target_compile_options(onnxruntime_test_utils PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
else()
  target_compile_definitions(onnxruntime_test_utils PUBLIC -DNSYNC_ATOMIC_CPP11)
  target_include_directories(onnxruntime_test_utils PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${ONNXRUNTIME_ROOT} "${CMAKE_CURRENT_SOURCE_DIR}/external/nsync/public")
endif()
onnxruntime_add_include_to_target(onnxruntime_test_utils onnxruntime_framework GTest::gtest onnx onnx_proto)

if (onnxruntime_USE_DNNL)
  target_compile_definitions(onnxruntime_test_utils PUBLIC USE_DNNL=1)
endif()
if (onnxruntime_USE_DML)
  target_add_dml(onnxruntime_test_utils)
endif()
add_dependencies(onnxruntime_test_utils ${onnxruntime_EXTERNAL_DEPENDENCIES})
target_include_directories(onnxruntime_test_utils PUBLIC "${TEST_SRC_DIR}/util/include" PRIVATE ${eigen_INCLUDE_DIRS} ${ONNXRUNTIME_ROOT})
set_target_properties(onnxruntime_test_utils PROPERTIES FOLDER "ONNXRuntimeTest")

set(all_tests ${onnxruntime_test_common_src} ${onnxruntime_test_ir_src} ${onnxruntime_test_optimizer_src} ${onnxruntime_test_framework_src} ${onnxruntime_test_providers_src})
if(NOT TARGET onnxruntime)
  list(APPEND all_tests ${onnxruntime_shared_lib_test_SRC})
endif()
set(all_dependencies ${onnxruntime_test_providers_dependencies} )

  if (onnxruntime_USE_TVM)
    list(APPEND all_tests ${onnxruntime_test_tvm_src})
  endif()
  if (onnxruntime_USE_OPENVINO)
    list(APPEND all_tests ${onnxruntime_test_openvino_src})
  endif()
  # we can only have one 'main', so remove them all and add back the providers test_main as it sets
  # up everything we need for all tests
  file(GLOB_RECURSE test_mains CONFIGURE_DEPENDS
    "${TEST_SRC_DIR}/*/test_main.cc"
    )
  list(REMOVE_ITEM all_tests ${test_mains})
  list(APPEND all_tests "${TEST_SRC_DIR}/providers/test_main.cc")

  # this is only added to onnxruntime_test_framework_libs above, but we use onnxruntime_test_providers_libs for the onnxruntime_test_all target.
  # for now, add it here. better is probably to have onnxruntime_test_providers_libs use the full onnxruntime_test_framework_libs
  # list given it's built on top of that library and needs all the same dependencies.
  if(WIN32)
    list(APPEND onnxruntime_test_providers_libs Advapi32)
  endif()

  AddTest(
    TARGET onnxruntime_test_all
    SOURCES ${all_tests}
    LIBS ${onnxruntime_test_providers_libs} ${onnxruntime_test_common_libs}
    DEPENDS ${all_dependencies}
  )

  # the default logger tests conflict with the need to have an overall default logger
  # so skip in this type of
  target_compile_definitions(onnxruntime_test_all PUBLIC -DSKIP_DEFAULT_LOGGER_TESTS)

  if (onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS)
    target_link_libraries(onnxruntime_test_all PRIVATE onnxruntime_language_interop onnxruntime_pyop)
  endif()

  set(test_data_target onnxruntime_test_all)


#
# onnxruntime_ir_graph test data
#
set(TEST_DATA_SRC ${TEST_SRC_DIR}/testdata)
set(TEST_DATA_DES $<TARGET_FILE_DIR:${test_data_target}>/testdata)

# Copy test data from source to destination.
add_custom_command(
  TARGET ${test_data_target} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
  ${TEST_DATA_SRC}
  ${TEST_DATA_DES})
if(WIN32)
  if (onnxruntime_USE_DNNL)
    list(APPEND onnx_test_libs dnnl)
    add_custom_command(
      TARGET ${test_data_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${DNNL_DLL_PATH} $<TARGET_FILE_DIR:${test_data_target}>
      )
  endif()
  if (onnxruntime_USE_MKLML)
    add_custom_command(
      TARGET ${test_data_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy
      ${MKLML_LIB_DIR}/${MKLML_SHARED_LIB} ${MKLML_LIB_DIR}/${IOMP5MD_SHARED_LIB}
      $<TARGET_FILE_DIR:${test_data_target}>
    )
  endif()
  if (onnxruntime_USE_OPENVINO)
    add_custom_command(
      TARGET ${test_data_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy
      ${OPENVINO_CPU_EXTENSION_DIR}/${OPENVINO_CPU_EXTENSION_LIB}
      $<TARGET_FILE_DIR:${test_data_target}>
    )
  endif()
  if (onnxruntime_USE_NGRAPH)
    add_custom_command(
      TARGET ${test_data_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${ngraph_LIBRARIES}/
      $<TARGET_FILE_DIR:${test_data_target}>
    )
  endif()
  if (onnxruntime_USE_TVM)
    add_custom_command(
      TARGET ${test_data_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:tvm> $<TARGET_FILE_DIR:${test_data_target}>
      )
  endif()
endif()

add_library(onnx_test_data_proto ${TEST_SRC_DIR}/proto/tml.proto)
add_dependencies(onnx_test_data_proto onnx_proto ${onnxruntime_EXTERNAL_DEPENDENCIES})

if(WIN32)
  target_compile_options(onnx_test_data_proto PRIVATE "/wd4125" "/wd4456" "/wd4100" "/wd4267")  
else()
  if(HAS_UNUSED_PARAMETER)
    target_compile_options(onnx_test_data_proto PRIVATE "-Wno-unused-parameter")
  endif()
  if(HAS_UNUSED_VARIABLE)
    target_compile_options(onnx_test_data_proto PRIVATE "-Wno-unused-variable")
  endif()
  if(HAS_UNUSED_BUT_SET_VARIABLE)    
    target_compile_options(onnx_test_data_proto PRIVATE "-Wno-unused-but-set-variable")
  endif()
endif()
add_dependencies(onnx_test_data_proto onnx_proto ${onnxruntime_EXTERNAL_DEPENDENCIES})

onnxruntime_add_include_to_target(onnx_test_data_proto onnx_proto)
target_include_directories(onnx_test_data_proto PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_BINARY_DIR}/onnx)
set_target_properties(onnx_test_data_proto PROPERTIES FOLDER "ONNXRuntimeTest")
onnxruntime_protobuf_generate(APPEND_PATH IMPORT_DIRS ${ONNXRUNTIME_ROOT}/core/protobuf TARGET onnx_test_data_proto)

set(onnx_test_runner_src_dir ${TEST_SRC_DIR}/onnx)
set(onnx_test_runner_common_srcs
  ${onnx_test_runner_src_dir}/TestResultStat.cc
  ${onnx_test_runner_src_dir}/TestResultStat.h
  ${onnx_test_runner_src_dir}/testenv.h
  ${onnx_test_runner_src_dir}/FixedCountFinishCallback.h
  ${onnx_test_runner_src_dir}/TestCaseResult.cc
  ${onnx_test_runner_src_dir}/TestCaseResult.h
  ${onnx_test_runner_src_dir}/testenv.cc
  ${onnx_test_runner_src_dir}/heap_buffer.h
  ${onnx_test_runner_src_dir}/heap_buffer.cc
  ${onnx_test_runner_src_dir}/OrtValueList.h
  ${onnx_test_runner_src_dir}/runner.h
  ${onnx_test_runner_src_dir}/runner.cc
  ${onnx_test_runner_src_dir}/TestCase.cc
  ${onnx_test_runner_src_dir}/TestCase.h
  ${onnx_test_runner_src_dir}/onnxruntime_event.h
  ${onnx_test_runner_src_dir}/sync_api.h
  ${onnx_test_runner_src_dir}/sync_api.cc
  ${onnx_test_runner_src_dir}/callback.h
  ${onnx_test_runner_src_dir}/callback.cc
  ${onnx_test_runner_src_dir}/pb_helper.h
  ${onnx_test_runner_src_dir}/pb_helper.cc
  ${onnx_test_runner_src_dir}/mem_buffer.h
  ${onnx_test_runner_src_dir}/tensorprotoutils.h
  ${onnx_test_runner_src_dir}/tensorprotoutils.cc)

if(WIN32)
  set(wide_get_opt_src_dir ${TEST_SRC_DIR}/win_getopt/wide)
  add_library(win_getopt_wide ${wide_get_opt_src_dir}/getopt.cc ${wide_get_opt_src_dir}/include/getopt.h)
  target_include_directories(win_getopt_wide INTERFACE ${wide_get_opt_src_dir}/include)
  set_target_properties(win_getopt_wide PROPERTIES FOLDER "ONNXRuntimeTest")
  set(onnx_test_runner_common_srcs ${onnx_test_runner_common_srcs})
  set(GETOPT_LIB_WIDE win_getopt_wide)
endif()

add_library(onnx_test_runner_common ${onnx_test_runner_common_srcs})
if(MSVC)
  target_compile_options(onnx_test_runner_common PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
else()
  target_compile_definitions(onnx_test_runner_common PUBLIC -DNSYNC_ATOMIC_CPP11)
  target_include_directories(onnx_test_runner_common PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${ONNXRUNTIME_ROOT} "${CMAKE_CURRENT_SOURCE_DIR}/external/nsync/public")
endif()
if (MSVC AND NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    #TODO: fix the warnings, they are dangerous
    target_compile_options(onnx_test_runner_common PRIVATE "/wd4244")
endif()
onnxruntime_add_include_to_target(onnx_test_runner_common onnxruntime_common onnxruntime_framework onnxruntime_test_utils onnx onnx_proto re2::re2 safeint_interface)

add_dependencies(onnx_test_runner_common onnx_test_data_proto ${onnxruntime_EXTERNAL_DEPENDENCIES})
target_include_directories(onnx_test_runner_common PRIVATE ${eigen_INCLUDE_DIRS} ${RE2_INCLUDE_DIR} ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_BINARY_DIR}/onnx ${ONNXRUNTIME_ROOT})

set_target_properties(onnx_test_runner_common PROPERTIES FOLDER "ONNXRuntimeTest")

set(onnx_test_libs
  onnxruntime_test_utils
  ${ONNXRUNTIME_TEST_LIBS}
  onnx_test_data_proto
  ${onnxruntime_EXTERNAL_LIBRARIES})

if (onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS)
  list(APPEND onnx_test_libs onnxruntime_language_interop onnxruntime_pyop)
endif()

add_executable(onnx_test_runner ${onnx_test_runner_src_dir}/main.cc)
if(MSVC)
  target_compile_options(onnx_test_runner PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
endif()
target_link_libraries(onnx_test_runner PRIVATE onnx_test_runner_common ${GETOPT_LIB_WIDE} ${onnx_test_libs})
target_include_directories(onnx_test_runner PRIVATE ${ONNXRUNTIME_ROOT})
set_target_properties(onnx_test_runner PROPERTIES FOLDER "ONNXRuntimeTest")

if (onnxruntime_USE_TVM)
  if (WIN32)
    target_link_options(onnx_test_runner PRIVATE "/STACK:4000000")
  endif()
endif()

install(TARGETS onnx_test_runner
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})

if(onnxruntime_BUILD_BENCHMARKS)
  add_executable(onnxruntime_benchmark ${TEST_SRC_DIR}/onnx/microbenchmark/main.cc ${TEST_SRC_DIR}/onnx/microbenchmark/modeltest.cc)
  target_include_directories(onnxruntime_benchmark PRIVATE ${ONNXRUNTIME_ROOT} ${onnxruntime_graph_header} benchmark)
  if(WIN32)
    target_compile_options(onnxruntime_benchmark PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler /wd4141>"
                      "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/wd4141>")
  endif()
  target_link_libraries(onnxruntime_benchmark PRIVATE onnx_test_runner_common benchmark ${onnx_test_libs})
  add_dependencies(onnxruntime_benchmark ${onnxruntime_EXTERNAL_DEPENDENCIES})
  set_target_properties(onnxruntime_benchmark PROPERTIES FOLDER "ONNXRuntimeTest")
endif()

if(WIN32)
  target_compile_options(onnx_test_runner_common PRIVATE -D_CRT_SECURE_NO_WARNINGS)
endif()

add_test(NAME onnx_test_pytorch_converted
  COMMAND onnx_test_runner ${PROJECT_SOURCE_DIR}/external/onnx/onnx/backend/test/data/pytorch-converted)
add_test(NAME onnx_test_pytorch_operator
  COMMAND onnx_test_runner ${PROJECT_SOURCE_DIR}/external/onnx/onnx/backend/test/data/pytorch-operator)

if (CMAKE_SYSTEM_NAME STREQUAL "Android")
    list(APPEND android_shared_libs log android)
    if (onnxruntime_USE_NNAPI)
        list(APPEND android_shared_libs neuralnetworks)
    endif()
endif()

#perf test runner
set(onnxruntime_perf_test_src_dir ${TEST_SRC_DIR}/perftest)
set(onnxruntime_perf_test_src_patterns
"${onnxruntime_perf_test_src_dir}/*.cc"
"${onnxruntime_perf_test_src_dir}/*.h")

if(WIN32)
  list(APPEND onnxruntime_perf_test_src_patterns
    "${onnxruntime_perf_test_src_dir}/windows/*.cc"
    "${onnxruntime_perf_test_src_dir}/windows/*.h" )
else ()
  list(APPEND onnxruntime_perf_test_src_patterns
    "${onnxruntime_perf_test_src_dir}/posix/*.cc"
    "${onnxruntime_perf_test_src_dir}/posix/*.h" )
endif()

file(GLOB onnxruntime_perf_test_src CONFIGURE_DEPENDS
  ${onnxruntime_perf_test_src_patterns}
  )
add_executable(onnxruntime_perf_test ${onnxruntime_perf_test_src} ${ONNXRUNTIME_ROOT}/core/framework/path_lib.cc)
if(MSVC)
  target_compile_options(onnxruntime_perf_test PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
endif()
target_include_directories(onnxruntime_perf_test PRIVATE ${onnx_test_runner_src_dir} ${ONNXRUNTIME_ROOT}
        ${eigen_INCLUDE_DIRS} ${onnxruntime_graph_header} ${onnxruntime_exec_src_dir}
        ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_BINARY_DIR}/onnx)
if (WIN32)
  target_compile_options(onnxruntime_perf_test PRIVATE ${disabled_warnings})
  SET(SYS_PATH_LIB shlwapi)
endif()

if (onnxruntime_BUILD_SHARED_LIB)
  set(onnxruntime_perf_test_libs onnxruntime_test_utils onnx_test_runner_common onnxruntime_common re2::re2
          onnx_test_data_proto onnx_proto ${PROTOBUF_LIB} ${GETOPT_LIB_WIDE} onnxruntime ${SYS_PATH_LIB} ${CMAKE_DL_LIBS})
  if(NOT WIN32)
    list(APPEND onnxruntime_perf_test_libs nsync_cpp)
  endif()
  if (CMAKE_SYSTEM_NAME STREQUAL "Android")
    list(APPEND onnxruntime_perf_test_libs ${android_shared_libs})
  endif()
  target_link_libraries(onnxruntime_perf_test PRIVATE ${onnxruntime_perf_test_libs} Threads::Threads)
  if(WIN32)
    target_link_libraries(onnxruntime_perf_test PRIVATE debug dbghelp advapi32)
  endif()
  if(tensorflow_C_PACKAGE_PATH)
    target_include_directories(onnxruntime_perf_test PRIVATE ${tensorflow_C_PACKAGE_PATH}/include)
    target_link_directories(onnxruntime_perf_test PRIVATE ${tensorflow_C_PACKAGE_PATH}/lib)
    target_link_libraries(onnxruntime_perf_test PRIVATE tensorflow)
    target_compile_definitions(onnxruntime_perf_test PRIVATE HAVE_TENSORFLOW)
  endif()
else()
  target_link_libraries(onnxruntime_perf_test PRIVATE onnx_test_runner_common ${GETOPT_LIB_WIDE} ${onnx_test_libs})
endif()
set_target_properties(onnxruntime_perf_test PROPERTIES FOLDER "ONNXRuntimeTest")

if (onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS AND NOT onnxruntime_BUILD_SHARED_LIB)
  target_link_libraries(onnxruntime_perf_test PRIVATE onnxruntime_language_interop onnxruntime_pyop)
endif()

if (onnxruntime_USE_TVM)
  if (WIN32)
    target_link_options(onnxruntime_perf_test PRIVATE "/STACK:4000000")
  endif()
endif()


# shared lib
if (onnxruntime_BUILD_SHARED_LIB)
  add_library(onnxruntime_mocked_allocator ${ONNXRUNTIME_ROOT}/test/util/test_allocator.cc)
  target_include_directories(onnxruntime_mocked_allocator PUBLIC ${ONNXRUNTIME_ROOT}/test/util/include)
  set_target_properties(onnxruntime_mocked_allocator PROPERTIES FOLDER "ONNXRuntimeTest")

  #################################################################
  # test inference using shared lib
  set(onnxruntime_shared_lib_test_LIBS onnxruntime_mocked_allocator onnxruntime_test_utils onnxruntime_common onnx_proto)

  if(NOT WIN32)
    list(APPEND onnxruntime_shared_lib_test_LIBS nsync_cpp)
  endif()
  if (CMAKE_SYSTEM_NAME STREQUAL "Android")
    list(APPEND onnxruntime_shared_lib_test_LIBS ${android_shared_libs})
  endif()
  AddTest(DYN
          TARGET onnxruntime_shared_lib_test
          SOURCES ${onnxruntime_shared_lib_test_SRC} ${TEST_SRC_DIR}/providers/test_main.cc
          LIBS ${onnxruntime_shared_lib_test_LIBS}
          DEPENDS ${all_dependencies}
  )
endif()

#some ETW tools
if(WIN32 AND onnxruntime_ENABLE_INSTRUMENT)
    add_executable(generate_perf_report_from_etl ${ONNXRUNTIME_ROOT}/tool/etw/main.cc ${ONNXRUNTIME_ROOT}/tool/etw/eparser.h ${ONNXRUNTIME_ROOT}/tool/etw/eparser.cc ${ONNXRUNTIME_ROOT}/tool/etw/TraceSession.h ${ONNXRUNTIME_ROOT}/tool/etw/TraceSession.cc)
    target_compile_definitions(generate_perf_report_from_etl PRIVATE "_CONSOLE" "_UNICODE" "UNICODE")
    target_link_libraries(generate_perf_report_from_etl PRIVATE tdh Advapi32)

    add_executable(compare_two_sessions ${ONNXRUNTIME_ROOT}/tool/etw/compare_two_sessions.cc ${ONNXRUNTIME_ROOT}/tool/etw/eparser.h ${ONNXRUNTIME_ROOT}/tool/etw/eparser.cc ${ONNXRUNTIME_ROOT}/tool/etw/TraceSession.h ${ONNXRUNTIME_ROOT}/tool/etw/TraceSession.cc)
    target_compile_definitions(compare_two_sessions PRIVATE "_CONSOLE" "_UNICODE" "UNICODE")
    target_link_libraries(compare_two_sessions PRIVATE ${GETOPT_LIB_WIDE} tdh Advapi32)
endif()

add_executable(onnxruntime_mlas_test ${TEST_SRC_DIR}/mlas/unittest.cpp)
if(MSVC)
  target_compile_options(onnxruntime_mlas_test PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:--compiler-options /utf-8>" "$<$<NOT:$<COMPILE_LANGUAGE:CUDA>>:/utf-8>")
endif()
target_include_directories(onnxruntime_mlas_test PRIVATE ${ONNXRUNTIME_ROOT}/core/mlas/inc ${ONNXRUNTIME_ROOT})
set(onnxruntime_mlas_test_libs onnxruntime_mlas onnxruntime_common)
if(NOT WIN32)
  list(APPEND onnxruntime_mlas_test_libs nsync_cpp)
endif()
list(APPEND onnxruntime_mlas_test_libs Threads::Threads)
target_link_libraries(onnxruntime_mlas_test PRIVATE ${onnxruntime_mlas_test_libs})
set_target_properties(onnxruntime_mlas_test PROPERTIES FOLDER "ONNXRuntimeTest")

add_library(custom_op_library SHARED ${REPO_ROOT}/onnxruntime/test/testdata/custom_op_library/custom_op_library.cc)
target_include_directories(custom_op_library PRIVATE ${REPO_ROOT}/include)
if(UNIX)
  if (APPLE)
    set(ONNXRUNTIME_CUSTOM_OP_LIB_LINK_FLAG "-Xlinker -dead_strip")
  else()
    set(ONNXRUNTIME_CUSTOM_OP_LIB_LINK_FLAG "-Xlinker --no-undefined -Xlinker --gc-sections")
  endif()
else()
  set(ONNXRUNTIME_CUSTOM_OP_LIB_LINK_FLAG "-DEF:${REPO_ROOT}/onnxruntime/test/testdata/custom_op_library/custom_op_library.def")
endif()
set_property(TARGET custom_op_library APPEND_STRING PROPERTY LINK_FLAGS ${ONNXRUNTIME_CUSTOM_OP_LIB_LINK_FLAG})

if (onnxruntime_BUILD_JAVA)
    message(STATUS "Running Java tests")
    # delegate to gradle's test runner
    add_test(NAME onnxruntime4j_test COMMAND ${GRADLE_EXECUTABLE} cmakeCheck -DcmakeBuildDir=${CMAKE_CURRENT_BINARY_DIR} WORKING_DIRECTORY ${REPO_ROOT}/java)
    set_property(TEST onnxruntime4j_test APPEND PROPERTY DEPENDS onnxruntime4j_jni)
endif()
