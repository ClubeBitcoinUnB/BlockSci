include(CheckCXXCompilerFlag)

find_path(VARIANT_INCLUDE_DIR mpark/variant.hpp REQUIRED)
add_library(variant INTERFACE)
target_include_directories(variant SYSTEM INTERFACE ${VARIANT_INCLUDE_DIR})
install(TARGETS variant EXPORT blocksci-targets)

find_path(RANGE_V3_INCLUDE_DIR range/v3/all.hpp REQUIRED)
add_library(ranges INTERFACE)
target_include_directories(ranges SYSTEM INTERFACE ${RANGE_V3_INCLUDE_DIR})
install(TARGETS ranges EXPORT blocksci-targets)

find_path(FILESYSTEM_INCLUDE_DIR wjfilesystem/path.h REQUIRED)
add_library(filesystem INTERFACE)
target_include_directories(filesystem SYSTEM INTERFACE ${FILESYSTEM_INCLUDE_DIR})

find_path(MIO_INCLUDE_DIR mio/mmap.hpp REQUIRED)
add_library(mio INTERFACE)
target_include_directories(mio SYSTEM INTERFACE ${MIO_INCLUDE_DIR})

find_path(DSET_INCLUDE_DIR dset/dset.h REQUIRED)
add_library(dset INTERFACE)
target_include_directories(dset SYSTEM INTERFACE ${DSET_INCLUDE_DIR})

find_path(CLIPP_INCLUDE_DIR clipp.h REQUIRED)
add_library(clipp INTERFACE)
target_include_directories(clipp SYSTEM INTERFACE ${CLIPP_INCLUDE_DIR})

find_path(ENDIAN_INCLUDE_DIR endian/big_endian.hpp REQUIRED)
add_library(endian INTERFACE)
target_include_directories(endian SYSTEM INTERFACE ${ENDIAN_INCLUDE_DIR})

find_path(JSON_INCLUDE_DIR nlohmann/json.hpp REQUIRED)
add_library(json INTERFACE)
target_include_directories(json SYSTEM INTERFACE ${JSON_INCLUDE_DIR})

find_path(CEREAL_INCLUDE_DIR cereal/cereal.hpp REQUIRED)
add_library(cereal INTERFACE)
target_include_directories(cereal SYSTEM INTERFACE ${CEREAL_INCLUDE_DIR})

find_package(GTest REQUIRED)
if(NOT TARGET gtest)
  add_library(gtest INTERFACE)
  target_link_libraries(gtest INTERFACE GTest::GTest)
endif()
if(NOT TARGET gtest_main)
  add_library(gtest_main INTERFACE)
  target_link_libraries(gtest_main INTERFACE GTest::Main)
endif()

find_library(SECP256K1_LIBRARY secp256k1 REQUIRED)
find_path(SECP256K1_INCLUDE_DIR secp256k1.h REQUIRED)
add_library(secp256k1 INTERFACE)
target_include_directories(secp256k1 INTERFACE ${SECP256K1_INCLUDE_DIR})
target_link_libraries(secp256k1 INTERFACE ${SECP256K1_LIBRARY})

set(saved_flags "${CMAKE_CXX_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -fvisibility=hidden")

check_cxx_compiler_flag(-Wclass-memaccess HAS_CLASS_MEMACCESS)
if(HAS_CLASS_MEMACCESS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-error=class-memaccess")
endif()

# rocksdb
find_library(ROCKSDB_LIBRARY rocksdb REQUIRED)
find_path(ROCKSDB_INCLUDE_DIR rocksdb/db.h REQUIRED)
add_library(rocksdb INTERFACE)
target_include_directories(rocksdb SYSTEM INTERFACE ${ROCKSDB_INCLUDE_DIR})
find_package(Threads REQUIRED)
target_link_libraries(rocksdb INTERFACE ${ROCKSDB_LIBRARY} Threads::Threads)

add_library(rocksdb_headers INTERFACE)
target_include_directories(rocksdb_headers SYSTEM INTERFACE ${ROCKSDB_INCLUDE_DIR})


set(CMAKE_CXX_FLAGS "${saved_flags}")

find_library(BITCOINAPI_LIBRARY bitcoinapi REQUIRED)
find_path(BITCOINAPI_INCLUDE_DIR bitcoinapi/bitcoinapi.h REQUIRED)
add_library(bitcoinapi INTERFACE)
target_include_directories(bitcoinapi SYSTEM INTERFACE ${BITCOINAPI_INCLUDE_DIR})
target_link_libraries(bitcoinapi INTERFACE ${BITCOINAPI_LIBRARY})

# bitcoin-api-cpp headers include <json/json.h>; give consumers jsoncpp's path.
find_path(JSONCPP_INCLUDE_DIR json/json.h PATH_SUFFIXES jsoncpp)
if(JSONCPP_INCLUDE_DIR)
  target_include_directories(bitcoinapi SYSTEM INTERFACE ${JSONCPP_INCLUDE_DIR})
endif()
