find_package( OpenSSL REQUIRED)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

set(SYSCONFIG_INSTALL_DIR etc/blocksci/ . )

set(BLOCKSCI_HEADER_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/../include/blocksci)
set(BLOCKSCI_SOURCE_PREFIX ${CMAKE_CURRENT_SOURCE_DIR})

add_library(blocksci_internal STATIC)
set_property(TARGET blocksci_internal PROPERTY POSITION_INDEPENDENT_CODE ON)

set_target_properties(blocksci_internal PROPERTIES CXX_VISIBILITY_PRESET hidden)
set_target_properties(blocksci_internal PROPERTIES VISIBILITY_INLINES_HIDDEN 1)

set(BLOCKSCI_FEATURE_REQUIREMENTS
cxx_aggregate_default_initializers
cxx_auto_type
cxx_decltype
cxx_default_function_template_args
cxx_defaulted_functions
cxx_defaulted_move_initializers
cxx_delegating_constructors
cxx_deleted_functions
cxx_explicit_conversions
cxx_extern_templates
cxx_generalized_initializers
cxx_generic_lambdas
cxx_inheriting_constructors
cxx_lambdas
cxx_long_long_type
cxx_nullptr
cxx_override
cxx_range_for
cxx_return_type_deduction
cxx_right_angle_brackets
cxx_rvalue_references
cxx_static_assert
cxx_trailing_return_types
cxx_uniform_initialization
cxx_variable_templates
cxx_variadic_templates
cxx_template_template_parameters
)

target_compile_features(blocksci_internal PUBLIC cxx_std_17 ${BLOCKSCI_FEATURE_REQUIREMENTS})

target_compile_options(blocksci_internal PRIVATE -Wall -Wextra -Wpedantic)

if(BLOCKSCI_NATIVE_ARCH)
  target_compile_options(blocksci_internal PRIVATE -march=native -mtune=native)
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang" OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
target_compile_options(blocksci_internal PRIVATE -Weverything -Wno-c++98-compat -Wno-c++98-compat-pedantic -Wno-old-style-cast -Wno-documentation-unknown-command -Wno-documentation -Wno-shadow -Wno-covered-switch-default -Wno-missing-prototypes -Wno-weak-vtables -Wno-unused-macros -Wno-padded)
endif()

target_link_libraries( blocksci_internal
PUBLIC
  mio
  filesystem
  rocksdb
  rocksdb_headers
  ranges
  json
PRIVATE
  OpenSSL::Crypto
  endian
)

target_include_directories(blocksci_internal PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/..>
)

set(DATA_ACCESS_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/address_info.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/address_index.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/address_output_range.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/bitcoin_script.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/bitcoin_uint256_hex.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/dedup_address_info.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/exception.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/hash.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/script_view.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/data_access.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/data_configuration.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/chain_configuration.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/hash_index.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/state.cpp
)


target_sources(blocksci_internal
PRIVATE
${DATA_ACCESS_SOURCES}
)
